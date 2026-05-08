-- Upserts the calling user's own profile row.
-- SECURITY DEFINER bypasses RLS so it works regardless of insert/update policy
-- evaluation order during ON CONFLICT DO UPDATE.

CREATE OR REPLACE FUNCTION upsert_my_profile(
  p_full_name TEXT,
  p_job_title TEXT DEFAULT '',
  p_phone     TEXT DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (id, full_name, job_title, phone)
  VALUES (auth.uid(), p_full_name, p_job_title, p_phone)
  ON CONFLICT (id) DO UPDATE SET
    full_name  = EXCLUDED.full_name,
    job_title  = EXCLUDED.job_title,
    phone      = EXCLUDED.phone,
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION upsert_my_profile IS
  'Upserts the calling user''s profile. SECURITY DEFINER avoids RLS conflicts on upsert.';

REVOKE ALL ON FUNCTION upsert_my_profile(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION upsert_my_profile(TEXT, TEXT, TEXT) TO authenticated;
