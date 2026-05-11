# HotRest — QA Test Document

**Product:** HotRest — Hotel & Restaurant Management SaaS  
**Platform:** Web (Flutter Web), Mobile (Flutter Android/iOS)  
**Prepared for:** QA Team  

---

## How to Use This Document

Each feature section contains:
- **Description** — what the feature does
- **Pre-conditions** — what must be true before testing
- **Test Scenarios** — steps to follow
- **Expected Results** — what correct behaviour looks like
- **Negative / Edge Cases** — inputs or flows that should fail gracefully

Test accounts needed:
| Role | Description |
|---|---|
| Owner | Full access, can manage billing and properties |
| Manager | All hotel/restaurant access, no billing |
| Staff | Limited access based on permissions assigned |
| Superadmin | Platform-level admin, separate login |
| Guest | No login — accesses QR portal via URL |

---

## MODULE 1 — AUTHENTICATION & ONBOARDING

### 1.1 Sign Up
**Description:** New users register with email and password to create a HotRest account.

**Test Scenarios & Expected Results:**

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to `/signup`. Enter valid email, password (8+ chars). Click Sign Up. | Account created. Redirected to onboarding profile page. |
| 2 | Sign up with an email already registered. | Error: "Email already in use" (or similar). Form does not submit. |
| 3 | Sign up with a password shorter than 8 characters. | Validation error shown inline. Form does not submit. |
| 4 | Sign up with invalid email format (e.g. `abc@`). | Validation error shown. Form does not submit. |
| 5 | Leave email or password blank and click Sign Up. | Required field errors shown. Form does not submit. |
| 6 | Sign up with a `?plan=starter` query param in the URL. | After onboarding, user is directed to upgrade screen pre-selecting Starter plan. |

---

### 1.2 Login
**Description:** Registered users log in with email and password.

**Test Scenarios & Expected Results:**

| # | Steps | Expected Result |
|---|---|---|
| 1 | Enter valid email and password. Click Login. | Redirected to `/app/dashboard`. |
| 2 | Enter valid email, wrong password. | Error message shown. User stays on login page. |
| 3 | Enter unregistered email. | Error message shown. |
| 4 | Leave fields blank. Click Login. | Validation errors shown. |
| 5 | Login as a staff account (username-based). | Redirected to dashboard. Navigation shows only permitted sections. |
| 6 | Login as superadmin. | Redirected to `/superadmin` dashboard, not the main app. |
| 7 | After logout, press browser Back button. | User cannot navigate back to authenticated pages. Redirected to landing/login. |

---

### 1.3 Onboarding — Profile Setup
**Description:** After signup, new users set up their organisation (company name, contact info).

**Pre-conditions:** Newly registered account (no organisation yet).

| # | Steps | Expected Result |
|---|---|---|
| 1 | Complete profile form with company name and contact info. Click Continue. | Organisation created. Redirected to Property Setup. |
| 2 | Skip optional fields. Click Continue. | Proceeds with only required fields. |
| 3 | Leave company name (required field) blank. | Validation error shown. Cannot proceed. |

---

### 1.4 Onboarding — Property Setup
**Description:** Users create their first property (hotel name, logo, type).

| # | Steps | Expected Result |
|---|---|---|
| 1 | Fill property name, select type. Click Create. | Property created. Redirected to `/app/dashboard`. |
| 2 | Upload a logo image (PNG/JPG under 2MB). | Logo shown in sidebar and property header. |
| 3 | Try to upload a non-image file as logo. | Error shown. Upload rejected. |
| 4 | Leave property name blank. | Validation error. Cannot proceed. |

---

### 1.5 Staff Account Invite & Accept
**Description:** Managers invite staff via username + password. Staff receive an invite link.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Manager creates a staff account in Team Members screen. Copy the invite link. | Staff account created with pending status. |
| 2 | Open invite link (`/accept-invite?token=...`) in browser. | Invite acceptance screen shown with property/role details. |
| 3 | Accept the invite. | Staff account activated. Staff can now log in. |
| 4 | Use an expired or invalid invite token. | Error shown: "Invalid or expired invite". |
| 5 | Try to accept an already-accepted invite. | Error shown: "Invite already used". |

---

## MODULE 2 — NAVIGATION & APP SHELL

### 2.1 Sidebar Navigation
**Description:** Left sidebar provides access to all sections. Collapses on smaller screens.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Click each menu item (Dashboard, Check-Ins, Rooms, etc.). | Navigates to the correct screen. Active item is highlighted. |
| 2 | Resize browser to mobile width. | Sidebar collapses. Hamburger menu appears. |
| 3 | Click hamburger menu on mobile. | Sidebar drawer slides in. |
| 4 | Log in as Staff with only Restaurant permissions. | Hotel section items (Rooms, Check-Ins, etc.) are hidden from sidebar. |
| 5 | Click "Add Property" in sidebar. | Opens property creation flow (redirects to `/property-setup`). |

