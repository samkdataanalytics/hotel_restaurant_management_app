-- ============================================================================
-- Website CMS: published content, drafts, revisions and a media library for the
-- public HotRest site (landing, help, legal, auth copy, header, footer, theme).
--
-- Design notes
--   * Published and draft content live in separate tables. Postgres column
--     grants cannot tell a signed-in stranger from a superadmin, so a "draft"
--     column on a world-readable table would leak unpublished text to every
--     authenticated user.
--   * Nobody writes the tables directly. All writes go through SECURITY DEFINER
--     functions that check is_superadmin() themselves, so the table grants stay
--     read-only and there is no policy to get subtly wrong.
--   * The structural CHECK is a backstop. The editor validates much more
--     strictly, and the public renderer tolerates anything that gets through.
--   * No rows exist after this migration: the site renders its bundled defaults
--     until a superadmin publishes, so applying it changes nothing visible.
-- ============================================================================

-- ─── Structural check ───────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.site_content_ok(p_key text, p_content jsonb)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  -- coalesce: a CHECK passes on NULL, and a page with no "sections" key would
  -- otherwise evaluate to NULL rather than false.
  SELECT coalesce(
    jsonb_typeof(p_content) = 'object'
    AND pg_column_size(p_content) < 262144                       -- 256 KB
    AND (
      p_key NOT LIKE 'page:%'
      OR (
        jsonb_typeof(p_content -> 'sections') = 'array'
        AND jsonb_array_length(p_content -> 'sections') <= 80
      )
    )
    -- No string anywhere may begin with a script-capable URL scheme. Links are
    -- additionally allow-listed by the app; this stops one reaching the table.
    -- "data:" is only refused in its URI form (data:text/html...), so legal copy
    -- that happens to start a sentence with "Data:" is not caught.
    AND NOT jsonb_path_exists(
      p_content,
      '$.** ? (@.type() == "string" && @ like_regex "^[[:space:]]*(javascript:|vbscript:|data:[a-z]+/)" flag "i")'
    ), false);
$$;

-- ─── Tables ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.site_documents (
  key          text PRIMARY KEY CHECK (key ~ '^(page|global):[a-z0-9-]{1,40}$'),
  content      jsonb NOT NULL,
  version      integer NOT NULL DEFAULT 1,
  published_at timestamptz NOT NULL DEFAULT now(),
  published_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT site_documents_content_ok CHECK (public.site_content_ok(key, content))
);

CREATE TABLE IF NOT EXISTS public.site_drafts (
  key          text PRIMARY KEY CHECK (key ~ '^(page|global):[a-z0-9-]{1,40}$'),
  content      jsonb NOT NULL,
  -- Published version this draft was started from; the editor warns when the
  -- live document has moved on since.
  base_version integer NOT NULL DEFAULT 0,
  -- Bumped on every save: optimistic concurrency between two open editors.
  version      integer NOT NULL DEFAULT 1,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT site_drafts_content_ok CHECK (public.site_content_ok(key, content))
);

-- Immutable history, and the audit log: who published what, when.
CREATE TABLE IF NOT EXISTS public.site_revisions (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  key         text NOT NULL,
  rev         integer NOT NULL,
  content     jsonb NOT NULL,
  action      text NOT NULL CHECK (action IN ('publish', 'restore', 'discard')),
  note        text NOT NULL DEFAULT '',
  created_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (key, rev)
);

CREATE INDEX IF NOT EXISTS site_revisions_key_rev ON public.site_revisions (key, rev DESC);

