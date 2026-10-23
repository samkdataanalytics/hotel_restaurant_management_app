-- ============================================================================
-- Superadmin: companies, properties and the platform as a whole.
--
-- 20261023000002 added who the users are and what they do. This adds the rest of
-- the picture, so a superadmin can follow any thread:
--
--   platform  ->  company  ->  property  ->  people  ->  what they did
--
--   * superadmin_platform_overview   headline numbers, 14-day trend, who is busy,
--                                    whose trial is about to end, who is dormant
--   * superadmin_list_companies      every company with owner, plan, usage, activity
--   * superadmin_company_detail      one company: details, limits vs usage, members,
--                                    properties, payments, activity breakdown
--   * superadmin_list_properties     every property with its company and activity
--   * superadmin_property_detail     one property: details, staff, rooms, tables,
--                                    bookings, orders, expenses, activity breakdown
--   * superadmin_activity            the activity log filtered by user, company,
--                                    property or action
--
-- It also starts logging changes to the things only a superadmin or an owner
-- changes: properties, plans, property settings and enterprise leads.
--
-- Guest personal data is never selected: bookings and orders are shown by
-- reference, status, dates and amount.
-- ============================================================================

-- ─── More of the log ────────────────────────────────────────────────────────

-- Same function as 20261023000002, with "name" added to the harmless fields (a
-- property, plan or menu item name is business data, not personal data) and the
-- property itself recognised as the place an entry happened.
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
        RETURN NULL;
      END IF;
      d := jsonb_build_object('changed', changed);
      IF changed ? 'status' AND jsonb_typeof(j -> 'status') = 'string' THEN
        act := entity || '.' || regexp_replace(lower(j ->> 'status'), '[^a-z0-9]+', '_', 'g');
      END IF;
    END IF;

    FOREACH k IN ARRAY ARRAY['name','status','payment_status','booking_ref','order_number','type','source',
                             'category','role','plan','billing_cycle','room_number','amount','total_amount',
                             'plan_slug','price_monthly','target_user','invited_email_domain']
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
      d := d || jsonb_build_object('invited_email_domain', split_part(j ->> 'invited_email', '@', 2));
    END IF;

    hotel := coalesce(nullif(j ->> 'hotel_id', '')::uuid, nullif(j ->> 'property_id', '')::uuid);
    IF hotel IS NULL AND entity = 'property' THEN
      hotel := nullif(j ->> 'id', '')::uuid;       -- a property's own changes happen "at" it
    END IF;
    org := nullif(j ->> 'org_id', '')::uuid;
    IF org IS NULL AND entity = 'org' THEN
      org := nullif(j ->> 'id', '')::uuid;
    END IF;
    IF org IS NULL AND hotel IS NOT NULL THEN
      SELECT h.org_id INTO org FROM public.hotels h WHERE h.id = hotel;
    END IF;

    actor := auth.uid();
    IF actor IS NULL AND entity = 'payment' THEN
      actor := nullif(j ->> 'user_id', '')::uuid;
    END IF;

    INSERT INTO public.user_activity (user_id, org_id, property_id, action, entity, entity_id, detail)
    VALUES (actor, org, hotel, act, entity, coalesce(j ->> 'id', j ->> 'hotel_id', ''), d);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_user_activity() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  spec text[][] := ARRAY[
    ['hotels',           'property',      'name,status,type,currency,is_deleted,city,country'],
    ['hotel_settings',   'property_settings', 'currency_symbol,tax_rate,service_charge_rate'],
    ['plans',            'plan',          'price_monthly,is_active,max_properties,max_users,max_rooms,max_tables,is_custom_price'],
    ['enterprise_leads', 'lead',          'status']
  ];
  i int; tbl text; ent text; cols text; args text;
BEGIN
  FOR i IN 1 .. array_length(spec, 1) LOOP
    tbl := spec[i][1]; ent := spec[i][2]; cols := spec[i][3];
    CONTINUE WHEN to_regclass('public.' || tbl) IS NULL;

    args := quote_literal(ent) || ', ' ||
            (SELECT string_agg(quote_literal(c), ', ') FROM unnest(string_to_array(cols, ',')) c);

    EXECUTE format('DROP TRIGGER IF EXISTS trg_log_activity ON public.%I', tbl);
    EXECUTE format('CREATE TRIGGER trg_log_activity AFTER INSERT OR DELETE ON public.%I '
                   'FOR EACH ROW EXECUTE FUNCTION public.log_user_activity(%s)', tbl, quote_literal(ent));
    EXECUTE format('DROP TRIGGER IF EXISTS trg_log_activity_upd ON public.%I', tbl);
    EXECUTE format('CREATE TRIGGER trg_log_activity_upd AFTER UPDATE ON public.%I '
                   'FOR EACH ROW EXECUTE FUNCTION public.log_user_activity(%s)', tbl, args);
  END LOOP;
END $$;

-- ─── Shared pieces ──────────────────────────────────────────────────────────

