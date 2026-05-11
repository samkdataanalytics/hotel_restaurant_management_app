"""
fill_qa_results.py
Reads HotRest_QA_Test_Document.xlsx, fills column E (RESULT) for every test row
based on static code review findings, then saves as HotRest_QA_Results.xlsx.

Result classifications:
  PASS         — code reviewed and implementation is correct
  FAIL         — specific bug or missing feature found in source code
  PARTIAL      — feature exists but is incomplete or has a discrepancy
  RUNTIME ONLY — needs a live running app to verify; cannot be confirmed statically
"""

from openpyxl import load_workbook
from openpyxl.styles import PatternFill, Font, Alignment

INPUT  = r"c:\Users\gphks\Documents\MyDoc\Proj\ideadeck\my_projects\proj_1\HotRest_QA_Test_Document.xlsx"
OUTPUT = r"c:\Users\gphks\Documents\MyDoc\Proj\ideadeck\my_projects\proj_1\HotRest_QA_Results.xlsx"

# ── Colour fills ──────────────────────────────────────────────────────────────
FILL_PASS    = PatternFill("solid", fgColor="D9F2E3")   # green
FILL_FAIL    = PatternFill("solid", fgColor="FCE4E4")   # red
FILL_PARTIAL = PatternFill("solid", fgColor="FFF3CD")   # amber
FILL_RT      = PatternFill("solid", fgColor="E8F0FE")   # light blue

FONT_PASS    = Font(name="Calibri", size=9, bold=True, color="1A6B3C")
FONT_FAIL    = Font(name="Calibri", size=9, bold=True, color="C0392B")
FONT_PARTIAL = Font(name="Calibri", size=9, bold=True, color="7D5A00")
FONT_RT      = Font(name="Calibri", size=9, italic=True, color="1A4B8C")

LABEL = {
    "PASS":         ("PASS",         FILL_PASS,    FONT_PASS),
    "FAIL":         ("FAIL",         FILL_FAIL,    FONT_FAIL),
    "PARTIAL":      ("PARTIAL",      FILL_PARTIAL, FONT_PARTIAL),
    "RUNTIME ONLY": ("RUNTIME ONLY", FILL_RT,      FONT_RT),
}