### 2.2 Property Switcher
**Description:** Users with multiple properties can switch between them via a dropdown.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Click the property selector button in the sidebar. | Dropdown shows all available properties. |
| 2 | Select a different property. | All data refreshes to show the selected property's data. |
| 3 | Click "Manage Properties". | Dialog opens showing all properties with edit options. |

### 2.3 Notification Bell
**Description:** Bell icon shows unread in-app notifications.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Click the notification bell in the top bar. | Notification panel opens showing recent notifications. |
| 2 | Click an unread notification. | Notification marked as read. Badge count decreases. |
| 3 | Click "Mark all as read". | All notifications marked read. Badge disappears. |
| 4 | When a housekeeping notification is due (guest staying 3+ nights). | Notification automatically appears: "Housekeeping Required — Room X". |

### 2.4 User Menu (Top Right)
**Description:** Account dropdown for profile, settings, and logout.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Click user avatar/email in top right. | Dropdown shows email, plan badge, Account Settings, Logout. |
| 2 | Click "Account Settings". | Navigates to `/app/account`. |
| 3 | Click "Logout". | Session ended. Redirected to landing page. Cannot navigate back. |

---

## MODULE 3 — HOTEL MANAGEMENT

### 3.1 Dashboard
**Description:** Displays key performance metrics for hotel and restaurant operations.

**Pre-conditions:** At least one booking or check-in must exist to see non-zero metrics.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Dashboard. | Page loads showing KPI cards: Check-ins today, Occupancy %, Revenue today, Orders today. |
| 2 | Verify currency symbol matches the hotel's configured currency. | Amounts shown with correct currency symbol (e.g. LKR). |
| 3 | With no bookings, open dashboard. | KPIs show zero values. No crash or error. |
| 4 | Enterprise plan account with outstanding payment. | Subscription payment banner is visible with amount due. |
| 5 | Free/Starter/Pro plan account. | No subscription banner shown. |

---

### 3.2 Rooms
**Description:** Manage the hotel's room inventory — add, edit, delete, and track status.

**Pre-conditions:** Logged in as Owner or Manager.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Rooms. | Grid of all rooms displayed with status indicators. |
| 2 | Click "Add Room". Fill in room number, type, price, floor, capacity. Click Save. | New room appears in the grid. |
| 3 | Click on an existing room card. Click "Edit". Change nightly rate. Save. | Room shows updated rate. |
| 4 | Change a room's status to "Maintenance". Set start/end date. | Room shown with maintenance indicator. Appears blocked in Reservations calendar. |
| 5 | Change maintenance end date to a past date. | Validation error: end date must be in the future. |
| 6 | Filter by "Available". | Only available rooms shown. |
| 7 | Filter by "Occupied". | Only occupied rooms shown. |
| 8 | Filter by "Maintenance". | Only rooms in maintenance shown. |
| 9 | Delete an unoccupied room. Confirm deletion. | Room removed from grid. |
| 10 | Attempt to add rooms beyond the plan limit (e.g. 31 rooms on Starter = 30 max). | Error/dialog shown: "Upgrade your plan to add more rooms". |
| 11 | Click "Generate QR" on a room. | QR code generated for the room service URL for that room. |

**Negative Cases:**
- Add a room with a negative price → Validation error.
- Add a room with no room number → Validation error.
- Add a room with the same number as an existing room → Error: "Room number already exists".

---

### 3.3 Reservations (Booking Calendar)
**Description:** 14-day Gantt calendar showing all bookings per room.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Reservations. | 14-day calendar loads with rooms on Y-axis and dates on X-axis. |
| 2 | Click the forward arrow to advance the calendar. | Calendar shifts forward by one day. |
| 3 | Click "Add Reservation". Fill guest name, email, room, check-in/check-out dates. Save. | Booking block appears on the calendar for the correct room and dates. |
| 4 | Click an existing booking block. | Detail panel slides in showing full reservation info. |
| 5 | Click "Edit" on a booking. Change the check-out date. Save. | Booking block resizes on the calendar. |
| 6 | Click "Delete" on a booking. Confirm. | Booking removed from calendar. |
| 7 | Filter by source "Booking.com". | Only bookings from Booking.com shown. |
| 8 | Click "Print Folio" on a booking. | Generates and downloads a PDF/printable invoice including room charges and linked expenses. |
| 9 | Try to create a booking for a room already booked on those dates. | Error: "Room not available for selected dates". |
| 10 | Set check-out date before check-in date. | Validation error: "Check-out must be after check-in". |
| 11 | Rooms in maintenance show as blocked. | Maintenance blocks appear in a different colour/pattern. Cannot book over them. |
| 12 | View "Daily Revenue" for a day. | Shows expected revenue for that day from confirmed bookings. |

