-- ============================================================================
-- Superadmin: registered users, their details and their activity.
--
-- Until now a superadmin could see companies and their members, but not who has
-- registered, when they last signed in, or what they did. This adds:
--
--   * user_activity  - an append-only log of who did what, written by triggers on
--                      the tables that matter (bookings, orders, staff, billing,
--                      membership, sign-ins). Readable by superadmins only.
--   * superadmin_*   - SECURITY DEFINER functions the console calls. They read
--                      auth.users / auth.sessions, which the browser cannot, and
--                      each one refuses anyone who is not a superadmin.
--
-- What is and is not recorded
--   Recorded: sign-ups, sign-ins, creates and status changes on bookings,
--   check-ins, restaurant orders, expenses, rooms, menu items, tables, staff and
--   shifts, invites, membership and role changes, payments, plan changes, profile
--   edits. The actor is whoever's session made the change (auth.uid()); changes
--   made by a webhook or a service key have no actor and are recorded without one.
--   Not recorded: page views, reads, searches. Nothing is recorded retroactively
--   except one "signed up" and one "last signed in" entry per existing user.
--   Guest personal data (names, IDs, contact details) is deliberately never copied
--   into the log: entries carry references and statuses, not people's details.
--
-- Safety
--   Logging can never block the action it observes: every trigger swallows its own
--   errors. The table has no INSERT/UPDATE/DELETE grants for any client role.
-- ============================================================================

-- ─── Table ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_activity (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid,                       -- the actor; null for system / webhook changes
  org_id      uuid,
  property_id uuid,
  action      text NOT NULL,              -- 'booking.created', 'auth.sign_in', ...
  entity      text NOT NULL,              -- 'booking', 'auth', ...
  entity_id   text,
  detail      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_activity_detail_small CHECK (pg_column_size(detail) < 4096)
);