# ── Results dictionary ────────────────────────────────────────────────────────
# Format: "TC-ID": ("RESULT", "optional finding note appended to cell")
RESULTS = {

    # ── Module 1: AUTH ────────────────────────────────────────────────────────
    "TC-AUTH-01": ("PASS",         ""),
    "TC-AUTH-02": ("PASS",         "Handled via identities[].isEmpty check"),
    "TC-AUTH-03": ("FAIL",         "BUG: min password length is 6 chars in code (signup_screen.dart), not 8 as documented — 6- or 7-char passwords accepted"),
    "TC-AUTH-04": ("PASS",         ""),
    "TC-AUTH-05": ("PASS",         ""),
    "TC-AUTH-06": ("PASS",         "?plan= saved to SharedPreferences as pending_plan"),
    "TC-AUTH-07": ("PASS",         ""),
    "TC-AUTH-08": ("PASS",         ""),
    "TC-AUTH-09": ("PASS",         ""),
    "TC-AUTH-10": ("PASS",         ""),
    "TC-AUTH-11": ("PASS",         "Username resolved via staffService.getEmailByUsername()"),
    "TC-AUTH-12": ("PASS",         "Router redirects isSuperadmin → /superadmin"),
    "TC-AUTH-13": ("PASS",         "GoRouter redirect guard re-checks auth on every navigation"),
    "TC-AUTH-14": ("PASS",         ""),
    "TC-AUTH-15": ("PASS",         ""),
    "TC-AUTH-16": ("PASS",         ""),
    "TC-AUTH-17": ("RUNTIME ONLY", "Logo upload UI exists; file-type filtering needs live confirmation"),
    "TC-AUTH-18": ("RUNTIME ONLY", "Non-image rejection depends on platform picker/validator"),
    "TC-AUTH-19": ("PASS",         ""),
    "TC-AUTH-20": ("PASS",         ""),
    "TC-AUTH-21": ("PASS",         "accept_invite_screen shows role and property info"),
    "TC-AUTH-22": ("PASS",         ""),
    "TC-AUTH-23": ("PASS",         "preview['expired'] == true shows expired message"),
    "TC-AUTH-24": ("PASS",         "preview['status'] == 'accepted' shows already-used message"),

    # ── Module 2: NAVIGATION ──────────────────────────────────────────────────
    "TC-NAV-01":  ("PASS",         "Active item highlighted via isSelected state in sidebar"),
    "TC-NAV-02":  ("PASS",         "isMobile = width < 768 in app_shell.dart"),
    "TC-NAV-03":  ("PASS",         "Drawer widget used for mobile sidebar"),
    "TC-NAV-04":  ("PASS",         "_activeSections() filters out PrivilegeLevel.none items"),
    "TC-NAV-05":  ("PASS",         ""),
    "TC-NAV-06":  ("PASS",         "Property selector dropdown in sidebar"),
    "TC-NAV-07":  ("PASS",         "_applyActiveProperty() sets hotelId on all repos/services"),
    "TC-NAV-08":  ("PASS",         "Manage Properties dialog lists all properties with Edit/Delete"),
    "TC-NAV-09":  ("PASS",         "NotificationBell overlay panel opens on tap"),
    "TC-NAV-10":  ("PASS",         "onMarkRead(id) calls service.markAsRead(id)"),
    "TC-NAV-11":  ("PASS",         "Mark all read button exists in notification panel"),
    "TC-NAV-12":  ("RUNTIME ONLY", "Auto housekeeping notification after 3+ nights needs live data"),
    "TC-NAV-13":  ("PASS",         "Dropdown shows email, plan badge, Account Settings, Logout"),
    "TC-NAV-14":  ("PASS",         ""),
    "TC-NAV-15":  ("PASS",         "Router guard prevents re-entry after session clear"),

    # ── Module 3: HOTEL ───────────────────────────────────────────────────────
    "TC-HOT-01":  ("PASS",         "Dashboard KPI cards: Check-ins, Occupancy %, Revenue, Orders"),
    "TC-HOT-02":  ("RUNTIME ONLY", "Currency symbol rendering needs live property-currency config"),
    "TC-HOT-03":  ("PASS",         "Zero-value state handled; no crash path in code"),
    "TC-HOT-04":  ("RUNTIME ONLY", "Subscription payment banner depends on live billing data"),
    "TC-HOT-05":  ("RUNTIME ONLY", "Absence of banner for non-enterprise plans needs live testing"),
    "TC-HOT-06":  ("PASS",         "Rooms grid with colour-coded status indicators"),
    "TC-HOT-07":  ("PASS",         "Add room dialog with number, type, price, floor, capacity fields"),
    "TC-HOT-08":  ("PASS",         "Edit room dialog; save updates room in grid"),
    "TC-HOT-09":  ("PASS",         "Maintenance status with start/end date pickers"),
    "TC-HOT-10":  ("FAIL",         "BUG: maintenance date picker uses firstDate = now-30d; no cross-validation that end date > start date — past/overlapping dates accepted"),
    "TC-HOT-11":  ("PASS",         ""),
    "TC-HOT-12":  ("PASS",         ""),
    "TC-HOT-13":  ("PASS",         ""),
    "TC-HOT-14":  ("PASS",         "Delete blocked if room.status == RoomStatus.occupied"),
    "TC-HOT-15":  ("PASS",         "canAddRoom() checked; showUpgradePlanDialog() on limit hit"),
    "TC-HOT-16":  ("FAIL",         "BUG: price validator only checks double.tryParse() == null; negative values like -100 pass — no > 0 check in _RoomFormDialog"),
    "TC-HOT-17":  ("PASS",         "Room number empty check present in form validator"),
    "TC-HOT-18":  ("PASS",         "QrImageView with /room-service/:propertyId/:roomNumber URL"),
    "TC-HOT-19":  ("RUNTIME ONLY", "14-day Gantt calendar layout needs live rendering test"),
    "TC-HOT-20":  ("RUNTIME ONLY", "Calendar day-shift navigation needs live interaction"),
    "TC-HOT-21":  ("RUNTIME ONLY", "Booking block creation on calendar needs live testing"),
    "TC-HOT-22":  ("RUNTIME ONLY", "Booking detail side-panel needs live data"),
    "TC-HOT-23":  ("RUNTIME ONLY", "Booking resize on date edit needs live testing"),
    "TC-HOT-24":  ("RUNTIME ONLY", "Booking deletion and calendar refresh needs live testing"),
    "TC-HOT-25":  ("RUNTIME ONLY", "Source filter on reservations needs live booking data"),
    "TC-HOT-26":  ("RUNTIME ONLY", "Print folio PDF generation needs live testing"),
    "TC-HOT-27":  ("RUNTIME ONLY", "Double-booking prevention relies on DB constraint + live data"),
    "TC-HOT-28":  ("RUNTIME ONLY", "Check-out < check-in date validation needs live interaction"),
    "TC-HOT-29":  ("RUNTIME ONLY", "Maintenance blocks on calendar need live room status data"),
    "TC-HOT-30":  ("RUNTIME ONLY", "Check-ins list data depends on live bookings"),
    "TC-HOT-31":  ("RUNTIME ONLY", "Check-in action and room status update needs live testing"),
    "TC-HOT-32":  ("RUNTIME ONLY", "Check-out action needs live testing"),
    "TC-HOT-33":  ("RUNTIME ONLY", "Guest name search needs live data"),
    "TC-HOT-34":  ("RUNTIME ONLY", "Guest email search needs live data"),
    "TC-HOT-35":  ("RUNTIME ONLY", "Expandable row details need live guest data"),
    "TC-HOT-36":  ("RUNTIME ONLY", "Print folio with expenses and restaurant orders needs live data"),
    "TC-HOT-37":  ("RUNTIME ONLY", "Bookings tab filter needs live booking data"),
    "TC-HOT-38":  ("RUNTIME ONLY", "Financials KPI cards need live revenue data"),
    "TC-HOT-39":  ("RUNTIME ONLY", "Net profit arithmetic verified in code but needs live figures"),
    "TC-HOT-40":  ("RUNTIME ONLY", "Date range recalculation needs live data"),
    "TC-HOT-41":  ("RUNTIME ONLY", "Custom date range needs live data"),
    "TC-HOT-42":  ("RUNTIME ONLY", "Invalid date range handling needs live interaction"),
    "TC-HOT-43":  ("RUNTIME ONLY", "Booking source filter needs live data"),
    "TC-HOT-44":  ("RUNTIME ONLY", "Daily breakdown table needs live data"),
    "TC-HOT-45":  ("RUNTIME ONLY", "Zero-booking edge case needs live state"),
    "TC-HOT-46":  ("RUNTIME ONLY", "Expenses list display needs live data"),
    "TC-HOT-47":  ("RUNTIME ONLY", "Add expense flow needs live testing"),
    "TC-HOT-48":  ("RUNTIME ONLY", "Room-linked expense on folio needs live testing"),
    "TC-HOT-49":  ("RUNTIME ONLY", "Billable flag and invoice appearance needs live testing"),
    "TC-HOT-50":  ("RUNTIME ONLY", "Paid status update needs live testing"),
    "TC-HOT-51":  ("RUNTIME ONLY", "Edit expense and financials refresh needs live testing"),
    "TC-HOT-52":  ("RUNTIME ONLY", "Delete expense and cost recalculation needs live testing"),
    "TC-HOT-53":  ("RUNTIME ONLY", "Zero-amount expense validation needs live interaction"),
    "TC-HOT-54":  ("RUNTIME ONLY", "No-description expense validation needs live interaction"),

    # ── Module 4: RESTAURANT ──────────────────────────────────────────────────
    "TC-RES-01":  ("RUNTIME ONLY", "POS screen layout needs live rendering test"),
    "TC-RES-02":  ("RUNTIME ONLY", "Order panel building needs live POS interaction"),
    "TC-RES-03":  ("RUNTIME ONLY", "Quantity +/- and total recalculation needs live testing"),
    "TC-RES-04":  ("RUNTIME ONLY", "Item removal from order needs live testing"),
    "TC-RES-05":  ("RUNTIME ONLY", "Discount application and total display needs live testing"),
    "TC-RES-06":  ("RUNTIME ONLY", "Dine-In order type and service charge needs live testing"),
    "TC-RES-07":  ("RUNTIME ONLY", "Takeaway order type needs live testing"),
    "TC-RES-08":  ("RUNTIME ONLY", "Delivery platform selector needs live testing"),
    "TC-RES-09":  ("RUNTIME ONLY", "Order-to-KDS flow needs live POS + KDS open"),
    "TC-RES-10":  ("RUNTIME ONLY", "Split payment dialog needs live POS testing"),
    "TC-RES-11":  ("RUNTIME ONLY", "Room charge posting to guest folio needs live check-in data"),
    "TC-RES-12":  ("RUNTIME ONLY", "Zero-stock item greyout needs live inventory state"),
    "TC-RES-13":  ("RUNTIME ONLY", "Zero-items place order block needs live POS state"),
    "TC-RES-14":  ("RUNTIME ONLY", "Discount > total validation needs live POS testing"),
    "TC-RES-15":  ("RUNTIME ONLY", "Split total mismatch error needs live split payment dialog"),
    "TC-RES-16":  ("RUNTIME ONLY", "Floor plan colour-coded tables need live table/order state"),
    "TC-RES-17":  ("RUNTIME ONLY", "Click-empty-table to POS needs live interaction"),
    "TC-RES-18":  ("RUNTIME ONLY", "Click-occupied-table shows orders needs live data"),
    "TC-RES-19":  ("RUNTIME ONLY", "Real-time table status update needs two live tabs"),
    "TC-RES-20":  ("PASS",         "KDS kanban columns: Pending, Preparing, Ready, Payment Due — code confirmed"),
    "TC-RES-21":  ("PASS",         "Supabase realtime channel on restaurant_orders with hotel_id filter"),
    "TC-RES-22":  ("RUNTIME ONLY", "Move to Preparing status update needs live KDS interaction"),
    "TC-RES-23":  ("RUNTIME ONLY", "Move to Ready needs live testing"),
    "TC-RES-24":  ("RUNTIME ONLY", "Move to Payment Due needs live testing"),
    "TC-RES-25":  ("FAIL",         "BUG: No green state for <5 min — default card colour is slate (no colour); amber starts at 8 min, not 5 min as documented"),
    "TC-RES-26":  ("PARTIAL",      "Amber/yellow exists but triggers at ≥8 min (code), not ≥5 min as documented — threshold discrepancy in kitchen_screen.dart"),
    "TC-RES-27":  ("PASS",         "Red at ≥15 min threshold matches spec"),
    "TC-RES-28":  ("PASS",         "_soundEnabled flag; _playNotificationBeep() via JS Web Audio API on new order"),
    "TC-RES-29":  ("PASS",         "Sound OFF branch skips _playNotificationBeep()"),
    "TC-RES-30":  ("RUNTIME ONLY", "Menu item list display needs live data"),
    "TC-RES-31":  ("RUNTIME ONLY", "Add menu item and POS appearance needs live testing"),
    "TC-RES-32":  ("RUNTIME ONLY", "Menu item image upload needs live testing"),
    "TC-RES-33":  ("RUNTIME ONLY", "Availability toggle and POS/guest menu greyout needs live test"),
    "TC-RES-34":  ("RUNTIME ONLY", "Price edit and POS update needs live testing"),
    "TC-RES-35":  ("RUNTIME ONLY", "Menu item delete across all views needs live testing"),
    "TC-RES-36":  ("RUNTIME ONLY", "Zero price validation in menu item form needs live testing"),
    "TC-RES-37":  ("RUNTIME ONLY", "Ingredients list needs live data"),
    "TC-RES-38":  ("RUNTIME ONLY", "Add ingredient needs live testing"),
    "TC-RES-39":  ("RUNTIME ONLY", "Stock +10 needs live testing"),
    "TC-RES-40":  ("RUNTIME ONLY", "Stock -5 and zero-floor needs live testing"),
    "TC-RES-41":  ("RUNTIME ONLY", "Low-stock warning indicator needs live inventory state"),
    "TC-RES-42":  ("RUNTIME ONLY", "Auto-deduct on order serve needs live order cycle"),
    "TC-RES-43":  ("RUNTIME ONLY", "Stock restore on refund needs live refund flow"),
    "TC-RES-44":  ("RUNTIME ONLY", "Tables config list needs live data"),
    "TC-RES-45":  ("RUNTIME ONLY", "Add table and POS/floor plan appearance needs live testing"),
    "TC-RES-46":  ("PASS",         "QR generation confirmed: /menu/:propertyId/:tableId URL in code"),
    "TC-RES-47":  ("RUNTIME ONLY", "Delete table and removal from all views needs live testing"),
    "TC-RES-48":  ("PASS",         "canAddTable() checked before dialog; upgrade prompt on limit"),
    "TC-RES-49":  ("RUNTIME ONLY", "Tax & charges config display needs live data"),
    "TC-RES-50":  ("RUNTIME ONLY", "Tax rate change reflecting in POS needs live testing"),
    "TC-RES-51":  ("RUNTIME ONLY", "Service charge dine-in-only enforcement needs live testing"),
    "TC-RES-52":  ("RUNTIME ONLY", "Negative percentage validation needs live form interaction"),
    "TC-RES-53":  ("RUNTIME ONLY", "Orders list needs live order data"),
    "TC-RES-54":  ("RUNTIME ONLY", "Today filter needs live data"),
    "TC-RES-55":  ("RUNTIME ONLY", "Status filter needs live data"),
    "TC-RES-56":  ("RUNTIME ONLY", "Order number search needs live data"),
    "TC-RES-57":  ("RUNTIME ONLY", "Order row expansion needs live data"),
    "TC-RES-58":  ("RUNTIME ONLY", "Full refund flow needs live order data"),
    "TC-RES-59":  ("RUNTIME ONLY", "Partial refund with item selection needs live testing"),
    "TC-RES-60":  ("RUNTIME ONLY", "Refund-cancelled-order block needs live cancelled order"),
    "TC-RES-61":  ("RUNTIME ONLY", "Analytics KPIs need live order history"),
    "TC-RES-62":  ("RUNTIME ONLY", "AOV = Revenue ÷ Count arithmetic needs live figures"),
    "TC-RES-63":  ("RUNTIME ONLY", "Last 7 days filter needs live data"),
    "TC-RES-64":  ("RUNTIME ONLY", "Custom date range needs live data"),
    "TC-RES-65":  ("RUNTIME ONLY", "Pie chart distribution needs live order type data"),
    "TC-RES-66":  ("RUNTIME ONLY", "Top items list needs live order history"),
    "TC-RES-67":  ("RUNTIME ONLY", "Service charge tab needs live data"),
    "TC-RES-68":  ("RUNTIME ONLY", "Zero orders edge case needs live state"),
    "TC-RES-69":  ("RUNTIME ONLY", "Cancellations KPI row needs live cancelled orders"),
    "TC-RES-70":  ("RUNTIME ONLY", "Cancelled order row detail needs live data"),
    "TC-RES-71":  ("RUNTIME ONLY", "Refunded Items tab needs live refund records"),
    "TC-RES-72":  ("RUNTIME ONLY", "Refund amount arithmetic needs live refund data"),

    # ── Module 5: TEAM ────────────────────────────────────────────────────────
    "TC-TEAM-01": ("RUNTIME ONLY", "Staff list display needs live org data"),
    "TC-TEAM-02": ("PASS",         "Add staff dialog with username/password/name; invite link generated"),
    "TC-TEAM-03": ("RUNTIME ONLY", "Duplicate username error depends on DB UNIQUE constraint + live test"),
    "TC-TEAM-04": ("PASS",         "_EditPermissionsDialog exists; Hotel=None removes hotel items from sidebar"),
    "TC-TEAM-05": ("PASS",         "PrivilegeLevel.view hides edit/add/delete controls via canEditSection()"),
    "TC-TEAM-06": ("PASS",         "PrivilegeLevel.edit grants full CRUD in all hotel/restaurant sections"),
    "TC-TEAM-07": ("PASS",         "_ResetPasswordDialog confirmed present in users_management_screen.dart"),
    "TC-TEAM-08": ("RUNTIME ONLY", "Staff deactivation and login-block depends on DB update + auth state"),
    "TC-TEAM-09": ("PASS",         "canAddStaff() checked before add dialog; upgrade prompt shown"),
    "TC-TEAM-10": ("RUNTIME ONLY", "Shifts week view needs live shift data"),
    "TC-TEAM-11": ("RUNTIME ONLY", "Week navigation needs live interaction"),
    "TC-TEAM-12": ("RUNTIME ONLY", "Add shift dialog needs live testing"),
    "TC-TEAM-13": ("RUNTIME ONLY", "End < start time validation needs live form interaction"),
    "TC-TEAM-14": ("RUNTIME ONLY", "Time Tracking tab needs live clock records"),
    "TC-TEAM-15": ("RUNTIME ONLY", "Clock-in record and elapsed time needs live testing"),
    "TC-TEAM-16": ("RUNTIME ONLY", "Clock-out duration calculation needs live testing"),
    "TC-TEAM-17": ("RUNTIME ONLY", "Already-clocked-in guard needs live clock state"),

    # ── Module 6: ACCOUNT & BILLING ───────────────────────────────────────────
    "TC-ACC-01":  ("PASS",         "Account Settings shows email (read-only), name, job title, phone, org details"),
    "TC-ACC-02":  ("PASS",         "_saveProfile() updates fullName via organizationService.updateProfile()"),
    "TC-ACC-03":  ("FAIL",         "BUG: No password change feature in account_settings_screen.dart — section entirely absent"),
    "TC-ACC-04":  ("FAIL",         "BUG: Cannot test wrong-current-password error — password change form does not exist"),
    "TC-ACC-05":  ("FAIL",         "BUG: Cannot test confirm-password mismatch — password change form does not exist"),
    "TC-ACC-06":  ("PARTIAL",      "Currency is a per-property setting in Edit Property dialog, not in Account Settings — TC tests Account Settings currency change which does not exist there"),
    "TC-ACC-07":  ("PASS",         "Upgrade screen loads with plan cards; plans filtered by sortOrder > current plan"),
    "TC-ACC-08":  ("RUNTIME ONLY", "Plan card highlight on selection needs live UI interaction"),
    "TC-ACC-09":  ("PASS",         "Annual toggle: effectiveAmount = (priceMonthly × 0.8).round() — 20% discount confirmed in code"),
    "TC-ACC-10":  ("PASS",         "First/Last Name, Phone validators present; PayHere.checkout() triggered on valid form"),
    "TC-ACC-11":  ("RUNTIME ONLY", "Sandbox payment completion and plan badge update needs live PayHere integration"),
    "TC-ACC-12":  ("RUNTIME ONLY", "PayHere cancel callback redirect needs live payment gateway test"),
    "TC-ACC-13":  ("PASS",         "First name empty check: (v == null || v.trim().isEmpty) ? 'Required' : null"),
    "TC-ACC-14":  ("PASS",         "Downgrade blocked: plans filtered by p.sortOrder > currentPlan.sortOrder"),

    # ── Module 7: GUEST PORTAL ────────────────────────────────────────────────
    "TC-GST-01":  ("PASS",         "_lookupBooking() loads booking details; no auth required"),
    "TC-GST-02":  ("PASS",         "_submit() calls updateGuest() + updateBooking(isGuestFormSubmitted: true)"),
    "TC-GST-03":  ("PASS",         "Invalid ref shows 'Booking not found' error state"),
    "TC-GST-04":  ("PASS",         "booking.isGuestFormSubmitted == true shows 'Already Checked In' screen"),
    "TC-GST-05":  ("PASS",         "_canProceedPersonal() requires name, passport/ID, email non-empty"),
    "TC-GST-06":  ("RUNTIME ONLY", "Mobile browser responsiveness needs live device/viewport test"),
    "TC-GST-07":  ("PASS",         "Guest menu URL /menu/:propertyId/:tableId bypasses auth in router"),
    "TC-GST-08":  ("RUNTIME ONLY", "Category browsing and item filtering needs live menu data"),
    "TC-GST-09":  ("RUNTIME ONLY", "Cart management and subtotal calculation needs live interaction"),
    "TC-GST-10":  ("RUNTIME ONLY", "Item removal from guest cart needs live interaction"),
    "TC-GST-11":  ("RUNTIME ONLY", "Guest order-to-KDS flow needs live testing"),
    "TC-GST-12":  ("RUNTIME ONLY", "Unavailability greyout on guest menu needs live staff toggle"),
    "TC-GST-13":  ("RUNTIME ONLY", "Mobile responsiveness of guest menu needs live device test"),
    "TC-GST-14":  ("PASS",         "Room service URL /room-service/:propertyId/:roomNumber bypasses auth"),
    "TC-GST-15":  ("RUNTIME ONLY", "Room service order submission needs live testing"),
    "TC-GST-16":  ("RUNTIME ONLY", "Room Service tag on KDS with room number needs live order flow"),

    # ── Module 8: PROPERTY MGMT ───────────────────────────────────────────────
    "TC-PROP-01": ("PASS",         "Add Property sidebar link routes to /property-setup"),
    "TC-PROP-02": ("RUNTIME ONLY", "Full property creation with address/colour needs live testing"),
    "TC-PROP-03": ("PASS",         "canAddProperty() checked; upgrade dialog shown on limit"),
    "TC-PROP-04": ("RUNTIME ONLY", "Property name edit and sidebar header update needs live testing"),
    "TC-PROP-05": ("RUNTIME ONLY", "Primary colour change and sidebar accent update needs live testing"),
    "TC-PROP-06": ("RUNTIME ONLY", "Logo upload and sidebar display needs live testing"),
    "TC-PROP-07": ("PASS",         "_InactivePropertyScreen shown when property.status == 'inactive'"),

    # ── Module 9: SUPERADMIN ──────────────────────────────────────────────────
    "TC-SA-01":   ("RUNTIME ONLY", "Superadmin dashboard metrics need live org/revenue data"),
    "TC-SA-02":   ("RUNTIME ONLY", "Companies list needs live organisation data"),
    "TC-SA-03":   ("RUNTIME ONLY", "Company detail screen needs live org data"),
    "TC-SA-04":   ("RUNTIME ONLY", "Suspend org and login-block effect needs live testing"),
    "TC-SA-05":   ("RUNTIME ONLY", "Delete org and cascade removal needs live testing"),
    "TC-SA-06":   ("RUNTIME ONLY", "Enterprise leads list needs live leads data"),
    "TC-SA-07":   ("RUNTIME ONLY", "Provision for existing account needs live superadmin + org"),
    "TC-SA-08":   ("PARTIAL",      "pending_provisions table stores config for unregistered email; whether invite email sends successfully needs live SMTP/Edge Function test"),
    "TC-SA-09":   ("PASS",         "App checks pending_provisions on first login; auto-applies enterprise plan — logic confirmed in onboarding flow"),
    "TC-SA-10":   ("RUNTIME ONLY", "Plans list display needs live plan data"),
    "TC-SA-11":   ("RUNTIME ONLY", "Starter price edit reflected on landing page needs live DB + page reload"),
    "TC-SA-12":   ("RUNTIME ONLY", "is_active toggle and page disappearance needs live testing"),
    "TC-SA-13":   ("RUNTIME ONLY", "max_rooms update and enforcement needs live plan + room add test"),

    # ── Module 10: LANDING PAGE ───────────────────────────────────────────────
    "TC-LND-01":  ("PASS",         "Landing page with hero, features, comparison, pricing, testimonials confirmed in code"),
    "TC-LND-02":  ("PASS",         "Get Started / Start Free links route to /signup"),
    "TC-LND-03":  ("PASS",         "Pricing section uses Riverpod provider fetching plans from DB — dynamic"),
    "TC-LND-04":  ("PASS",         "Comparison table Starting price row fetches live Starter plan price from DB"),
    "TC-LND-05":  ("PASS",         "Plan upgrade CTA routes to /signup?plan=<planId>"),
    "TC-LND-06":  ("PASS",         "Enterprise Contact Us opens enquiry form/dialog"),
    "TC-LND-07":  ("RUNTIME ONLY", "Enterprise enquiry form save to superadmin leads needs live DB test"),
    "TC-LND-08":  ("PASS",         "Router: if (auth.isLoggedIn && loc == '/') → redirect to /app/dashboard"),
    "TC-LND-09":  ("PASS",         "/terms, /privacy, /returns are public routes confirmed in router.dart"),
    "TC-LND-10":  ("PASS",         "/help is a public route confirmed in router.dart"),

    # ── Module 11: MOBILE APP ─────────────────────────────────────────────────
    "TC-MOB-01":  ("RUNTIME ONLY", "Mobile app booking lookup needs live device test"),
    "TC-MOB-02":  ("RUNTIME ONLY", "Invalid reference error needs live device test"),
    "TC-MOB-03":  ("RUNTIME ONLY", "Blank field validation needs live device interaction"),
    "TC-MOB-04":  ("RUNTIME ONLY", "Mobile check-in and room status update needs live test"),
    "TC-MOB-05":  ("RUNTIME ONLY", "Already-checked-in message needs live booking state"),
    "TC-MOB-06":  ("RUNTIME ONLY", "Cancelled booking check-in block needs live booking state"),

    # ── Module 12: CROSS-CUTTING ──────────────────────────────────────────────
    "TC-CC-01":   ("PASS",         "canAddRoom() with plan max_rooms checked before every add"),
    "TC-CC-02":   ("PASS",         "canAddStaff() with plan max_users checked before every add"),
    "TC-CC-03":   ("PASS",         "canAddTable() with plan max_tables checked before every add"),
    "TC-CC-04":   ("PASS",         "canAddProperty() with plan max_properties checked before every add"),
    "TC-CC-05":   ("RUNTIME ONLY", "Immediate limit enforcement after upgrade needs live plan change"),
    "TC-CC-06":   ("PASS",         "Hotel=None: Rooms, Check-Ins, Reservations, Financials, Expenses absent"),
    "TC-CC-07":   ("PASS",         "Hotel=View: sections visible; canEditSection() hides edit controls"),
    "TC-CC-08":   ("PASS",         "Hotel=Edit: full CRUD access confirmed via permission routing"),
    "TC-CC-09":   ("PASS",         "Restaurant=None: POS, Kitchen, Tables, Orders, Analytics absent"),
    "TC-CC-10":   ("PASS",         "Manager role: all sections except billing accessible"),
    "TC-CC-11":   ("PASS",         "Owner role: all sections including billing and property management"),
    "TC-CC-12":   ("PASS",         "_applyActiveProperty() sets hotelId on all repos — data isolated per property"),
    "TC-CC-13":   ("PASS",         "Reservations scoped to active hotelId — cross-property leakage prevented"),
    "TC-CC-14":   ("PASS",         "Staff property assignment enforced via RLS and hotelId scoping"),
    "TC-CC-15":   ("PASS",         "Supabase realtime channel confirmed on restaurant_orders; KDS auto-updates"),
    "TC-CC-16":   ("RUNTIME ONLY", "Table status real-time update needs two live browser tabs"),
    "TC-CC-17":   ("PARTIAL",      "Currency is per-property (Edit Property dialog), not per Account Settings — symbol display needs live property-currency config test"),
    "TC-CC-18":   ("PARTIAL",      "Same as CC-17 — USD symbol display needs live property-currency config"),
    "TC-CC-19":   ("RUNTIME ONLY", "Comma thousands separator and decimal formatting needs live rendered values"),
}

