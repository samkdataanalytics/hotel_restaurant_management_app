#!/usr/bin/env bash
# Applies the CMS migration to a throwaway local Postgres (with stand-in Supabase
# schemas) and runs supabase/tests/site_cms.sql against it.
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

# The test always ends in an error that carries the report; read it from stderr.
out=$($PSQL -d $db -f supabase/tests/site_cms.sql 2>&1 || true)
echo "$out"

if echo "$out" | grep -q " FAIL "; then
  echo "SQL tests: FAILURES" >&2
  exit 1
fi
passes=$(echo "$out" | grep -c " PASS ")
if [ "$passes" -lt 30 ]; then
  echo "SQL tests: only $passes checks reported; the test did not run to the end" >&2
  exit 1
fi
echo "SQL tests: $passes checks passed"