CREATE INDEX IF NOT EXISTS user_activity_user_time ON public.user_activity (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_activity_org_time  ON public.user_activity (org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_activity_time      ON public.user_activity (created_at DESC);
CREATE INDEX IF NOT EXISTS user_activity_action    ON public.user_activity (action, created_at DESC);

ALTER TABLE public.user_activity ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_activity FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_activity TO authenticated;

DROP POLICY IF EXISTS user_activity_read ON public.user_activity;
CREATE POLICY user_activity_read ON public.user_activity
  FOR SELECT TO authenticated USING (public.is_superadmin());

-- ─── Trigger function ───────────────────────────────────────────────────────
-- Arguments: entity, then the columns whose change is worth a log line on UPDATE.
--   CREATE TRIGGER ... EXECUTE FUNCTION public.log_user_activity('booking', 'status', 'is_paid');
-- INSERT and DELETE are always logged; UPDATE only when a watched column changed.

CREATE OR REPLACE FUNCTION public.log_user_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  entity   text := TG_ARGV[0];
  j        jsonb;
  oldj     jsonb;
  hotel    uuid;
  org      uuid;
  actor    uuid;
  act      text;
  d        jsonb := '{}'::jsonb;
  changed  jsonb := '{}'::jsonb;
  col      text;
  i        int;
  k        text;
BEGIN
  BEGIN
    IF TG_OP = 'DELETE' THEN
      j := to_jsonb(OLD);
      act := entity || '.deleted';
    ELSE
      j := to_jsonb(NEW);
      oldj := CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END;
      act := entity || CASE TG_OP WHEN 'INSERT' THEN '.created' ELSE '.updated' END;
    END IF;

    IF TG_OP = 'UPDATE' THEN
      FOR i IN 1 .. coalesce(array_length(TG_ARGV, 1), 0) - 1 LOOP
        col := TG_ARGV[i];
        IF (j -> col) IS DISTINCT FROM (oldj -> col) THEN
          changed := changed || jsonb_build_object(col, jsonb_build_object('from', oldj -> col, 'to', j -> col));
        END IF;
      END LOOP;
      IF changed = '{}'::jsonb THEN
        RETURN NULL;                       -- nothing we watch changed
      END IF;
      d := jsonb_build_object('changed', changed);
      -- A status change reads better as its own action: booking.confirmed.
      IF changed ? 'status' AND jsonb_typeof(j -> 'status') = 'string' THEN
        act := entity || '.' || regexp_replace(lower(j ->> 'status'), '[^a-z0-9]+', '_', 'g');
      END IF;
    END IF;

    -- A few harmless, non-personal fields to make the line readable. Guest names,
    -- contact details and documents are never copied.
    FOREACH k IN ARRAY ARRAY['status','payment_status','booking_ref','order_number','type','source',
                             'category','role','plan','billing_cycle','room_number','amount','total_amount',
                             'plan_slug','target_user','invited_email_domain']
    LOOP
      IF j ? k AND jsonb_typeof(j -> k) IN ('string', 'number', 'boolean') THEN
        d := d || jsonb_build_object(k, j -> k);
      END IF;
    END LOOP;
    IF j ? 'description' AND jsonb_typeof(j -> 'description') = 'string' THEN
      d := d || jsonb_build_object('description', left(j ->> 'description', 80));
    END IF;
    IF entity IN ('org_member', 'property_staff') AND j ? 'user_id' THEN
      d := d || jsonb_build_object('target_user', j ->> 'user_id');
    END IF;
    IF entity = 'staff_invite' AND j ? 'invited_email' THEN
      -- The domain says enough to recognise an invite without storing the address.
      d := d || jsonb_build_object('invited_email_domain', split_part(j ->> 'invited_email', '@', 2));
    END IF;

    hotel := coalesce(nullif(j ->> 'hotel_id', '')::uuid, nullif(j ->> 'property_id', '')::uuid);
    org   := nullif(j ->> 'org_id', '')::uuid;
    IF org IS NULL AND entity = 'org' THEN
      org := nullif(j ->> 'id', '')::uuid;
    END IF;
    IF org IS NULL AND hotel IS NOT NULL THEN
      SELECT h.org_id INTO org FROM public.hotels h WHERE h.id = hotel;
    END IF;

    actor := auth.uid();
    IF actor IS NULL AND entity = 'payment' THEN
      actor := nullif(j ->> 'user_id', '')::uuid;   -- the webhook has no session; the payer is the actor
    END IF;

    INSERT INTO public.user_activity (user_id, org_id, property_id, action, entity, entity_id, detail)
    VALUES (actor, org, hotel, act, entity, coalesce(j ->> 'id', ''), d);
  EXCEPTION WHEN OTHERS THEN
    NULL;   -- never let the log get in the way of the real write
  END;
  RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_user_activity() FROM PUBLIC, anon, authenticated;

-- Sign-ups and sign-ins come from auth.users itself.
CREATE OR REPLACE FUNCTION public.log_auth_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    IF TG_OP = 'INSERT' THEN
      INSERT INTO public.user_activity (user_id, action, entity, entity_id)
      VALUES (NEW.id, 'auth.sign_up', 'auth', NEW.id::text);
    ELSIF NEW.last_sign_in_at IS DISTINCT FROM OLD.last_sign_in_at AND NEW.last_sign_in_at IS NOT NULL THEN
      INSERT INTO public.user_activity (user_id, action, entity, entity_id, created_at)
      VALUES (NEW.id, 'auth.sign_in', 'auth', NEW.id::text, NEW.last_sign_in_at);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_auth_activity() FROM PUBLIC, anon, authenticated;

-- ─── Triggers ───────────────────────────────────────────────────────────────
-- Created only where the table exists, so this migration works on a database that
-- has not got every table (and re-running it is harmless).

DO $$
DECLARE
  t record;
  spec text[][] := ARRAY[
    -- table,               entity,           watched columns on UPDATE (comma separated; empty = none)
    ['bookings',            'booking',        'status,is_paid'],
    ['check_ins',           'check_in',       ''],
    ['restaurant_orders',   'order',          'status,payment_status'],
    ['expenses',            'expense',        'is_paid'],
    ['rooms',               'room',           'status'],
    ['menu_items',          'menu_item',      ''],
    ['restaurant_tables',   'table',          'status'],
    ['organization_members','org_member',     'role,is_deleted,can_manage_billing'],
    ['property_staff',      'property_staff', 'role,is_deleted'],
    ['staff_invites',       'staff_invite',   'status'],
    ['staff_shifts',        'shift',          'status'],
    ['staff_time_records',  'time_record',    'clock_out'],
    ['payhere_orders',      'payment',        'status'],
    ['organizations',       'org',            'plan,status,billing_cycle,trial_ends_at,subscription_paid_at,is_deleted'],
    ['profiles',            'profile',        'full_name,phone,job_title,is_deleted']
  ];
  i int;
  tbl text; ent text; cols text; args text;
BEGIN
  FOR i IN 1 .. array_length(spec, 1) LOOP
    tbl := spec[i][1]; ent := spec[i][2]; cols := spec[i][3];
    CONTINUE WHEN to_regclass('public.' || tbl) IS NULL;

    args := quote_literal(ent);
    IF cols <> '' THEN
      args := args || ', ' || (SELECT string_agg(quote_literal(c), ', ') FROM unnest(string_to_array(cols, ',')) c);
    END IF;

    EXECUTE format('DROP TRIGGER IF EXISTS trg_log_activity ON public.%I', tbl);
    EXECUTE format(
      'CREATE TRIGGER trg_log_activity AFTER INSERT OR DELETE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.log_user_activity(%s)', tbl, quote_literal(ent));

    IF cols <> '' THEN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_log_activity_upd ON public.%I', tbl);
      EXECUTE format(
        'CREATE TRIGGER trg_log_activity_upd AFTER UPDATE ON public.%I '
        'FOR EACH ROW EXECUTE FUNCTION public.log_user_activity(%s)', tbl, args);
    END IF;
  END LOOP;
END $$;

DROP TRIGGER IF EXISTS trg_log_auth_insert ON auth.users;
CREATE TRIGGER trg_log_auth_insert AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.log_auth_activity();

DROP TRIGGER IF EXISTS trg_log_auth_signin ON auth.users;
CREATE TRIGGER trg_log_auth_signin AFTER UPDATE OF last_sign_in_at ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.log_auth_activity();

-- One-off: give every existing user a "signed up" and a "last signed in" line, so
-- the history is not empty on day one. Marked as backfilled.
INSERT INTO public.user_activity (user_id, action, entity, entity_id, detail, created_at)
SELECT u.id, 'auth.sign_up', 'auth', u.id::text, '{"backfilled": true}', u.created_at
  FROM auth.users u
 WHERE NOT EXISTS (SELECT 1 FROM public.user_activity a WHERE a.user_id = u.id AND a.action = 'auth.sign_up');

INSERT INTO public.user_activity (user_id, action, entity, entity_id, detail, created_at)
SELECT u.id, 'auth.sign_in', 'auth', u.id::text, '{"backfilled": true}', u.last_sign_in_at
  FROM auth.users u
 WHERE u.last_sign_in_at IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM public.user_activity a WHERE a.user_id = u.id AND a.action = 'auth.sign_in');

-- ─── Console functions ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.superadmin_require()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'Only a superadmin can view user details' USING ERRCODE = '42501';
  END IF;
END;
$$;

-- Headline numbers for the Users page.
CREATE OR REPLACE FUNCTION public.superadmin_users_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r jsonb;
BEGIN
  PERFORM public.superadmin_require();
  SELECT jsonb_build_object(
    'total',          count(*),
    'new_7d',         count(*) FILTER (WHERE u.created_at > now() - interval '7 days'),
    'new_30d',        count(*) FILTER (WHERE u.created_at > now() - interval '30 days'),
    'active_7d',      count(*) FILTER (WHERE u.last_sign_in_at > now() - interval '7 days'),
    'active_30d',     count(*) FILTER (WHERE u.last_sign_in_at > now() - interval '30 days'),
    'unconfirmed',    count(*) FILTER (WHERE u.email_confirmed_at IS NULL AND u.confirmed_at IS NULL),
    'never_signed_in',count(*) FILTER (WHERE u.last_sign_in_at IS NULL),
    'superadmins',    count(*) FILTER (WHERE p.is_superadmin),
    'deleted',        count(*) FILTER (WHERE coalesce(p.is_deleted, false)),
    'actions_24h',    (SELECT count(*) FROM public.user_activity WHERE created_at > now() - interval '24 hours'
                         AND action NOT LIKE 'auth.%')
  ) INTO r
  FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id;
  RETURN r;
END;
$$;

-- Escapes LIKE wildcards in what the admin typed.
CREATE OR REPLACE FUNCTION public.superadmin_like_escape(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$ SELECT replace(replace(replace(coalesce(p, ''), '\', '\\'), '%', '\%'), '_', '\_') $$;

-- One page of users, with filters and a free-text search.
--   p_filter: all | active_7d | inactive_30d | unconfirmed | never_signed_in | superadmin | deleted | new_7d
CREATE OR REPLACE FUNCTION public.superadmin_list_users(
  p_search text DEFAULT '',
  p_filter text DEFAULT 'all',
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0)
RETURNS TABLE (
  user_id uuid, email text, full_name text, username text, phone text, job_title text,
  created_at timestamptz, last_sign_in_at timestamptz, email_confirmed boolean,
  is_superadmin boolean, is_deleted boolean, banned boolean,
  orgs jsonb, activity_30d bigint, last_activity_at timestamptz, total_count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE pat text := '%' || public.superadmin_like_escape(trim(p_search)) || '%';
BEGIN
  PERFORM public.superadmin_require();
  p_limit := least(greatest(coalesce(p_limit, 50), 1), 200);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  RETURN QUERY
  WITH base AS (
    SELECT u.id,
           u.email::text AS email,
           coalesce(p.full_name, '') AS full_name,
           p.username::text AS username,
           coalesce(p.phone, u.phone, '') AS phone,
           coalesce(p.job_title, '') AS job_title,
           u.created_at,
           u.last_sign_in_at,
           (u.email_confirmed_at IS NOT NULL OR u.confirmed_at IS NOT NULL) AS confirmed,
           coalesce(p.is_superadmin, false) AS is_sa,
           coalesce(p.is_deleted, false) AS is_del,
           (u.banned_until IS NOT NULL AND u.banned_until > now()) AS banned,
           coalesce((
             SELECT jsonb_agg(jsonb_build_object('org_id', o.id, 'name', o.name, 'role', m.role,
                                                 'plan', o.plan, 'status', o.status) ORDER BY o.name)
               FROM public.organization_members m
               JOIN public.organizations o ON o.id = m.org_id
              WHERE m.user_id = u.id AND coalesce(m.is_deleted, false) = false
           ), '[]'::jsonb) AS orgs
      FROM auth.users u
      LEFT JOIN public.profiles p ON p.id = u.id
  ),
  filtered AS (
    SELECT b.* FROM base b
     WHERE (trim(coalesce(p_search, '')) = '' OR
            b.email ILIKE pat ESCAPE '\' OR b.full_name ILIKE pat ESCAPE '\' OR
            coalesce(b.username, '') ILIKE pat ESCAPE '\' OR b.phone ILIKE pat ESCAPE '\' OR
            EXISTS (SELECT 1 FROM jsonb_array_elements(b.orgs) o WHERE (o ->> 'name') ILIKE pat ESCAPE '\'))
       AND CASE p_filter
             WHEN 'active_7d'        THEN b.last_sign_in_at > now() - interval '7 days'
             WHEN 'inactive_30d'     THEN b.last_sign_in_at IS NULL OR b.last_sign_in_at < now() - interval '30 days'
             WHEN 'unconfirmed'      THEN NOT b.confirmed
             WHEN 'never_signed_in'  THEN b.last_sign_in_at IS NULL
             WHEN 'superadmin'       THEN b.is_sa
             WHEN 'deleted'          THEN b.is_del
             WHEN 'new_7d'           THEN b.created_at > now() - interval '7 days'
             ELSE true
           END
  ),
  paged AS (
    SELECT f.*, count(*) OVER () AS total
      FROM filtered f
     ORDER BY f.last_sign_in_at DESC NULLS LAST, f.created_at DESC
     LIMIT p_limit OFFSET p_offset
  )
  SELECT pg.id, pg.email, pg.full_name, pg.username, pg.phone, pg.job_title,
         pg.created_at, pg.last_sign_in_at, pg.confirmed, pg.is_sa, pg.is_del, pg.banned,
         pg.orgs,
         coalesce((SELECT count(*) FROM public.user_activity a
                    WHERE a.user_id = pg.id AND a.created_at > now() - interval '30 days'
                      AND a.action NOT LIKE 'auth.%'), 0),
         (SELECT max(a.created_at) FROM public.user_activity a WHERE a.user_id = pg.id),
         pg.total
    FROM paged pg
   ORDER BY pg.last_sign_in_at DESC NULLS LAST, pg.created_at DESC;
END;
$$;

-- Everything about one user.
CREATE OR REPLACE FUNCTION public.superadmin_user_detail(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r jsonb;
BEGIN
  PERFORM public.superadmin_require();

  SELECT jsonb_build_object(
    'user_id', u.id,
    'email', u.email,
    'full_name', coalesce(p.full_name, ''),
    'username', p.username,
    'phone', coalesce(p.phone, u.phone, ''),
    'job_title', coalesce(p.job_title, ''),
    'avatar_url', coalesce(p.avatar_url, ''),
    'is_superadmin', coalesce(p.is_superadmin, false),
    'is_deleted', coalesce(p.is_deleted, false),
    'created_at', u.created_at,
    'last_sign_in_at', u.last_sign_in_at,
    'email_confirmed_at', coalesce(u.email_confirmed_at, u.confirmed_at),
    'banned_until', u.banned_until,
    'providers', coalesce(u.raw_app_meta_data -> 'providers', '[]'::jsonb),
    'sessions_open', (SELECT count(*) FROM auth.sessions s WHERE s.user_id = u.id),
    'orgs', coalesce((
      SELECT jsonb_agg(jsonb_build_object('org_id', o.id, 'name', o.name, 'role', m.role, 'plan', o.plan,
                                          'status', o.status, 'joined', m.created_at,
                                          'can_manage_billing', m.can_manage_billing,
                                          'trial_ends_at', o.trial_ends_at) ORDER BY m.created_at)
        FROM public.organization_members m
        JOIN public.organizations o ON o.id = m.org_id
       WHERE m.user_id = u.id AND coalesce(m.is_deleted, false) = false), '[]'::jsonb),
    'properties', coalesce((
      SELECT jsonb_agg(jsonb_build_object('property_id', h.id, 'name', h.name, 'role', ps.role, 'org_id', h.org_id)
                       ORDER BY h.name)
        FROM public.property_staff ps
        JOIN public.hotels h ON h.id = ps.property_id
       WHERE ps.user_id = u.id AND coalesce(ps.is_deleted, false) = false), '[]'::jsonb),
    'sessions', coalesce((
      SELECT jsonb_agg(jsonb_build_object('started', s.created_at, 'refreshed', s.refreshed_at,
                                          'user_agent', left(coalesce(s.user_agent, ''), 200),
                                          'ip', host(s.ip)) ORDER BY s.created_at DESC)
        FROM (SELECT * FROM auth.sessions WHERE user_id = u.id ORDER BY created_at DESC LIMIT 10) s), '[]'::jsonb),
    'payments', coalesce((
      SELECT jsonb_agg(jsonb_build_object('id', po.id, 'plan', po.plan_slug, 'cycle', po.billing_cycle,
                                          'amount', po.amount, 'currency', po.currency, 'status', po.status,
                                          'created_at', po.created_at) ORDER BY po.created_at DESC)
        FROM (SELECT * FROM public.payhere_orders WHERE user_id = u.id ORDER BY created_at DESC LIMIT 10) po),
      '[]'::jsonb),
    'invites_sent', (SELECT count(*) FROM public.staff_invites i WHERE i.invited_by = u.id),
    'activity_counts', coalesce((
      SELECT jsonb_agg(jsonb_build_object('action', x.action, 'n', x.n) ORDER BY x.n DESC)
        FROM (SELECT action, count(*) AS n FROM public.user_activity
               WHERE user_id = u.id AND created_at > now() - interval '30 days'
               GROUP BY action ORDER BY count(*) DESC LIMIT 12) x), '[]'::jsonb),
    'activity_total', (SELECT count(*) FROM public.user_activity WHERE user_id = u.id),
    'first_activity_at', (SELECT min(created_at) FROM public.user_activity WHERE user_id = u.id),
    'last_activity_at',  (SELECT max(created_at) FROM public.user_activity WHERE user_id = u.id AND action NOT LIKE 'auth.%')
  ) INTO r
  FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id
  WHERE u.id = p_user_id;

  IF r IS NULL THEN
    RAISE EXCEPTION 'No such user' USING ERRCODE = 'P0002';
  END IF;
  RETURN r;
END;
$$;

-- A page of the activity log: for one user, one company, or everyone. Newest first;
-- pass the last row's created_at as p_before for the next page.
CREATE OR REPLACE FUNCTION public.superadmin_user_activity(
  p_user_id uuid DEFAULT NULL,
  p_org_id uuid DEFAULT NULL,
  p_action_prefix text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_before timestamptz DEFAULT NULL)
RETURNS TABLE (
  id bigint, created_at timestamptz, user_id uuid, user_email text, user_name text,
  org_id uuid, org_name text, property_id uuid, property_name text,
  action text, entity text, entity_id text, detail jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.superadmin_require();
  p_limit := least(greatest(coalesce(p_limit, 50), 1), 200);

  RETURN QUERY
  SELECT a.id, a.created_at, a.user_id, u.email::text, coalesce(p.full_name, ''),
         a.org_id, o.name, a.property_id, h.name,
         a.action, a.entity, a.entity_id, a.detail
    FROM public.user_activity a
    LEFT JOIN auth.users u ON u.id = a.user_id
    LEFT JOIN public.profiles p ON p.id = a.user_id
    LEFT JOIN public.organizations o ON o.id = a.org_id
    LEFT JOIN public.hotels h ON h.id = a.property_id
   WHERE (p_user_id IS NULL OR a.user_id = p_user_id)
     AND (p_org_id IS NULL OR a.org_id = p_org_id)
     AND (p_action_prefix IS NULL OR p_action_prefix = '' OR a.action LIKE public.superadmin_like_escape(p_action_prefix) || '%' ESCAPE '\')
     AND (p_before IS NULL OR a.created_at < p_before)
   ORDER BY a.created_at DESC, a.id DESC
   LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION
  public.superadmin_require(),
  public.superadmin_users_overview(),
  public.superadmin_like_escape(text),
  public.superadmin_list_users(text, text, integer, integer),
  public.superadmin_user_detail(uuid),
  public.superadmin_user_activity(uuid, uuid, text, integer, timestamptz)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.superadmin_users_overview(),
  public.superadmin_list_users(text, text, integer, integer),
  public.superadmin_user_detail(uuid),
  public.superadmin_user_activity(uuid, uuid, text, integer, timestamptz)
TO authenticated;
