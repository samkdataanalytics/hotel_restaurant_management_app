-- Plan limits and the expired-trial pause, enforced where they cannot be bypassed.
--
-- Until now the four limits (properties, staff accounts, rooms, restaurant tables)
-- and the paused state of an expired trial were checked only by the web screens
-- (OrganizationService.canAdd*). Any signed-in member could go past their plan by
-- calling the API, and the staff-creation function had no check at all.
--
-- This adds a BEFORE INSERT trigger on hotels, rooms, restaurant_tables and
-- organization_members that applies the same rules the screens use:
--   * limit = the company's custom_max_* if set, else its plan's max_*; -1 = unlimited;
--     a plan row that cannot be found counts as 1 (what the screens assume);
--   * counted the same way: non-deleted hotels, non-deleted members, and rooms/tables
--     of the company's non-deleted hotels;
--   * a company whose trial has lapsed, or that is suspended, cannot add any of these;
--   * a superadmin is exempt.
-- Existing rows are never touched: a company already over its limit keeps its data and
-- simply cannot add more. A row that already exists (an upsert that updates it) is not
-- a new record and is not blocked, so editing a table at the limit still works.
--
-- Error: SQLSTATE PL402 with a readable message, which the API returns as a 400.

CREATE OR REPLACE FUNCTION public.org_plan_limit(p_org_id uuid, p_kind text)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
           CASE p_kind
             WHEN 'properties' THEN coalesce(o.custom_max_properties, pl.max_properties)
             WHEN 'staff'      THEN coalesce(o.custom_max_users,      pl.max_users)
             WHEN 'rooms'      THEN coalesce(o.custom_max_rooms,      pl.max_rooms)
             WHEN 'tables'     THEN coalesce(o.custom_max_tables,     pl.max_tables)
           END, 1)
    FROM public.organizations o
    LEFT JOIN public.plans pl ON pl.slug = o.plan
   WHERE o.id = p_org_id
$$;
REVOKE EXECUTE ON FUNCTION public.org_plan_limit(uuid, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_plan_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  kind  text := TG_ARGV[0];
  org   uuid;
  st    text;
  ends  timestamptz;
  lim   integer;
  used  bigint;
  label text;
BEGIN
  IF public.is_superadmin() THEN
    RETURN NEW;
  END IF;

  -- An upsert that lands on an existing row is an edit, not a new record.
  IF kind = 'staff' THEN
    IF EXISTS (SELECT 1 FROM public.organization_members m
                WHERE m.id = NEW.id OR (m.org_id = NEW.org_id AND m.user_id = NEW.user_id)) THEN
      RETURN NEW;
    END IF;
    org := NEW.org_id;
  ELSIF kind = 'properties' THEN
    IF EXISTS (SELECT 1 FROM public.hotels h WHERE h.id = NEW.id) THEN RETURN NEW; END IF;
    org := NEW.org_id;
  ELSIF kind = 'rooms' THEN
    IF EXISTS (SELECT 1 FROM public.rooms r WHERE r.id = NEW.id) THEN RETURN NEW; END IF;
    SELECT h.org_id INTO org FROM public.hotels h WHERE h.id = NEW.hotel_id;
  ELSE
    IF EXISTS (SELECT 1 FROM public.restaurant_tables t WHERE t.id = NEW.id) THEN RETURN NEW; END IF;
    SELECT h.org_id INTO org FROM public.hotels h WHERE h.id = NEW.hotel_id;
  END IF;

  IF org IS NULL THEN
    RETURN NEW;               -- not tied to a company; nothing to measure against
  END IF;

  -- One company adds one kind of record at a time, so two requests cannot both
  -- read "one slot left".
  PERFORM pg_advisory_xact_lock(hashtextextended(org::text || ':' || kind, 0));

  SELECT o.status, o.trial_ends_at INTO st, ends FROM public.organizations o WHERE o.id = org;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  label := CASE kind WHEN 'properties' THEN 'properties' WHEN 'staff' THEN 'staff accounts'
                     WHEN 'rooms' THEN 'rooms' ELSE 'restaurant tables' END;

  IF st = 'suspended' THEN
    RAISE EXCEPTION 'This account is suspended; new % cannot be added. Please contact support.', label
      USING ERRCODE = 'PL402';
  END IF;
  IF st = 'trial_expired' OR (st = 'trialing' AND ends IS NOT NULL AND ends <= now()) THEN
    RAISE EXCEPTION 'The free trial has ended; new % cannot be added until a plan is chosen.', label
      USING ERRCODE = 'PL402';
  END IF;

  lim := public.org_plan_limit(org, kind);
  IF lim = -1 THEN
    RETURN NEW;
  END IF;

  used := CASE kind
    WHEN 'properties' THEN (SELECT count(*) FROM public.hotels h
                             WHERE h.org_id = org AND NOT coalesce(h.is_deleted, false))
    WHEN 'staff'      THEN (SELECT count(*) FROM public.organization_members m
                             WHERE m.org_id = org AND NOT coalesce(m.is_deleted, false))
    WHEN 'rooms'      THEN (SELECT count(*) FROM public.rooms r JOIN public.hotels h ON h.id = r.hotel_id
                             WHERE h.org_id = org AND NOT coalesce(h.is_deleted, false))
    ELSE                   (SELECT count(*) FROM public.restaurant_tables t JOIN public.hotels h ON h.id = t.hotel_id
                             WHERE h.org_id = org AND NOT coalesce(h.is_deleted, false))
  END;

  IF used >= lim THEN
    RAISE EXCEPTION 'Plan limit reached: this plan allows % %. Upgrade the plan to add more.', lim, label
      USING ERRCODE = 'PL402';
  END IF;

  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.enforce_plan_limit() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE spec text[];
BEGIN
  FOREACH spec SLICE 1 IN ARRAY ARRAY[
    ['hotels',               'properties'],
    ['rooms',                'rooms'],
    ['restaurant_tables',    'tables'],
    ['organization_members', 'staff']
  ] LOOP
    CONTINUE WHEN to_regclass('public.' || spec[1]) IS NULL;
    EXECUTE format('DROP TRIGGER IF EXISTS enforce_plan_limit ON public.%I', spec[1]);
    EXECUTE format('CREATE TRIGGER enforce_plan_limit BEFORE INSERT ON public.%I
                    FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_limit(%L)', spec[1], spec[2]);
  END LOOP;
END $$;