---

### 3.4 Check-Ins
**Description:** Manage active guest check-ins. Perform check-in and check-out operations.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Check-Ins. | List of current check-ins displayed with guest name, room, dates. |
| 2 | Click "Check In" on a pending booking. | Status changes to Checked In. Room status becomes Occupied. |
| 3 | Click "Check Out" on an active check-in. | Status changes to Checked Out. Room status returns to Available. |
| 4 | Search for a guest by name. | Filtered list showing matching guests. |
| 5 | Search by email. | Filtered list showing matching guests. |
| 6 | Click on a check-in row to expand. | Full guest details shown (ID type, ID number, nationality, special requests). |
| 7 | Click "Print Folio" for a checked-in guest. | Invoice generated with all room charges, expenses, and restaurant orders. |
| 8 | Generate QR code for a checked-in guest. | QR code displayed for room service access. |
| 9 | Switch to "Bookings" tab. | All bookings (not just active check-ins) shown. |
| 10 | Filter by room status. | List filtered accordingly. |

---

### 3.5 Financials
**Description:** Revenue and cost analytics with customisable date ranges.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Financials. | Default date range (current month) loads with KPI cards. |
| 2 | Verify KPI cards: Gross Revenue, Total Costs, Net Profit, Future Revenue. | All four cards show correct values. Net Profit = Gross Revenue − Total Costs. |
| 3 | Change date range to last 7 days. | All metrics recalculate for the new date range. |
| 4 | Change date range to a custom range (e.g. Jan 1 – Jan 31). | Metrics update for January only. |
| 5 | Set end date before start date. | Validation error or end date auto-corrected. |
| 6 | Filter by booking source "Airbnb". | Revenue metrics show only Airbnb bookings. |
| 7 | View daily breakdown table. | Table shows each day with: Date, Revenue, Bookings, Expenses, Net. |
| 8 | Scroll through daily table. | All rows visible, no layout issues. |
| 9 | Currency symbol matches hotel configuration. | All monetary values use the correct symbol. |
| 10 | With zero bookings in range. | All KPIs show LKR 0.00. No crash. |

---

### 3.6 Expenses Management
**Description:** Log and track operational expenses for the property.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Expenses. | List of existing expenses shown. |
| 2 | Click "Add Expense". Fill description, amount, category, date. Click Save. | Expense appears in list. Reflected in Financials as a cost. |
| 3 | Add a room-linked expense. Select a room from the dropdown. | Expense appears in that room's guest folio. |
| 4 | Mark an expense as billable. | Expense flagged as billable. Appears on guest invoice. |
| 5 | Mark a billable expense as paid. | Expense shows "Paid" status. |
| 6 | Edit an existing expense. Change the amount. | List shows updated amount. |
| 7 | Delete an expense. Confirm. | Expense removed from list and from Financials. |
| 8 | Add expense with amount = 0. | Validation error: amount must be greater than zero. |
| 9 | Add expense with no description. | Validation error: description required. |
| 10 | Filter/view expenses by category (e.g. Maintenance). | Only maintenance expenses shown. |

---

## MODULE 4 — RESTAURANT MANAGEMENT

### 4.1 POS (Point of Sale)
**Description:** Take orders from tables or for takeaway/delivery. Add items, apply discounts, process payments.

**Pre-conditions:** Menu items and tables must be configured.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to POS. | Menu categories and items displayed. Table list on the side. |
| 2 | Select a table. Click menu items to add to order. | Order builds in the right panel with itemised totals. |
| 3 | Increase item quantity using + button. | Quantity updates. Line total recalculates. |
| 4 | Remove an item from the order. | Item removed. Total recalculates. |
| 5 | Apply a discount (percentage or fixed). | Discount deducted from total. Discount amount shown. |
| 6 | Select "Dine-In" order type. | Order tagged as dine-in. |
| 7 | Select "Takeaway" order type. | Order tagged as takeaway. No table required. |
| 8 | Select "Delivery" order type. | Order tagged as delivery. Delivery platform selector shown. |
| 9 | Place the order. | Order sent to Kitchen. Status = Pending. |
| 10 | Apply a service charge. | Service charge calculated and shown in total. |
| 11 | Split payment between cash and card. | Payment split dialog shown. Amounts must total the bill. |
| 12 | Charge to a guest room. | Bill posted to the checked-in guest's folio. |
| 13 | Items with low/zero inventory are marked unavailable. | Out-of-stock items shown as greyed out. Cannot be added to order. |
| 14 | Add an item with a modifier (e.g. "Extra cheese"). | Modifier selected. Line item shows modifier. Price adjusted if applicable. |
| 15 | Print receipt after payment. | Receipt printed/downloaded with itemised bill, taxes, and service charge. |