-- A company's status as it really is: "trialing" past its deadline is expired,
-- even if nobody has signed in to flip the stored value.
CREATE OR REPLACE FUNCTION public.superadmin_effective_status(p_status text, p_trial_ends timestamptz)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT CASE WHEN p_status = 'trialing' AND p_trial_ends IS NOT NULL AND p_trial_ends <= now()
              THEN 'trial_expired' ELSE coalesce(p_status, 'unknown') END
$$;

-- ─── Platform overview ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.superadmin_platform_overview()
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
    'companies', jsonb_build_object(
      'total',   (SELECT count(*) FROM public.organizations o WHERE NOT coalesce(o.is_deleted, false)),
      'deleted', (SELECT count(*) FROM public.organizations o WHERE coalesce(o.is_deleted, false)),
      'new_30d', (SELECT count(*) FROM public.organizations o
                   WHERE NOT coalesce(o.is_deleted, false) AND o.created_at > now() - interval '30 days'),
      'by_status', (SELECT coalesce(jsonb_object_agg(s.st, s.n), '{}'::jsonb)
                      FROM (SELECT public.superadmin_effective_status(o.status, o.trial_ends_at) AS st, count(*) AS n
                              FROM public.organizations o WHERE NOT coalesce(o.is_deleted, false) GROUP BY 1) s),
      'by_plan',   (SELECT coalesce(jsonb_object_agg(s.pl, s.n), '{}'::jsonb)
                      FROM (SELECT coalesce(o.plan, 'unknown') AS pl, count(*) AS n
                              FROM public.organizations o WHERE NOT coalesce(o.is_deleted, false) GROUP BY 1) s),
      'dormant_30d', (SELECT count(*) FROM public.organizations o
                       WHERE NOT coalesce(o.is_deleted, false)
                         AND NOT EXISTS (SELECT 1 FROM public.user_activity a
                                          WHERE a.org_id = o.id AND a.action NOT LIKE 'auth.%'
                                            AND a.created_at > now() - interval '30 days'))
    ),
    'properties', jsonb_build_object(
      'total',   (SELECT count(*) FROM public.hotels h WHERE NOT coalesce(h.is_deleted, false)),
      'active',  (SELECT count(*) FROM public.hotels h WHERE NOT coalesce(h.is_deleted, false) AND h.status = 'active'),
      'new_30d', (SELECT count(*) FROM public.hotels h
                   WHERE NOT coalesce(h.is_deleted, false) AND h.created_at > now() - interval '30 days'),
      'by_type', (SELECT coalesce(jsonb_object_agg(s.t, s.n), '{}'::jsonb)
                    FROM (SELECT coalesce(h.type, 'unknown') AS t, count(*) AS n
                            FROM public.hotels h WHERE NOT coalesce(h.is_deleted, false) GROUP BY 1) s)
    ),
    'users', jsonb_build_object(
      'total',     (SELECT count(*) FROM auth.users),
      'active_7d', (SELECT count(*) FROM auth.users u WHERE u.last_sign_in_at > now() - interval '7 days')
    ),
    'inventory', jsonb_build_object(
      'rooms',  (SELECT count(*) FROM public.rooms),
      'tables', (SELECT count(*) FROM public.restaurant_tables)
    ),
    'bookings', jsonb_build_object(
      'total',        (SELECT count(*) FROM public.bookings),
      'last_30d',     (SELECT count(*) FROM public.bookings b WHERE b.created_at > now() - interval '30 days'),
      'paid_value_30d', (SELECT coalesce(sum(b.total_amount), 0) FROM public.bookings b
                          WHERE b.is_paid AND b.created_at > now() - interval '30 days')
    ),
    'orders', jsonb_build_object(
      'total',    (SELECT count(*) FROM public.restaurant_orders),
      'last_30d', (SELECT count(*) FROM public.restaurant_orders o WHERE o.created_at > now() - interval '30 days')
    ),
    'subscriptions', jsonb_build_object(
      'paid_count',  (SELECT count(*) FROM public.payhere_orders p WHERE p.status = 'success'),
      'paid_amount', (SELECT coalesce(sum(p.amount), 0) FROM public.payhere_orders p WHERE p.status = 'success'),
      'paid_30d',    (SELECT coalesce(sum(p.amount), 0) FROM public.payhere_orders p
                       WHERE p.status = 'success' AND p.created_at > now() - interval '30 days'),
      'pending',     (SELECT count(*) FROM public.payhere_orders p WHERE p.status = 'pending')
    ),
    'activity', jsonb_build_object(
      'actions_24h', (SELECT count(*) FROM public.user_activity a
                       WHERE a.created_at > now() - interval '24 hours' AND a.action NOT LIKE 'auth.%'),
      'actions_7d',  (SELECT count(*) FROM public.user_activity a
                       WHERE a.created_at > now() - interval '7 days' AND a.action NOT LIKE 'auth.%'),
      'daily', (SELECT coalesce(jsonb_agg(jsonb_build_object('day', d.day, 'signups', d.signups,
                                                              'sign_ins', d.sign_ins, 'actions', d.actions)
                                           ORDER BY d.day), '[]'::jsonb)
                  FROM (SELECT g.day::date AS day,
                               count(*) FILTER (WHERE a.action = 'auth.sign_up')  AS signups,
                               count(*) FILTER (WHERE a.action = 'auth.sign_in')  AS sign_ins,
                               count(*) FILTER (WHERE a.action NOT LIKE 'auth.%') AS actions
                          FROM generate_series(current_date - 13, current_date, interval '1 day') g(day)
                          LEFT JOIN public.user_activity a ON a.created_at::date = g.day::date
                         GROUP BY g.day) d)
    ),
    'busiest_companies', (SELECT coalesce(jsonb_agg(jsonb_build_object('org_id', t.org_id, 'name', t.name, 'actions', t.n)
                                                     ORDER BY t.n DESC), '[]'::jsonb)
                            FROM (SELECT a.org_id, o.name, count(*) AS n
                                    FROM public.user_activity a JOIN public.organizations o ON o.id = a.org_id
                                   WHERE a.created_at > now() - interval '30 days' AND a.action NOT LIKE 'auth.%'
                                   GROUP BY a.org_id, o.name ORDER BY count(*) DESC LIMIT 5) t),
    'trials_ending', (SELECT coalesce(jsonb_agg(jsonb_build_object('org_id', t.id, 'name', t.name,
                                                                    'trial_ends_at', t.trial_ends_at) ORDER BY t.trial_ends_at), '[]'::jsonb)
                        FROM (SELECT o.id, o.name, o.trial_ends_at FROM public.organizations o
                               WHERE NOT coalesce(o.is_deleted, false) AND o.status = 'trialing'
                                 AND o.trial_ends_at > now() AND o.trial_ends_at <= now() + interval '7 days'
                               ORDER BY o.trial_ends_at LIMIT 8) t)
  ) INTO r;
  RETURN r;
