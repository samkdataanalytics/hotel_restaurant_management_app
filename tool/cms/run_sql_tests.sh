#!/usr/bin/env bash
# Applies the CMS and user-tracking migrations to a throwaway local Postgres (with
# stand-in Supabase schemas) and runs their regression tests.
#
#   PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres tool/cms/run_sql_tests.sh
#
# Never point this at a real project: it drops and recreates the database "cms_test".
set -euo pipefail
cd "$(dirname "$0")/../.."

PSQL=${PSQL:-psql}
db=cms_test

$PSQL -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $db" -c "create database $db"
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/tests/local/supabase_stubs.sql
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/migrations/20261023000001_site_cms.sql >/dev/null 2>&1
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/migrations/20261023000003_site_conflict_code.sql >/dev/null 2>&1

# Each test always ends in an error that carries the report; read it from stderr.
run_test() { # file, minimum number of PASS lines
  local out passes
  out=$($PSQL -d $db -f "$1" 2>&1 || true)
  echo "$out"
  if echo "$out" | grep -q " FAIL "; then
    echo "SQL tests: FAILURES in $1" >&2
    exit 1
  fi
  passes=$(echo "$out" | grep -c " PASS ")
  if [ "$passes" -lt "$2" ]; then
    echo "SQL tests: $1 reported only $passes checks; it did not run to the end" >&2
    exit 1
  fi
  echo "== $1: $passes checks passed"
}

run_test supabase/tests/site_cms.sql 30

# User tracking: its stand-in tables, its migration, then its tests.
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/tests/local/user_tracking_stubs.sql
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/migrations/20261023000002_superadmin_user_tracking.sql >/dev/null 2>&1
run_test supabase/tests/user_tracking.sql 25
run_test supabase/tests/local/user_tracking_triggers.sql 10

# Companies and properties: more stand-ins and a little data, the migration, the tests.
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/tests/local/company_property_stubs.sql
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/migrations/20261023000004_superadmin_companies_properties.sql >/dev/null 2>&1
run_test supabase/tests/company_property_tracking.sql 25

# A database without the optional staff_invites table: the detail screens must still work.
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/migrations/20261103000001_superadmin_optional_tables.sql >/dev/null 2>&1
run_test supabase/tests/superadmin_optional_tables.sql 6

# Plan limits, the expired-trial pause and suspension, enforced by triggers.
$PSQL -v ON_ERROR_STOP=1 -q -d $db -f supabase/migrations/20261103000002_plan_limits_server_side.sql >/dev/null 2>&1
run_test supabase/tests/local/plan_limits.sql 18
echo "All SQL tests passed"