**Negative Cases:**
- Place order with zero items → Place Order button disabled or error shown.
- Apply discount greater than total → Validation error or discount capped at 100%.
- Split payment totals that don't match order total → Cannot confirm payment.

---

### 4.2 Tables / Floor Plan
**Description:** Visual floor plan showing table statuses. Manage table sessions and quick-access to orders.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Tables. | Floor plan renders with all tables. Colour-coded by status (empty/occupied/reserved). |
| 2 | Click an empty table. | Opens POS for that table. |
| 3 | Click an occupied table. | Shows active orders for that table. |
| 4 | Table with active order shows order count badge. | Badge displays number of active orders. |
| 5 | Mark a table as Reserved. | Table colour changes to "reserved" state. |
| 6 | Close a table (checkout all orders). | Table returns to "empty" state. |
| 7 | Tables update in real time when orders are placed from POS. | No page refresh needed — status updates automatically. |

---

### 4.3 Kitchen Display System (KDS)
**Description:** Real-time order board for the kitchen. Orders move through workflow columns.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Kitchen. | Kanban board with columns: Pending, Preparing, Ready, Payment Due. |
| 2 | New order placed from POS. | Order card appears in Pending column within seconds (real-time). |
| 3 | Drag/click order to "Preparing". | Order moves to Preparing column. Status updated. |
| 4 | Move order to "Ready to Serve". | Order moves to Ready column. Waiter is notified. |
| 5 | Move order to "Payment Due". | Order moves to Payment Due. Table can be charged. |
| 6 | Order under 5 minutes old. | Order card header is green. |
| 7 | Order 5–15 minutes old. | Order card header is yellow/amber. |
| 8 | Order over 15 minutes old. | Order card header is red (overdue). |
| 9 | Toggle sound notification on. Place a new order from POS. | Audio beep plays in the browser when new order arrives. |
| 10 | Toggle sound off. Place a new order. | No audio plays. |
| 11 | View order details. | Shows all items, quantities, special requests, table number. |
| 12 | Apply discount from KDS. | Discount reflected in order total. |

---

### 4.4 Restaurant Management — Menu
**Description:** Create and manage menu items with categories, prices, images, and availability.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Restaurant → Menu tab. | All menu items listed with name, price, category, availability. |
| 2 | Click "Add Item". Fill name, price, category, description. Save. | Item appears in menu list and in POS. |
| 3 | Upload an image for a menu item. | Image shown on item card and in POS. |
| 4 | Toggle an item's availability to Off. | Item shown as unavailable. Greyed out in POS. |
| 5 | Edit a menu item's price. | Updated price shown in POS and on guest menu. |
| 6 | Delete a menu item. Confirm. | Item removed from menu and POS. |
| 7 | Add item with price = 0. | Validation error: price must be greater than zero. |
| 8 | Add item with blank name. | Validation error. |

---

### 4.5 Restaurant Management — Ingredients & Inventory
**Description:** Track ingredient stock levels with reorder alerts. Link ingredients to menu items for COGS calculation.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Restaurant → Ingredients tab. | List of all ingredients with current stock level and unit. |
| 2 | Add a new ingredient with name, unit, cost per unit, minimum stock level. | Ingredient appears in list. |
| 3 | Adjust stock level (add). | Stock level increases. |
| 4 | Adjust stock level (remove/use). | Stock level decreases. Cannot go below zero. |
| 5 | Stock falls below minimum level. | Ingredient highlighted with low-stock warning. |
| 6 | Link an ingredient to a menu item. | COGS for that item is calculated and shown. |
| 7 | When an order is served, ingredient stock auto-deducts. | Stock decreases by amount used in the recipe. |
| 8 | When an order is refunded, ingredient stock auto-restores. | Stock increases back. |

---

### 4.6 Restaurant Management — Tables Configuration
**Description:** Add and configure restaurant tables with number, capacity, and QR code generation.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Restaurant → Tables tab. | All configured tables listed. |
| 2 | Add a new table with number and capacity. | Table appears in list, floor plan, and POS. |
| 3 | Edit a table's capacity. | Updated capacity shown. |
| 4 | Generate QR code for a table. | QR code generated linking to the guest menu URL for that table. |
| 5 | Delete a table. Confirm. | Table removed from all views. |
| 6 | Add table beyond plan limit (e.g. 16th table on Starter = 15 max). | Upgrade prompt shown. |

---

