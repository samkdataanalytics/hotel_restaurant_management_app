# Superadmin tracking: companies, properties and activity

Superadmin can follow everything that happens on the platform, from one place,
read-only. Companion to [user-tracking.md](user-tracking.md).

## Turn it on

Paste into the Supabase SQL editor of **hotrest_dev**, in this order:

1. `supabase/migrations/20261023000002_superadmin_user_tracking.sql` (users and the activity log)
2. `supabase/migrations/20261023000004_superadmin_companies_properties.sql` (this feature)

Then run `supabase/tests/company_property_tracking.sql`. It ends in an error on
purpose (nothing commits); the message is a PASS/FAIL report. Until the migration
is applied the new screens say "functions not installed" and name the file; the
rest of the dashboard keeps working.

## Where to look

| Screen | What it shows |
|---|---|
| Dashboard → Platform activity | Companies by status and plan, users (active this week), bookings and orders in 30 days, paid booking value, subscription payments, 14-day sign-ups/sign-ins/actions, busiest companies, trials ending soon |
| Companies | Every company (search; filters: active, trialing, trial ending, trial expired, suspended, dormant, no properties, deleted) with owner, plan, status, usage and last activity |
| Company → Overview | Plan usage against its limits (flags anything over), totals, people with roles and last sign-in, properties, subscription payments, what the company has been doing |
| Company → Properties / Members / Activity | Each row opens the property or the person |
| Properties | Every property across all companies, with its company, rooms, tables, staff, bookings, orders, paid value and last activity |
| Property dialog | Details, settings (tax, service charge), people (staff and company owners/managers), recent bookings and orders, expenses, activity |
| Users | See [user-tracking.md](user-tracking.md); company and property names link across |

Every name in an activity row (person, company, property) is a link, so you can
walk from an action to who did it, where, and for which company.

## What is recorded

Database triggers write one row per change to `user_activity`: bookings,
check-ins, orders, expenses, rooms, menu, tables, members, staff, invites, shifts,
time records, payments, companies, properties, property settings, plans, leads,
and profile changes, plus sign-up and sign-in. The row names the actor, company
and property. Failure to log never blocks the real change.

## Privacy

- **Guest names, emails, phones and ID numbers are never copied** into the
  activity log and are not shown in the property dialog (bookings appear by
  reference, dates, amount and status). The SQL test seeds a guest and checks the
  name appears nowhere.
- Staff accounts with synthetic addresses (`…@staff.internal`) are shown by
  username.
- Only a superadmin can call the functions (`superadmin_require()`); the
  functions are not granted to `anon`.
- There is no retention limit yet: `user_activity` grows until you add one.