END;
$$;

-- ─── Companies ──────────────────────────────────────────────────────────────
--   p_filter: all | active | trialing | trial_expired | suspended | trial_ending |
--             no_properties | dormant | deleted

CREATE OR REPLACE FUNCTION public.superadmin_list_companies(
  p_search text DEFAULT '',
  p_filter text DEFAULT 'all',
  p_limit integer DEFAULT 25,
  p_offset integer DEFAULT 0)
RETURNS TABLE (
  org_id uuid, name text, slug text, plan text, status text, country text, phone text, email text,
  created_at timestamptz, trial_ends_at timestamptz, billing_cycle text, subscription_paid_at timestamptz,
  logo_url text, custom_price_monthly numeric, custom_price_annually numeric,
  is_deleted boolean, owner_id uuid, owner_name text, owner_email text,
  members bigint, properties bigint, rooms bigint, tables bigint,
  bookings_30d bigint, orders_30d bigint, actions_30d bigint,
  last_activity_at timestamptz, last_sign_in_at timestamptz, total_count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE pat text := '%' || public.superadmin_like_escape(trim(p_search)) || '%';
BEGIN
  PERFORM public.superadmin_require();
  p_limit := least(greatest(coalesce(p_limit, 25), 1), 200);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  RETURN QUERY
  WITH base AS (
    SELECT o.id AS ouid, o.name AS oname, o.slug AS oslug, coalesce(o.plan, '') AS oplan,
           public.superadmin_effective_status(o.status, o.trial_ends_at) AS ostatus,
           coalesce(o.country, '') AS ocountry, coalesce(o.phone, '') AS ophone, coalesce(o.email, '') AS oemail,
           o.created_at AS ocreated, o.trial_ends_at AS otrial, o.billing_cycle AS ocycle,
           o.subscription_paid_at AS opaid, coalesce(o.is_deleted, false) AS odel,
           coalesce(o.logo_url, '') AS ologo, o.custom_price_monthly AS ocpm, o.custom_price_annually AS ocpa,
           ow.user_id AS owner_uid,
           (SELECT count(*) FROM public.organization_members m WHERE m.org_id = o.id AND NOT coalesce(m.is_deleted, false)) AS n_members,
           (SELECT count(*) FROM public.hotels h WHERE h.org_id = o.id AND NOT coalesce(h.is_deleted, false)) AS n_props,
           (SELECT count(*) FROM public.rooms r JOIN public.hotels h ON h.id = r.hotel_id WHERE h.org_id = o.id) AS n_rooms,
           (SELECT count(*) FROM public.restaurant_tables t JOIN public.hotels h ON h.id = t.hotel_id WHERE h.org_id = o.id) AS n_tables,
           (SELECT count(*) FROM public.bookings b JOIN public.hotels h ON h.id = b.hotel_id
             WHERE h.org_id = o.id AND b.created_at > now() - interval '30 days') AS n_book30,
           (SELECT count(*) FROM public.restaurant_orders x JOIN public.hotels h ON h.id = x.hotel_id
             WHERE h.org_id = o.id AND x.created_at > now() - interval '30 days') AS n_ord30,
           (SELECT count(*) FROM public.user_activity a
             WHERE a.org_id = o.id AND a.action NOT LIKE 'auth.%' AND a.created_at > now() - interval '30 days') AS n_act30,
           (SELECT max(a.created_at) FROM public.user_activity a WHERE a.org_id = o.id AND a.action NOT LIKE 'auth.%') AS last_act,
           (SELECT max(u.last_sign_in_at) FROM public.organization_members m JOIN auth.users u ON u.id = m.user_id
             WHERE m.org_id = o.id AND NOT coalesce(m.is_deleted, false)) AS last_in
      FROM public.organizations o
      LEFT JOIN LATERAL (
        SELECT m.user_id FROM public.organization_members m
         WHERE m.org_id = o.id AND NOT coalesce(m.is_deleted, false)
         ORDER BY (m.role = 'owner') DESC, m.created_at LIMIT 1) ow ON true
  ),
  filtered AS (
    SELECT b.* FROM base b
      LEFT JOIN public.profiles pr ON pr.id = b.owner_uid
      LEFT JOIN auth.users au ON au.id = b.owner_uid
     WHERE (trim(coalesce(p_search, '')) = '' OR
            b.oname ILIKE pat ESCAPE '\' OR b.oslug ILIKE pat ESCAPE '\' OR b.oemail ILIKE pat ESCAPE '\' OR
            b.ophone ILIKE pat ESCAPE '\' OR b.ocountry ILIKE pat ESCAPE '\' OR
            coalesce(pr.full_name, '') ILIKE pat ESCAPE '\' OR coalesce(au.email::text, '') ILIKE pat ESCAPE '\')
       AND CASE p_filter
             WHEN 'deleted'       THEN b.odel
             WHEN 'active'        THEN NOT b.odel AND b.ostatus = 'active'
             WHEN 'trialing'      THEN NOT b.odel AND b.ostatus = 'trialing'
             WHEN 'trial_expired' THEN NOT b.odel AND b.ostatus = 'trial_expired'
             WHEN 'suspended'     THEN NOT b.odel AND b.ostatus = 'suspended'
             WHEN 'trial_ending'  THEN NOT b.odel AND b.ostatus = 'trialing' AND b.otrial <= now() + interval '7 days'
             WHEN 'no_properties' THEN NOT b.odel AND b.n_props = 0
             WHEN 'dormant'       THEN NOT b.odel AND b.n_act30 = 0
             ELSE NOT b.odel
           END
  ),
  paged AS (
    SELECT f.*, count(*) OVER () AS total
      FROM filtered f
     ORDER BY f.last_act DESC NULLS LAST, f.ocreated DESC
     LIMIT p_limit OFFSET p_offset
  )
  SELECT pg.ouid, pg.oname, pg.oslug, pg.oplan, pg.ostatus, pg.ocountry, pg.ophone, pg.oemail,
         pg.ocreated, pg.otrial, pg.ocycle, pg.opaid, pg.ologo, pg.ocpm, pg.ocpa, pg.odel,
         pg.owner_uid, coalesce(p2.full_name, ''), au2.email::text,
         pg.n_members, pg.n_props, pg.n_rooms, pg.n_tables, pg.n_book30, pg.n_ord30, pg.n_act30,
         pg.last_act, pg.last_in, pg.total
    FROM paged pg
    LEFT JOIN public.profiles p2 ON p2.id = pg.owner_uid
    LEFT JOIN auth.users au2 ON au2.id = pg.owner_uid
   ORDER BY pg.last_act DESC NULLS LAST, pg.ocreated DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.superadmin_company_detail(p_org_id uuid)
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
    'org_id', o.id,
    'name', o.name, 'slug', o.slug,
    'plan', coalesce(o.plan, ''), 'status', public.superadmin_effective_status(o.status, o.trial_ends_at),
    'stored_status', o.status,
    'country', coalesce(o.country, ''), 'country_code', coalesce(o.country_code, ''),
    'phone', coalesce(o.phone, ''), 'email', coalesce(o.email, ''), 'logo_url', coalesce(o.logo_url, ''),
    'created_at', o.created_at, 'created_by', o.created_by,
    'created_by_name', (SELECT coalesce(p.full_name, '') FROM public.profiles p WHERE p.id = o.created_by),
    'created_by_email', (SELECT u.email FROM auth.users u WHERE u.id = o.created_by),
    'is_deleted', coalesce(o.is_deleted, false), 'deleted_at', o.deleted_at,
    'trial_ends_at', o.trial_ends_at, 'billing_cycle', o.billing_cycle,
    'subscription_paid_at', o.subscription_paid_at,
    'custom_price_monthly', o.custom_price_monthly, 'custom_price_annually', o.custom_price_annually,
    'limits', jsonb_build_object(
      'properties', jsonb_build_object('max', coalesce(o.custom_max_properties, pl.max_properties),
                      'used', (SELECT count(*) FROM public.hotels h WHERE h.org_id = o.id AND NOT coalesce(h.is_deleted, false))),
      'users',      jsonb_build_object('max', coalesce(o.custom_max_users, pl.max_users),
                      'used', (SELECT count(*) FROM public.organization_members m WHERE m.org_id = o.id AND NOT coalesce(m.is_deleted, false))),
      'rooms',      jsonb_build_object('max', coalesce(o.custom_max_rooms, pl.max_rooms),
                      'used', (SELECT count(*) FROM public.rooms r JOIN public.hotels h ON h.id = r.hotel_id WHERE h.org_id = o.id)),
      'tables',     jsonb_build_object('max', coalesce(o.custom_max_tables, pl.max_tables),
                      'used', (SELECT count(*) FROM public.restaurant_tables t JOIN public.hotels h ON h.id = t.hotel_id WHERE h.org_id = o.id))
    ),
    'totals', jsonb_build_object(
      'bookings',      (SELECT count(*) FROM public.bookings b JOIN public.hotels h ON h.id = b.hotel_id WHERE h.org_id = o.id),
      'bookings_30d',  (SELECT count(*) FROM public.bookings b JOIN public.hotels h ON h.id = b.hotel_id
                         WHERE h.org_id = o.id AND b.created_at > now() - interval '30 days'),
      'paid_bookings_value', (SELECT coalesce(sum(b.total_amount), 0) FROM public.bookings b JOIN public.hotels h ON h.id = b.hotel_id
                               WHERE h.org_id = o.id AND b.is_paid),
      'orders',        (SELECT count(*) FROM public.restaurant_orders x JOIN public.hotels h ON h.id = x.hotel_id WHERE h.org_id = o.id),
      'orders_30d',    (SELECT count(*) FROM public.restaurant_orders x JOIN public.hotels h ON h.id = x.hotel_id
                         WHERE h.org_id = o.id AND x.created_at > now() - interval '30 days'),
      'expenses_value',(SELECT coalesce(sum(e.amount), 0) FROM public.expenses e JOIN public.hotels h ON h.id = e.hotel_id WHERE h.org_id = o.id),
      'pending_invites', (SELECT count(*) FROM public.staff_invites i WHERE i.org_id = o.id AND i.status = 'pending')
    ),
    'members', coalesce((
      SELECT jsonb_agg(jsonb_build_object('user_id', m.user_id, 'name', coalesce(p.full_name, ''), 'email', u.email,
                                          'username', p.username, 'role', m.role, 'joined', m.created_at,
                                          'last_sign_in_at', u.last_sign_in_at,
                                          'can_manage_billing', m.can_manage_billing,
                                          'actions_30d', (SELECT count(*) FROM public.user_activity a
                                                           WHERE a.user_id = m.user_id AND a.org_id = o.id
                                                             AND a.action NOT LIKE 'auth.%' AND a.created_at > now() - interval '30 days'))
                       ORDER BY (m.role = 'owner') DESC, m.created_at)
        FROM public.organization_members m
        LEFT JOIN auth.users u ON u.id = m.user_id
        LEFT JOIN public.profiles p ON p.id = m.user_id
       WHERE m.org_id = o.id AND NOT coalesce(m.is_deleted, false)), '[]'::jsonb),
    'properties', coalesce((
      SELECT jsonb_agg(jsonb_build_object('property_id', h.id, 'name', h.name, 'type', h.type, 'city', coalesce(h.city, ''),
                                          'country', coalesce(h.country, ''), 'status', h.status, 'created_at', h.created_at,
                                          'rooms', (SELECT count(*) FROM public.rooms r WHERE r.hotel_id = h.id),
                                          'tables', (SELECT count(*) FROM public.restaurant_tables t WHERE t.hotel_id = h.id),
                                          'bookings_30d', (SELECT count(*) FROM public.bookings b WHERE b.hotel_id = h.id AND b.created_at > now() - interval '30 days'),
                                          'orders_30d', (SELECT count(*) FROM public.restaurant_orders x WHERE x.hotel_id = h.id AND x.created_at > now() - interval '30 days'),
                                          'last_activity_at', (SELECT max(a.created_at) FROM public.user_activity a WHERE a.property_id = h.id AND a.action NOT LIKE 'auth.%'))
                       ORDER BY h.created_at)
        FROM public.hotels h WHERE h.org_id = o.id AND NOT coalesce(h.is_deleted, false)), '[]'::jsonb),
    'payments', coalesce((
      SELECT jsonb_agg(jsonb_build_object('id', po.id, 'plan', po.plan_slug, 'cycle', po.billing_cycle, 'amount', po.amount,
                                          'currency', po.currency, 'status', po.status, 'created_at', po.created_at,
                                          'payer', (SELECT coalesce(p.full_name, u.email::text) FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id WHERE u.id = po.user_id))
                       ORDER BY po.created_at DESC)
        FROM (SELECT * FROM public.payhere_orders x WHERE x.org_id = o.id ORDER BY x.created_at DESC LIMIT 12) po), '[]'::jsonb),
    'activity_counts', coalesce((
      SELECT jsonb_agg(jsonb_build_object('action', x.action, 'n', x.n) ORDER BY x.n DESC)
        FROM (SELECT a.action, count(*) AS n FROM public.user_activity a
               WHERE a.org_id = o.id AND a.created_at > now() - interval '30 days' AND a.action NOT LIKE 'auth.%'
               GROUP BY a.action ORDER BY count(*) DESC LIMIT 12) x), '[]'::jsonb),
    'activity_total', (SELECT count(*) FROM public.user_activity a WHERE a.org_id = o.id),
    'first_activity_at', (SELECT min(a.created_at) FROM public.user_activity a WHERE a.org_id = o.id),
    'last_activity_at',  (SELECT max(a.created_at) FROM public.user_activity a WHERE a.org_id = o.id AND a.action NOT LIKE 'auth.%')
  ) INTO r
  FROM public.organizations o
  LEFT JOIN public.plans pl ON pl.slug = o.plan
  WHERE o.id = p_org_id;

  IF r IS NULL THEN
    RAISE EXCEPTION 'No such company' USING ERRCODE = 'P0002';
  END IF;
  RETURN r;
END;
$$;

-- ─── Properties ─────────────────────────────────────────────────────────────
--   p_filter: all | active | inactive | hotel | restaurant | both | no_activity | deleted

CREATE OR REPLACE FUNCTION public.superadmin_list_properties(
  p_search text DEFAULT '',
  p_filter text DEFAULT 'all',
  p_org_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 25,
  p_offset integer DEFAULT 0)
RETURNS TABLE (
  property_id uuid, org_id uuid, org_name text, org_plan text, org_status text,
  name text, type text, city text, country text, status text, currency text, is_deleted boolean,
  created_at timestamptz, rooms bigint, tables bigint, staff bigint,
  bookings_total bigint, bookings_30d bigint, orders_30d bigint, paid_value_30d numeric,
  actions_30d bigint, last_activity_at timestamptz, total_count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE pat text := '%' || public.superadmin_like_escape(trim(p_search)) || '%';
BEGIN
  PERFORM public.superadmin_require();
  p_limit := least(greatest(coalesce(p_limit, 25), 1), 200);
  p_offset := greatest(coalesce(p_offset, 0), 0);

  RETURN QUERY
  WITH base AS (
    SELECT h.id AS hid, h.org_id AS horg, o.name AS oname, coalesce(o.plan, '') AS oplan,
           public.superadmin_effective_status(o.status, o.trial_ends_at) AS ostatus,
           h.name AS hname, coalesce(h.type, '') AS htype, coalesce(h.city, '') AS hcity, coalesce(h.country, '') AS hcountry,
           coalesce(h.status, '') AS hstatus, coalesce(h.currency, '') AS hcur, coalesce(h.is_deleted, false) AS hdel,
           h.created_at AS hcreated,
           (SELECT count(*) FROM public.rooms r WHERE r.hotel_id = h.id) AS n_rooms,
           (SELECT count(*) FROM public.restaurant_tables t WHERE t.hotel_id = h.id) AS n_tables,
           (SELECT count(DISTINCT x.uid) FROM (
              SELECT ps.user_id AS uid FROM public.property_staff ps WHERE ps.property_id = h.id AND NOT coalesce(ps.is_deleted, false)
              UNION SELECT hu.user_id FROM public.hotel_users hu WHERE hu.hotel_id = h.id) x) AS n_staff,
           (SELECT count(*) FROM public.bookings b WHERE b.hotel_id = h.id) AS n_book,
           (SELECT count(*) FROM public.bookings b WHERE b.hotel_id = h.id AND b.created_at > now() - interval '30 days') AS n_book30,
           (SELECT count(*) FROM public.restaurant_orders x WHERE x.hotel_id = h.id AND x.created_at > now() - interval '30 days') AS n_ord30,
           (SELECT coalesce(sum(b.total_amount), 0) FROM public.bookings b
             WHERE b.hotel_id = h.id AND b.is_paid AND b.created_at > now() - interval '30 days') AS paid30,
           (SELECT count(*) FROM public.user_activity a
             WHERE a.property_id = h.id AND a.action NOT LIKE 'auth.%' AND a.created_at > now() - interval '30 days') AS n_act30,
           (SELECT max(a.created_at) FROM public.user_activity a WHERE a.property_id = h.id AND a.action NOT LIKE 'auth.%') AS last_act
      FROM public.hotels h
      LEFT JOIN public.organizations o ON o.id = h.org_id
     WHERE p_org_id IS NULL OR h.org_id = p_org_id
  ),
  filtered AS (
    SELECT b.* FROM base b
     WHERE (trim(coalesce(p_search, '')) = '' OR
            b.hname ILIKE pat ESCAPE '\' OR coalesce(b.oname, '') ILIKE pat ESCAPE '\' OR
            b.hcity ILIKE pat ESCAPE '\' OR b.hcountry ILIKE pat ESCAPE '\')
       AND CASE p_filter
             WHEN 'deleted'     THEN b.hdel
             WHEN 'active'      THEN NOT b.hdel AND b.hstatus = 'active'
             WHEN 'inactive'    THEN NOT b.hdel AND b.hstatus <> 'active'
             WHEN 'hotel'       THEN NOT b.hdel AND b.htype = 'hotel'
             WHEN 'restaurant'  THEN NOT b.hdel AND b.htype = 'restaurant'
             WHEN 'both'        THEN NOT b.hdel AND b.htype = 'both'
             WHEN 'no_activity' THEN NOT b.hdel AND b.n_act30 = 0
             ELSE NOT b.hdel
           END
  ),
  paged AS (
    SELECT f.*, count(*) OVER () AS total
      FROM filtered f
     ORDER BY f.last_act DESC NULLS LAST, f.hcreated DESC
     LIMIT p_limit OFFSET p_offset
  )
  SELECT pg.hid, pg.horg, pg.oname, pg.oplan, pg.ostatus, pg.hname, pg.htype, pg.hcity, pg.hcountry, pg.hstatus, pg.hcur,
         pg.hdel, pg.hcreated, pg.n_rooms, pg.n_tables, pg.n_staff, pg.n_book, pg.n_book30, pg.n_ord30, pg.paid30,
         pg.n_act30, pg.last_act, pg.total
    FROM paged pg
   ORDER BY pg.last_act DESC NULLS LAST, pg.hcreated DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.superadmin_property_detail(p_property_id uuid)
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
    'property_id', h.id, 'name', h.name, 'slug', h.slug, 'type', coalesce(h.type, ''),
    'address', coalesce(h.address, ''), 'city', coalesce(h.city, ''), 'country', coalesce(h.country, ''),
    'phone', coalesce(h.phone, ''), 'email', coalesce(h.email, ''), 'timezone', coalesce(h.timezone, ''),
    'currency', coalesce(h.currency, ''), 'status', coalesce(h.status, ''), 'logo_url', coalesce(h.logo_url, ''),
    'booking_channels', coalesce(h.booking_channels, '[]'::jsonb),
    'is_deleted', coalesce(h.is_deleted, false), 'deleted_at', h.deleted_at, 'created_at', h.created_at,
    'company', jsonb_build_object('org_id', o.id, 'name', o.name, 'plan', coalesce(o.plan, ''),
                                  'status', public.superadmin_effective_status(o.status, o.trial_ends_at)),
    'settings', (SELECT jsonb_build_object('tax_rate', s.tax_rate, 'service_charge_rate', s.service_charge_rate,
                                           'currency_symbol', s.currency_symbol, 'updated_at', s.updated_at)
                   FROM public.hotel_settings s WHERE s.hotel_id = h.id),
    'rooms_by_status', (SELECT coalesce(jsonb_object_agg(x.s, x.n), '{}'::jsonb)
                          FROM (SELECT coalesce(r.status, 'unknown') AS s, count(*) AS n FROM public.rooms r WHERE r.hotel_id = h.id GROUP BY 1) x),
    'tables_by_status', (SELECT coalesce(jsonb_object_agg(x.s, x.n), '{}'::jsonb)
                           FROM (SELECT coalesce(t.status, 'unknown') AS s, count(*) AS n FROM public.restaurant_tables t WHERE t.hotel_id = h.id GROUP BY 1) x),
    'bookings_by_status', (SELECT coalesce(jsonb_object_agg(x.s, x.n), '{}'::jsonb)
                             FROM (SELECT coalesce(b.status, 'unknown') AS s, count(*) AS n FROM public.bookings b WHERE b.hotel_id = h.id GROUP BY 1) x),
    'orders_by_status', (SELECT coalesce(jsonb_object_agg(x.s, x.n), '{}'::jsonb)
                           FROM (SELECT coalesce(q.status, 'unknown') AS s, count(*) AS n FROM public.restaurant_orders q WHERE q.hotel_id = h.id GROUP BY 1) x),
    'totals', jsonb_build_object(
      'bookings',       (SELECT count(*) FROM public.bookings b WHERE b.hotel_id = h.id),
      'bookings_30d',   (SELECT count(*) FROM public.bookings b WHERE b.hotel_id = h.id AND b.created_at > now() - interval '30 days'),
      'paid_value',     (SELECT coalesce(sum(b.total_amount), 0) FROM public.bookings b WHERE b.hotel_id = h.id AND b.is_paid),
      'paid_value_30d', (SELECT coalesce(sum(b.total_amount), 0) FROM public.bookings b
                          WHERE b.hotel_id = h.id AND b.is_paid AND b.created_at > now() - interval '30 days'),
      'orders',         (SELECT count(*) FROM public.restaurant_orders q WHERE q.hotel_id = h.id),
      'orders_30d',     (SELECT count(*) FROM public.restaurant_orders q WHERE q.hotel_id = h.id AND q.created_at > now() - interval '30 days'),
      'expenses_30d',   (SELECT coalesce(sum(e.amount), 0) FROM public.expenses e
                          WHERE e.hotel_id = h.id AND e.date > now() - interval '30 days'),
      'menu_items',     (SELECT count(*) FROM public.menu_items m WHERE m.hotel_id = h.id)
    ),
    'expenses_by_category', coalesce((
      SELECT jsonb_agg(jsonb_build_object('category', x.c, 'amount', x.a) ORDER BY x.a DESC)
        FROM (SELECT coalesce(e.category, 'other') AS c, sum(e.amount) AS a FROM public.expenses e
               WHERE e.hotel_id = h.id AND e.date > now() - interval '30 days' GROUP BY 1) x), '[]'::jsonb),
    'staff', coalesce((
      SELECT jsonb_agg(jsonb_build_object('user_id', s.uid, 'name', coalesce(p.full_name, ''), 'email', u.email,
                                          'username', p.username, 'role', s.role, 'last_sign_in_at', u.last_sign_in_at,
                                          'actions_30d', (SELECT count(*) FROM public.user_activity a
                                                           WHERE a.user_id = s.uid AND a.property_id = h.id
                                                             AND a.action NOT LIKE 'auth.%' AND a.created_at > now() - interval '30 days'))
                       ORDER BY s.role, p.full_name)
        FROM (SELECT ps.user_id AS uid, ps.role::text AS role FROM public.property_staff ps
               WHERE ps.property_id = h.id AND NOT coalesce(ps.is_deleted, false)) s
        LEFT JOIN auth.users u ON u.id = s.uid
        LEFT JOIN public.profiles p ON p.id = s.uid), '[]'::jsonb),
    'company_access', coalesce((
      SELECT jsonb_agg(jsonb_build_object('user_id', m.user_id, 'name', coalesce(p.full_name, ''), 'email', u.email,
                                          'role', m.role, 'last_sign_in_at', u.last_sign_in_at)
                       ORDER BY (m.role = 'owner') DESC, m.created_at)
        FROM public.organization_members m
        LEFT JOIN auth.users u ON u.id = m.user_id
        LEFT JOIN public.profiles p ON p.id = m.user_id
       WHERE m.org_id = h.org_id AND NOT coalesce(m.is_deleted, false) AND m.role IN ('owner', 'manager')), '[]'::jsonb),
    'recent_bookings', coalesce((
      SELECT jsonb_agg(jsonb_build_object('ref', b.booking_ref, 'status', b.status, 'check_in', b.check_in_date,
                                          'check_out', b.check_out_date, 'amount', b.total_amount, 'paid', b.is_paid,
                                          'source', b.source, 'created_at', b.created_at) ORDER BY b.created_at DESC)
        FROM (SELECT * FROM public.bookings x WHERE x.hotel_id = h.id ORDER BY x.created_at DESC LIMIT 10) b), '[]'::jsonb),
    'recent_orders', coalesce((
      SELECT jsonb_agg(jsonb_build_object('number', q.order_number, 'status', q.status, 'type', q.type,
                                          'payment_status', q.payment_status, 'room', q.room_number,
                                          'items', CASE WHEN jsonb_typeof(q.items) = 'array' THEN jsonb_array_length(q.items) ELSE 0 END,
                                          'created_at', q.created_at) ORDER BY q.created_at DESC)
        FROM (SELECT * FROM public.restaurant_orders x WHERE x.hotel_id = h.id ORDER BY x.created_at DESC LIMIT 10) q), '[]'::jsonb),
    'activity_counts', coalesce((
      SELECT jsonb_agg(jsonb_build_object('action', x.action, 'n', x.n) ORDER BY x.n DESC)
        FROM (SELECT a.action, count(*) AS n FROM public.user_activity a
               WHERE a.property_id = h.id AND a.created_at > now() - interval '30 days' AND a.action NOT LIKE 'auth.%'
               GROUP BY a.action ORDER BY count(*) DESC LIMIT 12) x), '[]'::jsonb),
    'activity_total', (SELECT count(*) FROM public.user_activity a WHERE a.property_id = h.id),
    'first_activity_at', (SELECT min(a.created_at) FROM public.user_activity a WHERE a.property_id = h.id),
    'last_activity_at',  (SELECT max(a.created_at) FROM public.user_activity a WHERE a.property_id = h.id AND a.action NOT LIKE 'auth.%')
  ) INTO r
  FROM public.hotels h
  LEFT JOIN public.organizations o ON o.id = h.org_id
  WHERE h.id = p_property_id;

  IF r IS NULL THEN
    RAISE EXCEPTION 'No such property' USING ERRCODE = 'P0002';
  END IF;
  RETURN r;
END;
$$;

-- ─── Activity, filtered every way ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.superadmin_activity(
  p_user_id uuid DEFAULT NULL,
  p_org_id uuid DEFAULT NULL,
  p_property_id uuid DEFAULT NULL,
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
#variable_conflict use_column
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
     AND (p_property_id IS NULL OR a.property_id = p_property_id)
     AND (p_action_prefix IS NULL OR p_action_prefix = '' OR a.action LIKE public.superadmin_like_escape(p_action_prefix) || '%' ESCAPE '\')
     AND (p_before IS NULL OR a.created_at < p_before)
   ORDER BY a.created_at DESC, a.id DESC
   LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION
  public.superadmin_effective_status(text, timestamptz),
  public.superadmin_platform_overview(),
  public.superadmin_list_companies(text, text, integer, integer),
  public.superadmin_company_detail(uuid),
  public.superadmin_list_properties(text, text, uuid, integer, integer),
  public.superadmin_property_detail(uuid),
  public.superadmin_activity(uuid, uuid, uuid, text, integer, timestamptz)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.superadmin_effective_status(text, timestamptz),
  public.superadmin_platform_overview(),
  public.superadmin_list_companies(text, text, integer, integer),
  public.superadmin_company_detail(uuid),
  public.superadmin_list_properties(text, text, uuid, integer, integer),
  public.superadmin_property_detail(uuid),
  public.superadmin_activity(uuid, uuid, uuid, text, integer, timestamptz)
TO authenticated;