### 4.7 Restaurant Management — Tax & Charges
**Description:** Configure tax rate, service charge rate, and applicable order types.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Restaurant → Tax & Charges tab. | Current tax % and service charge % shown. |
| 2 | Update tax rate to 10%. Save. | New orders in POS show 10% tax applied. |
| 3 | Update service charge to 5%. Save. | New orders in POS show 5% service charge. |
| 4 | Set service charge to apply on Dine-In only. | Takeaway orders in POS do not show service charge. |
| 5 | Enter a negative percentage. | Validation error. |
| 6 | Enter a percentage > 100. | Validation error. |

---

### 4.8 Orders
**Description:** View and manage all restaurant orders with filtering, search, and refund capability.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Orders. | Full order list shown with date, status, items, total. |
| 2 | Filter by "Today". | Only today's orders shown. |
| 3 | Filter by "This Week". | Only this week's orders shown. |
| 4 | Filter by status "Served". | Only served (completed) orders shown. |
| 5 | Search by order number. | Matching order highlighted/shown. |
| 6 | Expand an order. | Shows all items, quantities, prices, table, and status. |
| 7 | Initiate a full refund on a served order. | Refund recorded. Order status shows "Refunded". Inventory restored. |
| 8 | Initiate a partial refund (select 1 of 2 items). | Only that item refunded. Order shows partial refund. Inventory partially restored. |
| 9 | View child orders (add-on orders linked to a parent). | Child orders shown nested under parent. |
| 10 | Try to refund a cancelled order. | Refund option not available for cancelled orders. |

---

### 4.9 Restaurant Analytics
**Description:** Performance metrics and trends for the restaurant business.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Analytics. | Overview tab shows KPI cards and charts. |
| 2 | Verify KPI cards: Total Revenue, Order Count, AOV, Cancellation Rate, Covers, Refunds. | All six cards show values. AOV = Revenue ÷ Order Count. |
| 3 | Select "Today" time range. | Charts and KPIs update to show today's data. |
| 4 | Select "Last 7 Days". | Data shown for past 7 days with daily bar chart. |
| 5 | Select "Last 30 Days". | Data shown for past 30 days. |
| 6 | Select "Last 90 Days". | Data shown for past 90 days. |
| 7 | Select custom date range. | Data shown for specified range. |
| 8 | View order type distribution (pie chart). | Shows % split: Dine-In / Takeaway / Delivery. Totals 100%. |
| 9 | View peak hours chart. | Hour with most orders/revenue highlighted. |
| 10 | View top selling items. | Ranked list of most-ordered items with count and revenue. |
| 11 | Switch to "Service Charge" tab. | Service charge breakdown shown by day/week/month. |
| 12 | With no orders in selected range. | KPIs show zero. Charts show empty state. No crash. |

---

### 4.10 Cancellations & Refunds
**Description:** Track all cancelled orders and refunded items.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Cancellations. | Cancelled Orders tab shown with summary KPI row. |
| 2 | View KPI row. | Shows: Total Cancelled, Total Value, Inventory Restored count, Total Refunded. |
| 3 | Each cancelled order row shows: order number, date, value, item count, inventory status. | All columns populated correctly. |
| 4 | Switch to "Refunded Items" tab. | Lists individual refunded items with qty, amount, refund type. |
| 5 | Verify refund amounts are correct. | Refund amount = unit price × refunded quantity. |
| 6 | Room charge reversal indicator. | Correctly shows Yes/No for items that were billed to a room. |

---

## MODULE 5 — TEAM MANAGEMENT

### 5.1 Team Members
**Description:** Create and manage staff accounts with role-based permissions.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Team Members. | List of all staff with name, username, role badge, properties. |
| 2 | Click "Add Staff Member". Fill username, password, first name, last name, phone. | New staff account created. Invite link generated. |
| 3 | Try to create staff with a duplicate username. | Error: "Username already taken". |
| 4 | Try to create staff with a password shorter than the minimum. | Validation error shown. |
| 5 | Click "Edit Permissions" on a staff member. | Permission matrix shown for each section (None / View / Edit). |
| 6 | Set Hotel section to "None". | Staff cannot see Hotel menu items after login. |
| 7 | Set Restaurant section to "View". | Staff can see restaurant screens but cannot make changes. |
| 8 | Set Financials to "Edit". | Staff can view and edit financial data. |
| 9 | Click "Assign to Property". | Staff assigned to the selected property. |
| 10 | Click "Remove from Property". | Staff loses access to that property. |
| 11 | Click "Reset Password". | New temporary password generated. Staff must change on next login (or dialog shown with new password). |
| 12 | Delete a staff member. Confirm. | Staff account deactivated/removed. They can no longer log in. |
| 13 | Attempt to add staff beyond plan limit. | Upgrade prompt shown. |

---