# ── Apply results to workbook ─────────────────────────────────────────────────

def get_style(result):
    r = result.upper()
    if r == "PASS":
        return FILL_PASS, FONT_PASS
    elif r == "FAIL":
        return FILL_FAIL, FONT_FAIL
    elif r == "PARTIAL":
        return FILL_PARTIAL, FONT_PARTIAL
    else:
        return FILL_RT, FONT_RT

wb = load_workbook(INPUT)
filled = 0
missing = []

for ws in wb.worksheets:
    if ws.title == "Cover":
        continue
    for row in ws.iter_rows():
        cell_a = row[0]  # Column A = test ID
        if cell_a.value and str(cell_a.value).startswith("TC-"):
            tid = str(cell_a.value).strip()
            if tid in RESULTS:
                result_label, note = RESULTS[tid]
                fill_style, font_style = get_style(result_label)

                # Build cell text
                cell_text = result_label
                if note:
                    cell_text = result_label + "\n" + note

                rc = row[4]  # Column E = RESULT
                rc.value = cell_text
                rc.fill = fill_style
                rc.font = font_style
                rc.alignment = Alignment(
                    wrap_text=True, horizontal="center", vertical="top"
                )
                # Increase row height if there's a note
                if note:
                    ws.row_dimensions[rc.row].height = max(
                        ws.row_dimensions[rc.row].height or 52, 68
                    )
                filled += 1
            else:
                missing.append(tid)

wb.save(OUTPUT)

print(f"Filled {filled} test cases -> {OUTPUT}")
if missing:
    print(f"WARNING — {len(missing)} test IDs not found in results dict: {missing}")

# ── Summary stats ─────────────────────────────────────────────────────────────
from collections import Counter
counts = Counter(v[0] for v in RESULTS.values())
total = sum(counts.values())
print(f"\nResult summary ({total} total):")
for label in ("PASS", "FAIL", "PARTIAL", "RUNTIME ONLY"):
    n = counts.get(label, 0)
    print(f"  {label:<14} {n:>3}  ({100*n/total:.1f}%)")
