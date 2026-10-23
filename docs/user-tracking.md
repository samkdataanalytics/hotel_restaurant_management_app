# Registered users and their activity (superadmin)

**Superadmin → Users** lists everyone who has registered, with their details and
what they have done. Click a person for their full record; click **Companies →
a company → Activity** for what that company's people have done.

## Turn it on (one step)

Paste `supabase/migrations/20261023000002_superadmin_user_tracking.sql` into the
Supabase SQL editor for **hotrest_dev**, then paste `supabase/tests/user_tracking.sql`
and run it (it ends in an error on purpose, so nothing commits; the message is a
PASS/FAIL report). Until the first file is applied, the Users page opens and says
the functions are not installed.

Production gets it only when you decide.

## What you see

| Where | What |
|---|---|
| Users → People | Headline numbers (registered, new this week, active this week, never signed in, email not confirmed, actions in 24 h); search by name, email, username, phone or company; filters; companies and roles; joined and last sign-in; actions in 30 days; status pills; **Export CSV**. |
| A person | Account (registered, last sign-in, email confirmed, sign-in methods, open sessions, invites sent), companies with role/plan/status, properties, payments, what they did in the last 30 days, the full activity log, and open sessions with device and address. |
| Users → Activity feed | Everyone's actions, newest first, filterable by area. |
| Company → Activity | The same log, for one company. |

## What is recorded

Sign-ups and sign-ins; bookings (created, confirmed, cancelled, checked in/out,
paid); check-ins; restaurant orders (created, status, payment); expenses; rooms,
menu items and tables added or removed; staff, shifts, clock-ins, invites;
team membership and role changes; payments; plan and status changes on a company;
profile edits.

The person who did it is whoever's session made the change. Changes made by a
payment webhook are attributed to the payer; other system changes have no actor.

## What is not

- Page views, searches, anything that only reads data.
- Anything before the migration (except one "signed up" and one "last signed in"
  entry per existing user, marked *from existing records*).
- Guest personal data. Entries carry references and statuses (a booking reference,
  an order number, a status change, an amount), never a guest's name, contact
  details or documents. An invite is recorded by the address's domain only.

## Notes for the owner

- The log, the sign-in addresses and device details are personal data about your
  customers and staff. Only superadmins can read them (enforced in the database,
  not just the screen). Decide how long you keep them; there is no automatic
  deletion yet. `delete from user_activity where created_at < now() - interval '1 year'`
  in the SQL editor trims it.
- Logging cannot block the action it records: each trigger swallows its own errors.
  If logging fails, the booking or order still saves and no line is written.
- Staff who sign in by username have a synthetic `username@staff.internal` address.
  The screen shows their username instead.

## Checks

`tool/cms/run_sql_tests.sh` applies the migration to a throwaway local Postgres and
runs 40 checks (permissions, search and paging, triggers, attribution, the
"logging can't block a write" case). CI runs it on every push. 24 more tests cover
the screens and models (`test/users`).
