-- A stale draft save used to raise SQLSTATE 40001 (serialization_failure).
-- Through the Supabase API that code does not come back as an error: PostgREST
-- leaves the transaction open and the request hangs until it times out, so the
-- studio's "this page was edited elsewhere" banner would never appear.
--
-- Found by calling the function over HTTP on hotrest_dev; the SQL tests, which run
-- inside the database, could not see it. The conflict now uses its own code,
-- 'CF409', which comes back as an ordinary 400 with that code in the body.

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
      RAISE EXCEPTION 'conflict: draft % no longer exists', p_key USING ERRCODE = 'CF409';
    END IF;
    SELECT coalesce(version, 0) INTO base FROM public.site_documents WHERE key = p_key;
    INSERT INTO public.site_drafts (key, content, base_version, version, updated_by)
    VALUES (p_key, p_content, coalesce(base, 0), 1, auth.uid());
    RETURN 1;
  END IF;

  IF cur <> p_expected THEN
    RAISE EXCEPTION 'conflict: draft % was changed elsewhere (have %, expected %)',
      p_key, cur, p_expected USING ERRCODE = 'CF409';
  END IF;

  UPDATE public.site_drafts
     SET content = p_content, version = cur + 1, updated_at = now(), updated_by = auth.uid()
   WHERE key = p_key;
  RETURN cur + 1;
END;
$$;

-- CREATE OR REPLACE keeps the existing grants, but state them so this file is
-- correct on its own.
REVOKE EXECUTE ON FUNCTION public.site_save_draft(text, jsonb, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.site_save_draft(text, jsonb, integer) TO authenticated;
