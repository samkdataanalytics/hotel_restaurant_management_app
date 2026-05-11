# Supabase Migrations

## How to run

1. Open Supabase Dashboard → **SQL editor**
2. Paste the file contents and click **Run**

Run in order: `001_`, `002_`, ...

---

## 001_multi_tenancy.sql

Adds full multi-tenancy to the database.

### What it creates

| Object | Purpose |
|---|---|
| `hotels` | One row per tenant (hotel) |
| `hotel_settings` | Branding per hotel (name, address, logo, tax rate) |
| `hotel_users` | Maps `auth.users` → hotel + staff role |
| `staff_role` enum | `owner / manager / front_desk / kitchen / restaurant` |
| `current_hotel_id()` | Helper function used in all RLS policies |

### What it modifies

Adds `hotel_id UUID NOT NULL REFERENCES hotels(id)` to:

- `rooms`
- `guests`
- `bookings`
- `check_ins`
- `expenses`
- `menu_items`
- `ingredients`
- `ingredient_prices`
- `menu_item_cost_records`
- `restaurant_tables`
- `restaurant_orders`
- `inventory`

### RLS policy pattern

Every table uses:
```sql
USING (hotel_id = current_hotel_id())
```

`current_hotel_id()` looks up the logged-in user's hotel from `hotel_users`.
No cross-tenant data leakage is possible at the DB level.

### After running — Flutter app changes needed

1. **Session provider**: after login, query `hotel_users` to get `hotel_id` and store it in a provider
2. **All INSERT calls**: include `hotel_id` from the session provider
3. **Settings screen**: replace hardcoded name/address/tax with a query to `hotel_settings`
4. **Signup flow**: create a `hotels` row + `hotel_settings` row + first `hotel_users` row (owner)

### Existing data

All current rows are assigned to a hotel named **"Hotel One"** (slug: `hotel-one`).
Rename it via:
```sql
UPDATE hotel_settings SET display_name = 'Your Hotel Name', address = '...' WHERE hotel_id = (SELECT id FROM hotels WHERE slug = 'hotel-one');
UPDATE hotels SET name = 'Your Hotel Name' WHERE slug = 'hotel-one';
```

---

## Prerequisite: parent_order_id column

If you haven't run this yet, run it **before** `001_multi_tenancy.sql`:

```sql
ALTER TABLE restaurant_orders
  ADD COLUMN IF NOT EXISTS parent_order_id UUID
  REFERENCES restaurant_orders(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS restaurant_orders_parent_idx
  ON restaurant_orders(parent_order_id);
```

---

## Migration 002 — SaaS Schema

Run after migration 001. Adds:
- `profiles` table (user profile + is_superadmin flag, auto-created on signup)
- `organizations` table (company/tenant with plan tiers)
- `organization_members` table (user → org role)
- `property_staff` table (user → property access for new signups)
- Extends `hotels` with: org_id, type, city, country, phone, email, timezone, logo_url, status, address

### After running migration 002

1. Promote your first superadmin:
   ```sql
   SELECT promote_to_superadmin('your@email.com');
   ```

2. Log in as superadmin → you'll be routed to /superadmin

3. For new users: signup → onboarding (company setup) → property setup → main app

### Plan limits
- free: 1 property, 5 staff
- pro: 5 properties, 20 staff
- enterprise: unlimited