### 5.2 Staff Schedule
**Description:** Schedule shifts and track clock-in/clock-out times for payroll.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Staff Schedule. | Week view shown with current week's shifts. |
| 2 | Click forward arrow. | Advances to next week. |
| 3 | Click backward arrow. | Goes to previous week. |
| 4 | Click "Add Shift". Select staff, date, start time, end time, role. Save. | Shift appears on the schedule calendar. |
| 5 | Edit a shift's end time. | Updated time shown on calendar. |
| 6 | Delete a shift. Confirm. | Shift removed from calendar. |
| 7 | Try to add a shift with end time before start time. | Validation error. |
| 8 | Switch to "Time Tracking" tab. | Shows clock-in/out records. |
| 9 | Clock in a staff member. | Clock-in time recorded. Running timer shows elapsed time. |
| 10 | Clock out a staff member. | Clock-out time recorded. Duration calculated and shown. |
| 11 | Try to clock in a staff member who is already clocked in. | Error: "Already clocked in". |
| 12 | Weekly total hours calculated correctly. | Sum of all shift durations for the week shown. |

---

## MODULE 6 — ACCOUNT & SETTINGS

### 6.1 Account Settings
**Description:** Update profile, change display name, update password, manage organisation details.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to Account Settings. | Current profile info shown (email, name, org details). |
| 2 | Update display name. Save. | New name shown in the app header. |
| 3 | Change password. Enter current password + new password + confirm. | Password updated. A re-login may be required. |
| 4 | Enter wrong current password. | Error: "Current password is incorrect". |
| 5 | New password and confirm do not match. | Validation error. |
| 6 | Update organisation's currency to a different symbol. | New currency symbol shown throughout the app. |
| 7 | Upload a new profile picture. | Profile picture updated in the top bar. |

---

### 6.2 Upgrade Plan (Billing)
**Description:** Upgrade from Free to Starter or Pro plan via PayHere payment.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Navigate to `/app/upgrade` or click upgrade prompt. | Upgrade screen shown with available plans (Starter, Pro). |
| 2 | Select "Starter" plan. | Starter selected with price shown. Features list updates. |
| 3 | Select "Pro" plan. | Pro selected with higher price shown. |
| 4 | Toggle "Annual (save 20%)". | Annual billing selected. Price shows 20% discount. |
| 5 | Fill in First Name, Last Name, Phone. Click "Pay". | PayHere checkout page opens in the same tab/new tab. |
| 6 | Complete sandbox payment with PayHere test card. | Payment success. Redirected to dashboard with `?upgraded=1`. Plan updated in the top-right badge. |
| 7 | Click "Cancel" on PayHere checkout. | Redirected back to `/app/upgrade`. Plan not changed. |
| 8 | Leave First Name blank. Click Pay. | Validation error. Payment not initiated. |
| 9 | Attempt to "downgrade" (e.g. on Pro plan, try to pay for Starter). | Error: "Cannot downgrade. Contact support." |

---

## MODULE 7 — GUEST PORTAL (No Login Required)

### 7.1 Guest Self Check-In
**Description:** Guests scan a QR code or visit `/guest-registration?ref=BK-XXXX` to self-register.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Open `/guest-registration?ref=BK-0001` in a browser (no login). | Check-in page loads with guest's booking details. |
| 2 | Fill in guest details (name, ID, nationality). Submit. | Guest registered. Check-in status updated. Success screen shown. |
| 3 | Use an invalid booking reference. | Error: "Booking not found". |
| 4 | Use a booking reference that is already checked in. | Message: "You are already checked in". |
| 5 | Leave required fields blank. Click Submit. | Validation errors shown per field. |
| 6 | Page works on mobile browser without login. | Fully functional. No login prompt. |

---

### 7.2 Guest Menu (QR Table Ordering)
**Description:** Guests at a restaurant table scan the table QR code to view the menu and place orders.

URL format: `/menu/:propertyId/:tableId`

| # | Steps | Expected Result |
|---|---|---|
| 1 | Open guest menu URL in browser (no login). | Menu loads with categories and items for the correct property. |
| 2 | Browse menu categories. | Categories filter the item list correctly. |
| 3 | Add items to cart. | Cart updates with items and quantities. |
| 4 | Adjust item quantity from cart. | Quantity changes. Subtotal recalculates. |
| 5 | Remove item from cart. | Item removed. Total recalculates. |
| 6 | Confirm and place order. | Order sent to KDS. Confirmation message shown to guest. |
| 7 | Item marked unavailable by staff. | Item shown as unavailable/greyed out. Cannot be added to cart. |
| 8 | Property logo and name shown correctly. | Branding matches the property's configuration. |
| 9 | Page is mobile-friendly (opened on phone). | Fully responsive. Easy to use on small screen. |

---

### 7.3 Guest Room Service
**Description:** In-room guests scan QR to order room service from their room.

URL format: `/room-service/:propertyId/:roomNumber`

