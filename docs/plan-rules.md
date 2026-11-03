# Plans, limits and what a company can do

## The four limits

Each plan (Superadmin → Plans) sets how many **properties**, **staff accounts**,
**rooms** and **restaurant tables** a company may have. `-1` means unlimited.
A company can have its own numbers (`custom_max_*`, set from Superadmin or an
enterprise invitation); those win over the plan. If a company's plan cannot be
found, the limit is 1, as the screens have always assumed.

How things are counted: non-deleted properties; non-deleted members of the
company; rooms and tables belonging to the company's non-deleted properties.

## Where the rules are enforced

| Rule | Web and mobile screens | Database |
|---|---|---|
| Over the plan or custom limit | "Add" is refused with an upgrade message | **Yes**, trigger `enforce_plan_limit` on `hotels`, `rooms`, `restaurant_tables`, `organization_members` |
| Trial ended (read-only) | Add is refused; the mobile app is blocked | **Yes**, same four additions |
| Suspended | Members see a "suspended" notice and can only sign out; mobile shows it as a blocker | **Yes**, same four additions are refused |

The database check (`supabase/migrations/20261103000002_plan_limits_server_side.sql`)
means the rules cannot be skipped by calling the API directly, and it also covers
the staff-creation function, which had no check before. It returns SQLSTATE `PL402`
with a readable message.

What it deliberately does **not** do:

- It never deletes or changes existing data. A company already over its limit keeps
  everything and can edit it; it just cannot add more.
- Editing an existing room, table or member (including an upsert that updates it) is
  not an addition and is not blocked.
- A superadmin is exempt.
- It does not block bookings, orders or other records for an expired or suspended
  company. If you want that, it is a separate decision (it stops staff mid-shift).
- Suspension is a lock-out in the app, not an Auth ban: someone with a valid
  token can still read their own company's data through the API. Banning the
  users in Auth would close that, at the cost of needing to un-ban them later.

## Checking

`tool/cms/run_sql_tests.sh` applies the migration to a throwaway Postgres and runs
`supabase/tests/local/plan_limits.sql` (20 checks: limits, custom override,
unlimited, bulk inserts, over-limit companies, upserts, expired and suspended,
superadmin, unknown plan). `test/plan_rules_test.dart` covers the app side.
