-- The user and company detail screens failed with
--   relation "public.staff_invites" does not exist (42P01)
-- on a database that never created that table (it comes from the optional
-- 20220101000004_staff_invites.sql; 20220101000034 already notes some databases
-- lack it). The activity triggers already skip missing tables; these two read
-- functions did not. They now count invites through a helper that answers 0 when
-- the table is absent. Nothing else changes: the two bodies below are the previous
-- definitions with only the invite count replaced. CREATE OR REPLACE keeps grants.

CREATE OR REPLACE FUNCTION public.superadmin_invite_count(p_invited_by uuid, p_org_id uuid)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE n bigint;
BEGIN
  IF to_regclass('public.staff_invites') IS NULL THEN
    RETURN 0;
  END IF;
  IF p_invited_by IS NOT NULL THEN
    EXECUTE 'SELECT count(*) FROM public.staff_invites WHERE invited_by = $1' INTO n USING p_invited_by;
  ELSE
    EXECUTE 'SELECT count(*) FROM public.staff_invites WHERE org_id = $1 AND status = ''pending''' INTO n USING p_org_id;
  END IF;
  RETURN coalesce(n, 0);
END;
$$;
-- Called only from the two functions below (which run as their owner).
REVOKE EXECUTE ON FUNCTION public.superadmin_invite_count(uuid, uuid) FROM PUBLIC, anon, authenticated;

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
    'invites_sent', public.superadmin_invite_count(u.id, NULL),
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
      'pending_invites', public.superadmin_invite_count(NULL, o.id)
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