| # | Steps | Expected Result |
|---|---|---|
| 1 | Open room service URL in browser (no login). | Menu loads filtered for room service items. Room number shown. |
| 2 | Add items and place room service order. | Order sent to KDS with room number tag. |
| 3 | Order appears in POS/KDS with "Room Service" label and room number. | Correct tagging visible to kitchen staff. |
| 4 | Page is mobile-friendly. | Fully responsive. |

---

## MODULE 8 — PROPERTY MANAGEMENT

### 8.1 Add / Edit Property
**Description:** Owners can add additional properties and edit existing property details.

| # | Steps | Expected Result |
|---|---|---|
| 1 | Click "Add Property" in sidebar. | Property setup screen opens. |
| 2 | Fill in property name, type, address, primary colour. Save. | New property created. Appears in property switcher. |
| 3 | Attempt to add a property beyond the plan limit. | Upgrade prompt shown. |
| 4 | Click "Manage Properties" in property switcher. | Dialog shows all properties with Edit/Delete options. |
| 5 | Edit a property's name. Save. | Updated name shown in sidebar and header. |
| 6 | Change a property's primary colour. | Sidebar accent colour updates to reflect the new colour. |
| 7 | Upload/change a property logo. | Logo appears in sidebar header. |
| 8 | Mark a property as Inactive. | Property shown with "Inactive" warning in the app. Features may be restricted. |

---

## MODULE 9 — SUPERADMIN (Platform Admin Only)

*Accessible only to accounts with the superadmin role via `/superadmin`.*

### 9.1 Superadmin Dashboard
| # | Steps | Expected Result |
|---|---|---|
| 1 | Login as superadmin. Navigate to `/superadmin`. | Dashboard shows total organisations, revenue metrics, and recent signups. |

### 9.2 Companies / Organisations
| # | Steps | Expected Result |
|---|---|---|
| 1 | Click "Companies" in superadmin menu. | List of all registered organisations shown. |
| 2 | Click a company name. | Company detail screen shows: org name, owner email, current plan, properties, staff count. |
| 3 | Update an org's status to "Suspended". | Org's users cannot log in (or see suspended message). |
| 4 | Delete an organisation. Confirm. | Organisation and all associated data removed. |

### 9.3 Enterprise Leads
| # | Steps | Expected Result |
|---|---|---|
| 1 | Click "Leads" in superadmin menu. | List of enterprise enquiries shown. |
| 2 | Click "Provision Access" on a lead. | Dialog to provision enterprise limits (max properties, rooms, users, tables, price). |
| 3 | Provision a lead whose account already exists. | Access provisioned immediately. Organisation plan set to Enterprise with configured limits. |
| 4 | Provision a lead whose email is not yet registered. | Invitation email sent to that email. Status shows "Invitation Sent". |
| 5 | Invited user signs up via invite link. Completes onboarding. | Enterprise plan automatically applied. No manual step needed. |

### 9.4 Plans Management
| # | Steps | Expected Result |
|---|---|---|
| 1 | Click "Plans" in superadmin menu. | List of all plans shown (Free, Starter, Pro, Enterprise). |
| 2 | Edit the Starter plan's monthly price. Save. | New price reflected on the public landing page's pricing section and the upgrade screen. |
| 3 | Toggle a plan's "is_active" off. | Plan disappears from the public pricing page and the upgrade screen. |
| 4 | Update a plan's feature limits (max_rooms, max_users etc). | New limits enforced for new accounts on that plan. |

---

## MODULE 10 — LANDING PAGE (Public)

| # | Steps | Expected Result |
|---|---|---|
| 1 | Visit the root URL `/` when not logged in. | Landing page loads with hero section, features, pricing, comparison table, testimonials. |
| 2 | Click "Get Started" or "Start Free". | Redirected to `/signup`. |
| 3 | Pricing section shows plan cards. | Plans, prices, and feature lists fetched from DB. Correct prices shown. |
| 4 | Comparison table "Starting price" row for HotRest. | Shows the actual Starter plan price from the DB (not hardcoded). |
| 5 | Click "Upgrade" on a Starter plan card. | Redirected to `/signup?plan=starter`. |
| 6 | Click "Contact Us" on Enterprise plan. | Enterprise enquiry form/dialog opens. |
| 7 | Submit enterprise contact form. | Lead saved in the superadmin leads screen. Confirmation shown to user. |
| 8 | Visit `/` when already logged in. | Automatically redirected to `/app/dashboard`. |
| 9 | Navigate to `/terms`, `/privacy`, `/returns`. | Respective legal pages load. |
| 10 | Navigate to `/help`. | Help and documentation page loads. |

---

## MODULE 11 — MOBILE APP

*Available as a native Android/iOS app for front-desk quick access.*