CREATE TABLE IF NOT EXISTS public.site_media (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  path          text NOT NULL UNIQUE,           -- object path inside the bucket
  url           text NOT NULL,
  width         integer,
  height        integer,
  bytes         integer NOT NULL,
  mime          text NOT NULL,
  alt           text NOT NULL DEFAULT '',
  original_name text NOT NULL DEFAULT '',
  created_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ─── Access: read-only tables ───────────────────────────────────────────────
-- Explicit grants: tables created without them are unreadable (see migration
-- 20220101000047_fix_table_grants.sql).

ALTER TABLE public.site_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_drafts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_media     ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.site_documents, public.site_drafts,
              public.site_revisions, public.site_media FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.site_documents TO anon, authenticated;
GRANT SELECT ON public.site_drafts, public.site_revisions, public.site_media TO authenticated;

-- Published content is public. The policy calls no function: an anon policy
-- that calls one the role cannot execute fails the whole query.
DROP POLICY IF EXISTS site_documents_read ON public.site_documents;
CREATE POLICY site_documents_read ON public.site_documents
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS site_drafts_read ON public.site_drafts;
CREATE POLICY site_drafts_read ON public.site_drafts
  FOR SELECT TO authenticated USING (public.is_superadmin());

DROP POLICY IF EXISTS site_revisions_read ON public.site_revisions;
CREATE POLICY site_revisions_read ON public.site_revisions
  FOR SELECT TO authenticated USING (public.is_superadmin());

DROP POLICY IF EXISTS site_media_read ON public.site_media;
CREATE POLICY site_media_read ON public.site_media
  FOR SELECT TO authenticated USING (public.is_superadmin());

-- ─── Write functions ────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.site_require_superadmin()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'Only a superadmin can edit the website' USING ERRCODE = '42501';
  END IF;
END;
$$;

-- Save the working copy. p_expected is the version the editor last saw (0 when
-- it believes no draft exists); a mismatch means someone else saved in between.
CREATE OR REPLACE FUNCTION public.site_save_draft(p_key text, p_content jsonb, p_expected integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cur   integer;
  base  integer;
BEGIN
  PERFORM public.site_require_superadmin();

  SELECT version INTO cur FROM public.site_drafts WHERE key = p_key FOR UPDATE;

  IF cur IS NULL THEN
    IF p_expected <> 0 THEN
      RAISE EXCEPTION 'conflict: draft % no longer exists', p_key USING ERRCODE = '40001';
    END IF;
    SELECT coalesce(version, 0) INTO base FROM public.site_documents WHERE key = p_key;
    INSERT INTO public.site_drafts (key, content, base_version, version, updated_by)
    VALUES (p_key, p_content, coalesce(base, 0), 1, auth.uid());
    RETURN 1;
  END IF;

  IF cur <> p_expected THEN
    RAISE EXCEPTION 'conflict: draft % was changed elsewhere (have %, expected %)',
      p_key, cur, p_expected USING ERRCODE = '40001';
  END IF;

  UPDATE public.site_drafts
     SET content = p_content, version = cur + 1, updated_at = now(), updated_by = auth.uid()
   WHERE key = p_key;
  RETURN cur + 1;
END;
$$;

-- Make the draft the live document, and record a revision.
CREATE OR REPLACE FUNCTION public.site_publish(p_key text, p_note text DEFAULT '')
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  d       jsonb;
  newv    integer;
  newrev  integer;
BEGIN
  PERFORM public.site_require_superadmin();

  SELECT content INTO d FROM public.site_drafts WHERE key = p_key FOR UPDATE;
  IF d IS NULL THEN
    RAISE EXCEPTION 'Nothing to publish for %', p_key;
  END IF;

  INSERT INTO public.site_documents (key, content, version, published_at, published_by)
  VALUES (p_key, d, 1, now(), auth.uid())
  ON CONFLICT (key) DO UPDATE
     SET content = excluded.content,
         version = public.site_documents.version + 1,
         published_at = now(),
         published_by = auth.uid()
  RETURNING version INTO newv;

  SELECT coalesce(max(rev), 0) + 1 INTO newrev FROM public.site_revisions WHERE key = p_key;
  INSERT INTO public.site_revisions (key, rev, content, action, note, created_by)
  VALUES (p_key, newrev, d, 'publish', coalesce(p_note, ''), auth.uid());

  UPDATE public.site_drafts SET base_version = newv WHERE key = p_key;
  RETURN newv;
END;
$$;

-- Throw the working copy away; the editor falls back to the published document.
CREATE OR REPLACE FUNCTION public.site_discard_draft(p_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.site_require_superadmin();
  DELETE FROM public.site_drafts WHERE key = p_key;
END;
$$;

-- Restoring never goes straight to live: it loads the old revision into the
-- draft, where it can be looked at before it is published.
CREATE OR REPLACE FUNCTION public.site_restore_revision(p_key text, p_rev integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  old     jsonb;
  cur     integer;
  base    integer;
  newrev  integer;
BEGIN
  PERFORM public.site_require_superadmin();

  SELECT content INTO old FROM public.site_revisions WHERE key = p_key AND rev = p_rev;
  IF old IS NULL THEN
    RAISE EXCEPTION 'Revision % of % does not exist', p_rev, p_key;
  END IF;

  SELECT version INTO cur FROM public.site_drafts WHERE key = p_key FOR UPDATE;
  IF cur IS NULL THEN
    SELECT coalesce(version, 0) INTO base FROM public.site_documents WHERE key = p_key;
    INSERT INTO public.site_drafts (key, content, base_version, version, updated_by)
    VALUES (p_key, old, coalesce(base, 0), 1, auth.uid());
    cur := 0;
  ELSE
    UPDATE public.site_drafts
       SET content = old, version = cur + 1, updated_at = now(), updated_by = auth.uid()
     WHERE key = p_key;
  END IF;

  SELECT coalesce(max(rev), 0) + 1 INTO newrev FROM public.site_revisions WHERE key = p_key;
  INSERT INTO public.site_revisions (key, rev, content, action, note, created_by)
  VALUES (p_key, newrev, old, 'restore', 'Restored revision ' || p_rev, auth.uid());

  RETURN cur + 1;
END;
$$;

-- Library bookkeeping. The file itself is uploaded to storage by the client;
-- this records it (and checks the caller) so the library can list and search.
CREATE OR REPLACE FUNCTION public.site_media_register(
  p_path text, p_url text, p_width integer, p_height integer, p_bytes integer,
  p_mime text, p_alt text, p_original_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mid uuid;
BEGIN
  PERFORM public.site_require_superadmin();
  IF p_mime NOT IN ('image/jpeg', 'image/png', 'image/webp', 'image/gif') THEN
    RAISE EXCEPTION 'Unsupported image type %', p_mime;
  END IF;
  INSERT INTO public.site_media (path, url, width, height, bytes, mime, alt, original_name, created_by)
  VALUES (p_path, p_url, p_width, p_height, p_bytes, p_mime, coalesce(p_alt, ''),
          coalesce(p_original_name, ''), auth.uid())
  ON CONFLICT (path) DO UPDATE SET alt = excluded.alt
  RETURNING id INTO mid;
  RETURN mid;
END;
$$;

CREATE OR REPLACE FUNCTION public.site_media_set_alt(p_id uuid, p_alt text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.site_require_superadmin();
  UPDATE public.site_media SET alt = coalesce(p_alt, '') WHERE id = p_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.site_media_delete(p_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  obj text;
BEGIN
  PERFORM public.site_require_superadmin();
  DELETE FROM public.site_media WHERE id = p_id RETURNING path INTO obj;
  RETURN obj;
END;
$$;

REVOKE EXECUTE ON FUNCTION
  public.site_require_superadmin(),
  public.site_save_draft(text, jsonb, integer),
  public.site_publish(text, text),
  public.site_discard_draft(text),
  public.site_restore_revision(text, integer),
  public.site_media_register(text, text, integer, integer, integer, text, text, text),
  public.site_media_set_alt(uuid, text),
  public.site_media_delete(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.site_save_draft(text, jsonb, integer),
  public.site_publish(text, text),
  public.site_discard_draft(text),
  public.site_restore_revision(text, integer),
  public.site_media_register(text, text, integer, integer, integer, text, text, text),
  public.site_media_set_alt(uuid, text),
  public.site_media_delete(uuid)
TO authenticated;

-- ─── Media storage ──────────────────────────────────────────────────────────
-- Public read (the images are on the public site). SVG is excluded on purpose:
-- it can carry script. Writes need a superadmin session.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('site-media', 'site-media', true, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE
  SET public = true,
      file_size_limit = 5242880,
      allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

DROP POLICY IF EXISTS "site-media public read" ON storage.objects;
CREATE POLICY "site-media public read" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'site-media');

DROP POLICY IF EXISTS "site-media superadmin insert" ON storage.objects;
CREATE POLICY "site-media superadmin insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'site-media' AND public.is_superadmin());

DROP POLICY IF EXISTS "site-media superadmin update" ON storage.objects;
CREATE POLICY "site-media superadmin update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'site-media' AND public.is_superadmin());

DROP POLICY IF EXISTS "site-media superadmin delete" ON storage.objects;
CREATE POLICY "site-media superadmin delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'site-media' AND public.is_superadmin());
