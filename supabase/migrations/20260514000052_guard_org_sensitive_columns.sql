-- ============================================================
-- Migration 052: M-3 — Prevent direct plan/status/limits updates
-- ============================================================
--
-- The organizations_update RLS policy allows any org member to UPDATE
-- any column, including plan, status, and custom limits. A malicious
-- org admin could self-upgrade their plan to 'enterprise' for free.
--
-- Fix: add a BEFORE UPDATE trigger that blocks changes to sensitive
-- columns unless the caller is service_role (webhooks/Edge Functions)
-- or a verified superadmin.
--
-- Sensitive columns: plan, status, billing_cycle, created_by,
--   custom_max_properties, custom_max_users, custom_max_rooms,
--   custom_max_tables, custom_price_monthly, custom_price_annually
-- ============================================================

CREATE OR REPLACE FUNCTION guard_org_sensitive_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- service_role, postgres, and supabase_admin bypass this guard
  -- (payhere-notify webhook, Edge Functions, and migrations run as these roles)
  IF current_user IN ('service_role', 'postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  -- Superadmins may change any column (used by the admin panel)
  IF is_superadmin() THEN
    RETURN NEW;
  END IF;

  -- Regular authenticated users: block changes to payment / admin columns
  IF NEW.plan                  IS DISTINCT FROM OLD.plan                  THEN
    RAISE EXCEPTION 'Not authorized to change organization plan.';
  END IF;
  IF NEW.status                IS DISTINCT FROM OLD.status                THEN
    RAISE EXCEPTION 'Not authorized to change organization status.';
  END IF;
  IF NEW.billing_cycle         IS DISTINCT FROM OLD.billing_cycle         THEN
    RAISE EXCEPTION 'Not authorized to change billing cycle directly.';
  END IF;
  IF NEW.created_by            IS DISTINCT FROM OLD.created_by            THEN
    RAISE EXCEPTION 'Not authorized to change organization creator.';
  END IF;
  IF NEW.custom_max_properties IS DISTINCT FROM OLD.custom_max_properties THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_max_users      IS DISTINCT FROM OLD.custom_max_users      THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_max_rooms      IS DISTINCT FROM OLD.custom_max_rooms      THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_max_tables     IS DISTINCT FROM OLD.custom_max_tables     THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_price_monthly  IS DISTINCT FROM OLD.custom_price_monthly  THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;
  IF NEW.custom_price_annually IS DISTINCT FROM OLD.custom_price_annually THEN
    RAISE EXCEPTION 'Not authorized to change organization custom limits.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_org_sensitive ON organizations;
CREATE TRIGGER trg_guard_org_sensitive
  BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION guard_org_sensitive_columns();