### 11.1 Booking Lookup
| # | Steps | Expected Result |
|---|---|---|
| 1 | Open mobile app. Enter a valid booking reference. Search. | Booking details shown (guest name, room, dates, status). |
| 2 | Enter an invalid booking reference. | Error: "No booking found with this reference". |
| 3 | Leave the field blank. Tap Search. | Validation error: field required. |

### 11.2 Mobile Check-In Confirmation
| # | Steps | Expected Result |
|---|---|---|
| 1 | From booking lookup results, tap "Check In". | Check-in confirmation screen shown with booking details. |
| 2 | Confirm check-in. | Guest status updated to Checked In. Room marked Occupied. |
| 3 | Try to check in a booking that is already checked in. | Message: "Guest is already checked in". |
| 4 | Try to check in a cancelled booking. | Error: "Cannot check in a cancelled booking". |

---

## MODULE 12 — CROSS-CUTTING CONCERNS

### 12.1 Plan Limit Enforcement
| Feature | Free | Starter | Pro | Enterprise |
|---|---|---|---|---|
| Properties | 1 | 2 | 5 | Custom |
| Rooms | 10 | 30 | 150 | Custom |
| Staff accounts | 3 | 6 | 25 | Custom |
| Restaurant tables | 5 | 15 | 30 | Custom |

**Tests:**
- Attempt to exceed each limit → Upgrade dialog shown with correct messaging.
- After upgrading, limits are lifted immediately (no restart needed).

---

### 12.2 Permission-Based Access (Staff Accounts)
| # | Steps | Expected Result |
|---|---|---|
| 1 | Log in as Staff with "Hotel = None". | Rooms, Check-Ins, Reservations, Financials, Expenses not shown in sidebar. |
| 2 | Log in as Staff with "Hotel = View". | Sections visible but all edit/add/delete buttons are hidden or disabled. |
| 3 | Log in as Staff with "Hotel = Edit". | Full CRUD access to hotel sections. |
| 4 | Log in as Staff with "Restaurant = None". | POS, Kitchen, Tables, Orders, Analytics not shown. |
| 5 | Log in as Manager. | All sections accessible. No billing/plan options. |
| 6 | Log in as Owner. | All sections accessible including billing and property management. |

---

### 12.3 Multi-Property Isolation
| # | Steps | Expected Result |
|---|---|---|
| 1 | Switch to Property A. Add a room. Switch to Property B. | Room added to A does not appear under Property B. |
| 2 | Create a reservation under Property A. Switch to B. | Reservation not visible under Property B. |
| 3 | Staff assigned only to Property A. Log in. | Cannot see Property B's data. |

---

### 12.4 Real-Time Updates (Restaurant)
| # | Steps | Expected Result |
|---|---|---|
| 1 | Open POS in Tab A. Open Kitchen in Tab B. Place order in Tab A. | Order appears in Kitchen (Tab B) within 2–3 seconds. No page refresh needed. |
| 2 | Move order to "Ready" in Kitchen. | Table status in Tables screen updates. |
| 3 | Update an order status. Open Tables screen. | Table status reflects the current order state. |

---

### 12.5 Currency & Localisation
| # | Steps | Expected Result |
|---|---|---|
| 1 | Set property currency to LKR in Account Settings. | All monetary amounts across the app (POS totals, financials, expenses) show LKR symbol. |
| 2 | Set currency to USD. | All amounts show $ symbol. |
| 3 | Large amounts are formatted with comma separators (e.g. 10,000.00). | Numbers formatted correctly everywhere. |

---

## APPENDIX — TEST DATA SETUP

Before beginning testing, set up the following test data:

1. **Owner account** — register a new account, complete onboarding, create a property "Test Hotel".
2. **Manager account** — create via Team Members with full permissions.
3. **Staff account (view only)** — create via Team Members with Hotel=View, Restaurant=View.
4. **Rooms** — add 5 rooms (Room 101–105, various types, LKR 5000–15000/night).
5. **Menu items** — add 10 items across 3 categories.
6. **Ingredients** — add 5 ingredients linked to menu items.
7. **Restaurant tables** — add 5 tables (Table 1–5).
8. **Bookings** — create 3 bookings:
   - One checked in (active).
   - One pending (future check-in).
   - One checked out (past).

---

## APPENDIX — KNOWN LIMITATIONS (As of UAT)

| Item | Detail |
|---|---|
| Payment gateway | PayHere sandbox only. Use PayHere test cards for payment testing. Production cards will not work until live key is set. |
| Email sending | Invite emails require the `invite-enterprise-user` Edge Function to be deployed. |
| Real-time | Requires Supabase Realtime to be enabled. If orders don't appear in KDS instantly, check Realtime is on in Supabase Dashboard. |
| Housekeeping notifications | Auto-generated nightly via pg_cron. In testing, trigger manually via SQL: `SELECT generate_housekeeping_notifications();` |
