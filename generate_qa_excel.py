from openpyxl import Workbook
from openpyxl.styles import (
    PatternFill, Font, Alignment, Border, Side, GradientFill
)
from openpyxl.utils import get_column_letter

wb = Workbook()

# ── Colour palette ────────────────────────────────────────────────────────────
NAVY        = "1E3A5F"
GOLD        = "D4A853"
LIGHT_BLUE  = "E8F0FE"
LIGHT_GOLD  = "FFF8E7"
GREEN_PASS  = "D9F2E3"
RED_FAIL    = "FCE4E4"
GREY_ROW    = "F7F9FC"
WHITE       = "FFFFFF"
DARK_TEXT   = "1A1A2E"
MID_GREY    = "E2E8F0"

def fill(hex_color):
    return PatternFill("solid", fgColor=hex_color)

def bold_font(size=10, color=WHITE):
    return Font(name="Calibri", bold=True, size=size, color=color)

def normal_font(size=10, color=DARK_TEXT):
    return Font(name="Calibri", size=size, color=color)

def border():
    thin = Side(style="thin", color="CCCCCC")
    return Border(left=thin, right=thin, top=thin, bottom=thin)

def wrap_align(h="left", v="top"):
    return Alignment(wrap_text=True, horizontal=h, vertical=v)

def center_align():
    return Alignment(horizontal="center", vertical="center", wrap_text=True)

# ── Cover Sheet ───────────────────────────────────────────────────────────────
ws_cover = wb.active
ws_cover.title = "Cover"
ws_cover.sheet_view.showGridLines = False
ws_cover.column_dimensions["A"].width = 4
ws_cover.column_dimensions["B"].width = 60
ws_cover.column_dimensions["C"].width = 30

# Banner
for row in range(1, 8):
    for col in range(1, 12):
        ws_cover.cell(row=row, column=col).fill = fill(NAVY)

ws_cover.row_dimensions[3].height = 20
ws_cover.row_dimensions[4].height = 36
ws_cover.row_dimensions[5].height = 28
ws_cover.row_dimensions[6].height = 20

c = ws_cover.cell(row=4, column=2, value="HotRest")
c.font = Font(name="Calibri", bold=True, size=32, color=GOLD)
c.alignment = Alignment(horizontal="left", vertical="center")

c = ws_cover.cell(row=5, column=2, value="QA Test Document — Hotel & Restaurant Management SaaS")
c.font = Font(name="Calibri", size=16, color=WHITE)
c.alignment = Alignment(horizontal="left", vertical="center")

# Info table
info_rows = [
    ("Platform",    "Web (Flutter Web)  |  Mobile (Android / iOS)"),
    ("Version",     "UAT Build"),
    ("Prepared for","QA Team"),
    ("Modules",     "12 Modules  |  100+ Test Scenarios"),
]
ws_cover.row_dimensions[9].height = 6
r = 10
for label, value in info_rows:
    ws_cover.row_dimensions[r].height = 22
    lc = ws_cover.cell(row=r, column=2, value=label)
    lc.font = Font(name="Calibri", bold=True, size=11, color=NAVY)
    lc.alignment = Alignment(vertical="center")

    vc = ws_cover.cell(row=r, column=3, value=value)
    vc.font = Font(name="Calibri", size=11, color=DARK_TEXT)
    vc.alignment = Alignment(vertical="center")
    r += 1

ws_cover.row_dimensions[r].height = 8
r += 1
note = ws_cover.cell(row=r, column=2,
    value="Each test row has a RESULT column. Mark: PASS  |  FAIL  |  SKIP")
note.font = Font(name="Calibri", italic=True, size=10, color="777777")

# Index table
r += 3
ws_cover.row_dimensions[r].height = 22
hc = ws_cover.cell(row=r, column=2, value="MODULE INDEX")
hc.font = bold_font(12, NAVY)
ws_cover.cell(row=r, column=2).fill = fill(LIGHT_GOLD)
r += 1

modules = [
    ("01", "AUTH",          "Authentication & Onboarding"),
    ("02", "NAVIGATION",    "App Shell & Navigation"),
    ("03", "HOTEL",         "Hotel Management"),
    ("04", "RESTAURANT",    "Restaurant Management"),
    ("05", "TEAM",          "Team Management"),
    ("06", "ACCOUNT",       "Account & Billing"),
    ("07", "GUEST PORTAL",  "Guest Portal (No Login Required)"),
    ("08", "PROPERTY",      "Property Management"),
    ("09", "SUPERADMIN",    "Superadmin (Platform Admin)"),
    ("10", "LANDING",       "Landing Page & Public Pages"),
    ("11", "MOBILE",        "Mobile App"),
    ("12", "CROSS-CUT",     "Cross-Cutting Concerns"),
]

for num, sheet_tab, desc in modules:
    ws_cover.row_dimensions[r].height = 20
    nc = ws_cover.cell(row=r, column=2, value=f"  {num}  {sheet_tab}")
    nc.font = Font(name="Calibri", bold=True, size=10, color=NAVY)
    nc.alignment = Alignment(vertical="center")
    dc = ws_cover.cell(row=r, column=3, value=desc)
    dc.font = normal_font()
    dc.alignment = Alignment(vertical="center")
    if int(num) % 2 == 0:
        nc.fill = fill(GREY_ROW)
        dc.fill = fill(GREY_ROW)
    r += 1


# ── Helper: create a module sheet ─────────────────────────────────────────────

def add_module_sheet(title, color, sections):
    """
    sections = list of dicts:
      { "name": str, "preconditions": str or None,
        "rows": [ (test_id, steps, expected, neg_case) ] }
    neg_case can be "" to omit
    """
    ws = wb.create_sheet(title=title)
    ws.sheet_view.showGridLines = False

    # Column widths
    col_widths = [8, 45, 55, 22, 18]
    col_names  = ["TEST ID", "STEPS / ACTIONS", "EXPECTED RESULT", "NOTES / NEG. CASE", "RESULT"]
    for i, w in enumerate(col_widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w

    row = 1

    # Module header banner
    for col in range(1, 6):
        ws.cell(row=row, column=col).fill = fill(color)
    ws.row_dimensions[row].height = 30
    hc = ws.cell(row=row, column=1, value=title)
    hc.font = Font(name="Calibri", bold=True, size=14, color=WHITE)
    hc.alignment = Alignment(horizontal="left", vertical="center")
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=5)
    row += 1

    for section in sections:
        # Section header
        row += 1
        ws.row_dimensions[row].height = 20
        for col in range(1, 6):
            ws.cell(row=row, column=col).fill = fill(LIGHT_GOLD)
        sc = ws.cell(row=row, column=1, value=section["name"])
        sc.font = Font(name="Calibri", bold=True, size=11, color=NAVY)
        sc.alignment = Alignment(horizontal="left", vertical="center")
        ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=5)
        row += 1

        # Pre-conditions
        if section.get("preconditions"):
            ws.row_dimensions[row].height = 18
            for col in range(1, 6):
                ws.cell(row=row, column=col).fill = fill(LIGHT_BLUE)
            pc = ws.cell(row=row, column=1, value=f"Pre-conditions:  {section['preconditions']}")
            pc.font = Font(name="Calibri", italic=True, size=9, color="444444")
            pc.alignment = Alignment(horizontal="left", vertical="center")
            ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=5)
            row += 1

        # Column headers
        ws.row_dimensions[row].height = 18
        for col_i, col_name in enumerate(col_names, 1):
            c = ws.cell(row=row, column=col_i, value=col_name)
            c.fill = fill(NAVY)
            c.font = bold_font(9)
            c.alignment = center_align()
            c.border = border()
        row += 1

        # Test rows
        for i, (test_id, steps, expected, neg) in enumerate(section["rows"]):
            ws.row_dimensions[row].height = 52
            bg = WHITE if i % 2 == 0 else GREY_ROW

            vals = [test_id, steps, expected, neg, ""]
            for col_i, val in enumerate(vals, 1):
                c = ws.cell(row=row, column=col_i, value=val)
                c.fill = fill(bg)
                c.font = normal_font(9)
                c.alignment = wrap_align("left" if col_i > 1 else "center")
                c.border = border()

            # Result cell: light-green default
            rc = ws.cell(row=row, column=5)
            rc.fill = fill("F0FFF4")
            rc.alignment = center_align()
            row += 1

    return ws


# ══════════════════════════════════════════════════════════════════════════════
# MODULE DATA
# ══════════════════════════════════════════════════════════════════════════════

# ── Module 1: Authentication ──────────────────────────────────────────────────
add_module_sheet("01 AUTH", NAVY, [
    {
        "name": "1.1  Sign Up",
        "preconditions": "None — open in fresh browser session",
        "rows": [
            ("TC-AUTH-01", "Navigate to /signup. Enter valid email and password (8+ chars). Click Sign Up.",
             "Account created. Redirected to onboarding profile page.", ""),
            ("TC-AUTH-02", "Sign up with an email already registered.",
             "Error shown: 'Email already in use'. Form does not submit.", "Negative"),
            ("TC-AUTH-03", "Sign up with a password shorter than 8 characters.",
             "Inline validation error shown. Form does not submit.", "Negative"),
            ("TC-AUTH-04", "Sign up with invalid email format (e.g. abc@).",
             "Validation error shown. Form does not submit.", "Negative"),
            ("TC-AUTH-05", "Leave email or password blank. Click Sign Up.",
             "Required field errors shown per field. Form does not submit.", "Negative"),
            ("TC-AUTH-06", "Sign up via /signup?plan=starter URL.",
             "After onboarding, user directed to upgrade screen with Starter pre-selected.", ""),
        ]
    },
    {
        "name": "1.2  Login",
        "preconditions": "Registered account must exist",
        "rows": [
            ("TC-AUTH-07", "Enter valid email and password. Click Login.",
             "Redirected to /app/dashboard.", ""),
            ("TC-AUTH-08", "Enter valid email, wrong password.",
             "Error message shown. User stays on login page.", "Negative"),
            ("TC-AUTH-09", "Enter unregistered email.",
             "Error message shown.", "Negative"),
            ("TC-AUTH-10", "Leave both fields blank. Click Login.",
             "Validation errors shown.", "Negative"),
            ("TC-AUTH-11", "Login as a staff account (username-based).",
             "Redirected to dashboard. Only permitted sidebar sections visible.", ""),
            ("TC-AUTH-12", "Login as superadmin.",
             "Redirected to /superadmin. Main app is not accessible.", ""),
            ("TC-AUTH-13", "After logout, press browser Back button.",
             "Cannot navigate to authenticated pages. Redirected to landing/login.", "Security"),
        ]
    },
    {
        "name": "1.3  Onboarding — Profile Setup",
        "preconditions": "Newly registered account with no organisation",
        "rows": [
            ("TC-AUTH-14", "Complete profile form with company name and contact info. Click Continue.",
             "Organisation created. Redirected to Property Setup.", ""),
            ("TC-AUTH-15", "Leave company name (required) blank. Click Continue.",
             "Validation error. Cannot proceed.", "Negative"),
        ]
    },
    {
        "name": "1.4  Onboarding — Property Setup",
        "preconditions": "Organisation created, no property yet",
        "rows": [
            ("TC-AUTH-16", "Fill property name, select type. Click Create.",
             "Property created. Redirected to /app/dashboard.", ""),
            ("TC-AUTH-17", "Upload a logo (PNG/JPG under 2 MB).",
             "Logo shown in sidebar and property header.", ""),
            ("TC-AUTH-18", "Upload a non-image file as logo.",
             "Error shown. Upload rejected.", "Negative"),
            ("TC-AUTH-19", "Leave property name blank.",
             "Validation error. Cannot proceed.", "Negative"),
        ]
    },
    {
        "name": "1.5  Staff Invite & Accept",
        "preconditions": "Manager or Owner account logged in",
        "rows": [
            ("TC-AUTH-20", "Manager creates a staff account in Team Members. Copy the invite link.",
             "Staff account created. Invite link generated.", ""),
            ("TC-AUTH-21", "Open invite link /accept-invite?token=... in browser.",
             "Invite acceptance screen shown with property/role details.", ""),
            ("TC-AUTH-22", "Accept the invite.",
             "Staff account activated. Staff can log in.", ""),
            ("TC-AUTH-23", "Use an expired or invalid invite token.",
             "Error: 'Invalid or expired invite'.", "Negative"),
            ("TC-AUTH-24", "Try to accept an already-accepted invite.",
             "Error: 'Invite already used'.", "Negative"),
        ]
    },
])

# ── Module 2: Navigation ──────────────────────────────────────────────────────
add_module_sheet("02 NAVIGATION", "2C5F8A", [
    {
        "name": "2.1  Sidebar Navigation",
        "preconditions": "Logged in as Owner",
        "rows": [
            ("TC-NAV-01", "Click each menu item in the sidebar (Dashboard, Check-Ins, Rooms, etc.).",
             "Navigates to the correct screen. Active item is highlighted.", ""),
            ("TC-NAV-02", "Resize browser to mobile width (<768 px).",
             "Sidebar collapses. Hamburger/menu button appears.", ""),
            ("TC-NAV-03", "Click hamburger menu on mobile width.",
             "Sidebar drawer slides in over the content.", ""),
            ("TC-NAV-04", "Log in as Staff with only Restaurant permissions.",
             "Hotel section items (Rooms, Check-Ins, Reservations, etc.) hidden from sidebar.", ""),
            ("TC-NAV-05", "Click 'Add Property' in the sidebar.",
             "Redirected to /property-setup.", ""),
        ]
    },
    {
        "name": "2.2  Property Switcher",
        "preconditions": "Account with 2+ properties",
        "rows": [
            ("TC-NAV-06", "Click the property selector button at the top of the sidebar.",
             "Dropdown shows all available properties.", ""),
            ("TC-NAV-07", "Select a different property from the dropdown.",
             "All screen data refreshes to show the selected property's data.", ""),
            ("TC-NAV-08", "Click 'Manage Properties'.",
             "Dialog opens listing all properties with Edit and Delete options.", ""),
        ]
    },
    {
        "name": "2.3  Notification Bell",
        "preconditions": "At least one notification exists",
        "rows": [
            ("TC-NAV-09", "Click the bell icon in the top bar.",
             "Notification panel opens showing recent notifications.", ""),
            ("TC-NAV-10", "Click an unread notification.",
             "Notification marked as read. Unread badge count decreases.", ""),
            ("TC-NAV-11", "Click 'Mark all as read'.",
             "All notifications marked read. Badge disappears.", ""),
            ("TC-NAV-12", "Guest staying 3+ nights — check for housekeeping notification.",
             "Auto-notification appears: 'Housekeeping Required — Room X'.", ""),
        ]
    },
    {
        "name": "2.4  User Menu (Top Right)",
        "preconditions": "Logged in",
        "rows": [
            ("TC-NAV-13", "Click the user avatar/email in the top-right corner.",
             "Dropdown shows email, plan badge, Account Settings link, Logout.", ""),
            ("TC-NAV-14", "Click 'Account Settings' from the dropdown.",
             "Navigates to /app/account.", ""),
            ("TC-NAV-15", "Click 'Logout'.",
             "Session ended. Redirected to landing page. Back button cannot re-enter app.", ""),
        ]
    },
])

# ── Module 3: Hotel Management ────────────────────────────────────────────────
add_module_sheet("03 HOTEL", "1B4F72", [
    {
        "name": "3.1  Dashboard",
        "preconditions": "At least one booking or check-in must exist for non-zero metrics",
        "rows": [
            ("TC-HOT-01", "Navigate to /app/dashboard.",
             "Page loads. KPI cards show: Check-ins today, Occupancy %, Revenue today, Orders today.", ""),
            ("TC-HOT-02", "Verify currency symbol on all monetary KPI cards.",
             "Amounts display the hotel's configured currency symbol (e.g. LKR).", ""),
            ("TC-HOT-03", "Open dashboard with zero bookings/orders.",
             "KPIs show zero values. No crash or error.", "Edge Case"),
            ("TC-HOT-04", "Log in as Enterprise plan with outstanding payment.",
             "Subscription payment banner visible with amount due.", ""),
            ("TC-HOT-05", "Log in as Free/Starter/Pro plan.",
             "No subscription payment banner shown.", ""),
        ]
    },
    {
        "name": "3.2  Rooms",
        "preconditions": "Logged in as Owner or Manager",
        "rows": [
            ("TC-HOT-06", "Navigate to /app/rooms.",
             "Grid of all rooms displayed with status colour indicators.", ""),
            ("TC-HOT-07", "Click 'Add Room'. Fill room number, type, price, floor, capacity. Click Save.",
             "New room appears in the grid immediately.", ""),
            ("TC-HOT-08", "Click 'Edit' on an existing room. Change nightly rate. Save.",
             "Room shows updated rate.", ""),
            ("TC-HOT-09", "Set a room's status to 'Maintenance'. Set start and end dates.",
             "Room shown with maintenance indicator. Appears blocked in Reservations calendar.", ""),
            ("TC-HOT-10", "Set maintenance end date to a date before the start date.",
             "Validation error: end date must be after start date.", "Negative"),
            ("TC-HOT-11", "Filter rooms by 'Available'.",
             "Only available rooms shown.", ""),
            ("TC-HOT-12", "Filter rooms by 'Occupied'.",
             "Only occupied rooms shown.", ""),
            ("TC-HOT-13", "Filter rooms by 'Maintenance'.",
             "Only maintenance rooms shown.", ""),
            ("TC-HOT-14", "Delete an unoccupied room. Confirm.",
             "Room removed from grid.", ""),
            ("TC-HOT-15", "Attempt to add rooms beyond the plan limit (e.g. 31st room on Starter = 30 max).",
             "Upgrade dialog shown: 'Upgrade your plan to add more rooms'.", "Plan Limit"),
            ("TC-HOT-16", "Add a room with a negative price.",
             "Validation error. Room not created.", "Negative"),
            ("TC-HOT-17", "Add a room with no room number.",
             "Validation error. Room not created.", "Negative"),
            ("TC-HOT-18", "Click 'Generate QR' on a room.",
             "QR code displayed. It encodes the room service URL for that room.", ""),
        ]
    },
    {
        "name": "3.3  Reservations (Booking Calendar)",
        "preconditions": "At least 1 room must exist",
        "rows": [
            ("TC-HOT-19", "Navigate to /app/reservations.",
             "14-day Gantt calendar loads. Rooms on Y-axis, dates on X-axis.", ""),
            ("TC-HOT-20", "Click the forward navigation arrow.",
             "Calendar shifts forward by one day.", ""),
            ("TC-HOT-21", "Click 'Add Reservation'. Fill guest name, email, room, check-in/check-out. Save.",
             "Booking block appears on the calendar for the correct room and date range.", ""),
            ("TC-HOT-22", "Click an existing booking block.",
             "Detail panel slides in with full reservation info.", ""),
            ("TC-HOT-23", "Edit a booking — change the check-out date. Save.",
             "Booking block resizes to reflect new dates.", ""),
            ("TC-HOT-24", "Delete a booking. Confirm.",
             "Booking removed from the calendar.", ""),
            ("TC-HOT-25", "Filter bookings by source 'Booking.com'.",
             "Only Booking.com bookings shown.", ""),
            ("TC-HOT-26", "Click 'Print Folio' on a booking.",
             "Printable invoice generated with room charges and linked expenses.", ""),
            ("TC-HOT-27", "Try to create a booking for a room already booked on those exact dates.",
             "Error: 'Room not available for selected dates'.", "Negative"),
            ("TC-HOT-28", "Set check-out date before check-in date.",
             "Validation error: 'Check-out must be after check-in'.", "Negative"),
            ("TC-HOT-29", "Rooms in maintenance appear on the calendar.",
             "Maintenance blocks shown in a distinct colour/pattern. Cannot be booked.", ""),
        ]
    },
    {
        "name": "3.4  Check-Ins",
        "preconditions": "At least one pending booking must exist",
        "rows": [
            ("TC-HOT-30", "Navigate to /app/check-ins.",
             "List of current check-ins with guest name, room, check-in/check-out dates.", ""),
            ("TC-HOT-31", "Click 'Check In' on a pending booking.",
             "Status → Checked In. Room status → Occupied.", ""),
            ("TC-HOT-32", "Click 'Check Out' on an active check-in.",
             "Status → Checked Out. Room status → Available.", ""),
            ("TC-HOT-33", "Search for a guest by name.",
             "Filtered list shows only matching guests.", ""),
            ("TC-HOT-34", "Search by email.",
             "Filtered list shows matching guests.", ""),
            ("TC-HOT-35", "Expand a check-in row.",
             "Full guest details: ID type, ID number, nationality, special requests.", ""),
            ("TC-HOT-36", "Click 'Print Folio' for a checked-in guest.",
             "Invoice generated with room charges, expenses, and restaurant orders.", ""),
            ("TC-HOT-37", "Switch to 'Bookings' tab.",
             "All bookings (not just active check-ins) shown.", ""),
        ]
    },
    {
        "name": "3.5  Financials",
        "preconditions": "At least one confirmed booking with revenue",
        "rows": [
            ("TC-HOT-38", "Navigate to /app/financials.",
             "Default date range loads. Four KPI cards: Gross Revenue, Total Costs, Net Profit, Future Revenue.", ""),
            ("TC-HOT-39", "Verify: Net Profit = Gross Revenue − Total Costs.",
             "Net Profit value matches the calculation.", ""),
            ("TC-HOT-40", "Change date range to last 7 days.",
             "All metrics recalculate for the new 7-day range.", ""),
            ("TC-HOT-41", "Set a custom date range (e.g. Jan 1 – Jan 31).",
             "Metrics update for January only.", ""),
            ("TC-HOT-42", "Set end date before start date.",
             "Validation error or end date auto-corrected.", "Negative"),
            ("TC-HOT-43", "Filter by booking source 'Airbnb'.",
             "Revenue metrics show only Airbnb bookings.", ""),
            ("TC-HOT-44", "Scroll through the daily breakdown table.",
             "Each row shows: Date, Revenue, Bookings count, Expenses count, Net amount.", ""),
            ("TC-HOT-45", "Open financials with zero bookings in range.",
             "All KPIs show 0.00. No crash.", "Edge Case"),
        ]
    },
    {
        "name": "3.6  Expenses Management",
        "preconditions": "Logged in as Owner or Manager",
        "rows": [
            ("TC-HOT-46", "Navigate to /app/expenses.",
             "List of existing expenses displayed.", ""),
            ("TC-HOT-47", "Click 'Add Expense'. Fill description, amount, category, date. Save.",
             "Expense appears in list. Reflected in Financials as a cost.", ""),
            ("TC-HOT-48", "Add an expense linked to a specific room.",
             "Expense appears in that room's guest folio when printing.", ""),
            ("TC-HOT-49", "Mark an expense as 'Billable'.",
             "Expense flagged. Appears on guest invoice.", ""),
            ("TC-HOT-50", "Mark a billable expense as 'Paid'.",
             "Expense shows 'Paid' status.", ""),
            ("TC-HOT-51", "Edit an existing expense — change the amount.",
             "Updated amount shown in list and Financials.", ""),
            ("TC-HOT-52", "Delete an expense. Confirm.",
             "Expense removed from list and from Financials costs.", ""),
            ("TC-HOT-53", "Add an expense with amount = 0.",
             "Validation error: amount must be > 0.", "Negative"),
            ("TC-HOT-54", "Add an expense with no description.",
             "Validation error: description required.", "Negative"),
        ]
    },
])

# ── Module 4: Restaurant Management ──────────────────────────────────────────
add_module_sheet("04 RESTAURANT", "7B341E", [
    {
        "name": "4.1  POS (Point of Sale)",
        "preconditions": "Menu items and tables must be configured",
        "rows": [
            ("TC-RES-01", "Navigate to /app/pos. Menu categories and items load.",
             "POS screen shows menu items on the left, order panel on the right.", ""),
            ("TC-RES-02", "Select a table. Click menu items to add to the order.",
             "Order builds in the right panel. Line items, quantities, and total shown.", ""),
            ("TC-RES-03", "Click + to increase an item's quantity.",
             "Quantity increases. Line total and grand total recalculate.", ""),
            ("TC-RES-04", "Remove an item from the order.",
             "Item removed. Total recalculates.", ""),
            ("TC-RES-05", "Apply a percentage discount.",
             "Discount deducted from total. Discount line shown.", ""),
            ("TC-RES-06", "Select order type: Dine-In.",
             "Order tagged as Dine-In. Service charge applies if configured.", ""),
            ("TC-RES-07", "Select order type: Takeaway.",
             "Order tagged as Takeaway. No table required.", ""),
            ("TC-RES-08", "Select order type: Delivery.",
             "Delivery platform selector shown.", ""),
            ("TC-RES-09", "Place the order.",
             "Order sent to Kitchen. Status = Pending. Order appears on KDS.", ""),
            ("TC-RES-10", "Use split payment (cash + card).",
             "Split dialog shown. Both amounts entered. Totals must equal the bill.", ""),
            ("TC-RES-11", "Charge order to a guest room.",
             "Bill posted to the checked-in guest's folio.", ""),
            ("TC-RES-12", "Add item with zero stock.",
             "Item shown as greyed out / unavailable. Cannot be added.", ""),
            ("TC-RES-13", "Place order with zero items.",
             "Place Order button disabled or validation error shown.", "Negative"),
            ("TC-RES-14", "Apply discount greater than the order total.",
             "Validation error or discount capped.", "Negative"),
            ("TC-RES-15", "Split payment totals do not equal order total.",
             "Cannot confirm payment. Error shown.", "Negative"),
        ]
    },
    {
        "name": "4.2  Tables / Floor Plan",
        "preconditions": "Tables must be configured in Restaurant Management",
        "rows": [
            ("TC-RES-16", "Navigate to /app/tables.",
             "Floor plan renders with all tables colour-coded: empty (green), occupied (red/amber), reserved.", ""),
            ("TC-RES-17", "Click an empty table.",
             "Opens POS for that table.", ""),
            ("TC-RES-18", "Click an occupied table.",
             "Shows active orders for that table.", ""),
            ("TC-RES-19", "Place an order from POS for Table 1. Check Tables screen.",
             "Table 1 shows occupied status and order count badge — no page refresh needed.", "Real-Time"),
        ]
    },
    {
        "name": "4.3  Kitchen Display System (KDS)",
        "preconditions": "POS must be open in another tab to place test orders",
        "rows": [
            ("TC-RES-20", "Navigate to /app/kitchen.",
             "Kanban board shows columns: Pending | Preparing | Ready | Payment Due.", ""),
            ("TC-RES-21", "Place an order from POS.",
             "Order card appears in Pending column within 2–3 seconds (real-time).", "Real-Time"),
            ("TC-RES-22", "Move order to 'Preparing'.",
             "Order moves to Preparing column. Status updated in Orders screen.", ""),
            ("TC-RES-23", "Move order to 'Ready to Serve'.",
             "Order moves to Ready column.", ""),
            ("TC-RES-24", "Move order to 'Payment Due'.",
             "Order moves to Payment Due column.", ""),
            ("TC-RES-25", "Order card under 5 minutes old.",
             "Card header colour: green.", ""),
            ("TC-RES-26", "Order card 5–15 minutes old.",
             "Card header colour: yellow/amber.", ""),
            ("TC-RES-27", "Order card over 15 minutes old.",
             "Card header colour: red (overdue).", ""),
            ("TC-RES-28", "Toggle sound notifications ON. Place a new order from POS.",
             "Audio beep plays in the browser when the new order arrives.", ""),
            ("TC-RES-29", "Toggle sound notifications OFF. Place a new order.",
             "No audio plays.", ""),
        ]
    },
    {
        "name": "4.4  Restaurant Management — Menu",
        "preconditions": "Logged in as Owner or Manager",
        "rows": [
            ("TC-RES-30", "Navigate to Restaurant → Menu tab.",
             "All menu items listed with name, price, category, availability toggle.", ""),
            ("TC-RES-31", "Click 'Add Item'. Fill name, price, category, description. Save.",
             "Item appears in menu list and is immediately available in POS.", ""),
            ("TC-RES-32", "Upload an image for a menu item.",
             "Image shown on the item card and in POS/guest menu.", ""),
            ("TC-RES-33", "Toggle item availability OFF.",
             "Item shown as unavailable. Greyed out in POS and guest menu.", ""),
            ("TC-RES-34", "Edit a menu item's price. Save.",
             "Updated price in POS and guest menu.", ""),
            ("TC-RES-35", "Delete a menu item. Confirm.",
             "Item removed from all views (menu, POS, guest menu).", ""),
            ("TC-RES-36", "Add an item with price = 0.",
             "Validation error.", "Negative"),
        ]
    },
    {
        "name": "4.5  Ingredients & Inventory",
        "preconditions": "At least one menu item must exist",
        "rows": [
            ("TC-RES-37", "Navigate to Restaurant → Ingredients tab.",
             "List of ingredients with stock level, unit, and cost per unit.", ""),
            ("TC-RES-38", "Add ingredient with name, unit, cost, minimum stock level. Save.",
             "Ingredient appears in the list.", ""),
            ("TC-RES-39", "Adjust stock: Add 10 units.",
             "Stock level increases by 10.", ""),
            ("TC-RES-40", "Adjust stock: Remove 5 units.",
             "Stock level decreases by 5. Cannot go below zero.", ""),
            ("TC-RES-41", "Stock falls below minimum level.",
             "Ingredient highlighted with a low-stock warning indicator.", ""),
            ("TC-RES-42", "Serve an order containing an ingredient-linked menu item.",
             "Ingredient stock automatically deducts the recipe quantity.", ""),
            ("TC-RES-43", "Refund the served order.",
             "Ingredient stock automatically restores.", ""),
        ]
    },
    {
        "name": "4.6  Tables Configuration",
        "preconditions": "Logged in as Owner or Manager",
        "rows": [
            ("TC-RES-44", "Navigate to Restaurant → Tables tab.",
             "All configured tables listed with number, capacity, QR option.", ""),
            ("TC-RES-45", "Add a new table with number and capacity. Save.",
             "Table appears in list, floor plan, and POS table selector.", ""),
            ("TC-RES-46", "Generate QR code for a table.",
             "QR encodes /menu/:propertyId/:tableId. Scannable by a phone.", ""),
            ("TC-RES-47", "Delete a table. Confirm.",
             "Table removed from all views.", ""),
            ("TC-RES-48", "Attempt to add a table beyond the plan limit.",
             "Upgrade prompt shown.", "Plan Limit"),
        ]
    },
    {
        "name": "4.7  Tax & Charges Configuration",
        "preconditions": "Logged in as Owner or Manager",
        "rows": [
            ("TC-RES-49", "Navigate to Restaurant → Tax & Charges tab.",
             "Current tax % and service charge % displayed.", ""),
            ("TC-RES-50", "Update tax rate to 10%. Save. Place a new order.",
             "New order in POS shows 10% tax applied to subtotal.", ""),
            ("TC-RES-51", "Set service charge to apply on Dine-In only. Place Takeaway order.",
             "Takeaway order does not show service charge.", ""),
            ("TC-RES-52", "Enter a negative percentage.",
             "Validation error.", "Negative"),
        ]
    },
    {
        "name": "4.8  Orders",
        "preconditions": "At least some served orders must exist",
        "rows": [
            ("TC-RES-53", "Navigate to /app/orders.",
             "Order list shown with date, status, items, total.", ""),
            ("TC-RES-54", "Filter by 'Today'.",
             "Only today's orders shown.", ""),
            ("TC-RES-55", "Filter by status 'Served'.",
             "Only served (completed) orders shown.", ""),
            ("TC-RES-56", "Search by order number.",
             "Matching order highlighted.", ""),
            ("TC-RES-57", "Expand an order row.",
             "All items, quantities, prices, table, and status shown.", ""),
            ("TC-RES-58", "Initiate full refund on a served order.",
             "Refund recorded. Status shows 'Refunded'. Inventory restored.", ""),
            ("TC-RES-59", "Initiate partial refund (1 of 2 items). Select qty.",
             "Only that item refunded. Partial refund shown. Inventory partially restored.", ""),
            ("TC-RES-60", "Attempt to refund a cancelled order.",
             "Refund option not available for cancelled orders.", "Negative"),
        ]
    },
    {
        "name": "4.9  Restaurant Analytics",
        "preconditions": "At least some served orders must exist",
        "rows": [
            ("TC-RES-61", "Navigate to /app/analytics. Overview tab.",
             "6 KPI cards: Total Revenue, Orders, AOV, Cancellation Rate, Covers, Refunds.", ""),
            ("TC-RES-62", "Verify AOV calculation.",
             "AOV = Total Revenue ÷ Order Count.", ""),
            ("TC-RES-63", "Select 'Last 7 Days' time range.",
             "All charts and KPIs update for 7-day window.", ""),
            ("TC-RES-64", "Select custom date range.",
             "Data shown for specified range only.", ""),
            ("TC-RES-65", "View order type distribution pie chart.",
             "Dine-In / Takeaway / Delivery split shown. All percentages sum to 100%.", ""),
            ("TC-RES-66", "View top selling items.",
             "Ranked list of most-ordered items with count and revenue.", ""),
            ("TC-RES-67", "Switch to 'Service Charge' tab.",
             "Service charge breakdown shown by day.", ""),
            ("TC-RES-68", "Open analytics with zero orders in range.",
             "KPIs show 0. Charts show empty state. No crash.", "Edge Case"),
        ]
    },
    {
        "name": "4.10  Cancellations & Refunds",
        "preconditions": "At least one cancelled order or refunded item must exist",
        "rows": [
            ("TC-RES-69", "Navigate to /app/cancellations. View KPI summary row.",
             "Shows: Total Cancelled, Total Value, Inventory Restored, Total Refunded.", ""),
            ("TC-RES-70", "Review each cancelled order row.",
             "Shows order number, date, gross value, item count, inventory status.", ""),
            ("TC-RES-71", "Switch to 'Refunded Items' tab.",
             "Lists individual items with qty, refund amount, refund type, room charge reversal.", ""),
            ("TC-RES-72", "Verify refund amounts.",
             "Refund amount = unit price × refunded quantity.", ""),
        ]
    },
])

# ── Module 5: Team Management ─────────────────────────────────────────────────
add_module_sheet("05 TEAM", "145A32", [
    {
        "name": "5.1  Team Members",
        "preconditions": "Logged in as Owner or Manager",
        "rows": [
            ("TC-TEAM-01", "Navigate to /app/team.",
             "List of all staff with name, username, role badge, assigned properties.", ""),
            ("TC-TEAM-02", "Click 'Add Staff Member'. Fill username, password, first name, last name. Save.",
             "Staff account created. Invite link generated.", ""),
            ("TC-TEAM-03", "Try to create staff with a duplicate username.",
             "Error: 'Username already taken'.", "Negative"),
            ("TC-TEAM-04", "Click 'Edit Permissions'. Set Hotel = None.",
             "After staff login: Hotel menu items hidden from sidebar.", ""),
            ("TC-TEAM-05", "Set Restaurant = View.",
             "Staff can see restaurant screens but all edit/add/delete controls are hidden.", ""),
            ("TC-TEAM-06", "Set Financials = Edit.",
             "Staff has full CRUD access to financial data.", ""),
            ("TC-TEAM-07", "Click 'Reset Password'.",
             "New temporary password generated and displayed.", ""),
            ("TC-TEAM-08", "Delete a staff member. Confirm.",
             "Staff account deactivated. They can no longer log in.", ""),
            ("TC-TEAM-09", "Attempt to add staff beyond plan limit.",
             "Upgrade prompt shown.", "Plan Limit"),
        ]
    },
    {
        "name": "5.2  Staff Schedule",
        "preconditions": "At least one staff member must exist",
        "rows": [
            ("TC-TEAM-10", "Navigate to /app/shifts.",
             "Week view shown with current week's shifts.", ""),
            ("TC-TEAM-11", "Click forward/backward arrows.",
             "Calendar advances/retreats by one week.", ""),
            ("TC-TEAM-12", "Click 'Add Shift'. Select staff, date, start/end time. Save.",
             "Shift appears on the schedule calendar.", ""),
            ("TC-TEAM-13", "Try to add a shift with end time before start time.",
             "Validation error.", "Negative"),
            ("TC-TEAM-14", "Switch to 'Time Tracking' tab.",
             "Clock-in/clock-out records displayed.", ""),
            ("TC-TEAM-15", "Clock in a staff member.",
             "Clock-in time recorded. Running elapsed time shown.", ""),
            ("TC-TEAM-16", "Clock out the staff member.",
             "Clock-out time recorded. Duration calculated and displayed.", ""),
            ("TC-TEAM-17", "Try to clock in a staff member who is already clocked in.",
             "Error: 'Already clocked in'.", "Negative"),
        ]
    },
])

# ── Module 6: Account & Billing ───────────────────────────────────────────────
add_module_sheet("06 ACCOUNT & BILLING", "4A235A", [
    {
        "name": "6.1  Account Settings",
        "preconditions": "Logged in as Owner",
        "rows": [
            ("TC-ACC-01", "Navigate to /app/account.",
             "Current profile info shown: email, display name, org details.", ""),
            ("TC-ACC-02", "Update display name. Save.",
             "New name shown in the app header.", ""),
            ("TC-ACC-03", "Change password: enter current password + new password + confirm. Save.",
             "Password updated. May require re-login.", ""),
            ("TC-ACC-04", "Enter wrong current password.",
             "Error: 'Current password is incorrect'.", "Negative"),
            ("TC-ACC-05", "New password and confirm password do not match.",
             "Validation error.", "Negative"),
            ("TC-ACC-06", "Change currency to USD. Navigate to POS.",
             "All monetary values show $ symbol.", ""),
        ]
    },
    {
        "name": "6.2  Upgrade Plan (PayHere Billing)",
        "preconditions": "Logged in as Owner on Free plan. PayHere sandbox credentials set.",
        "rows": [
            ("TC-ACC-07", "Navigate to /app/upgrade.",
             "Upgrade screen shows Starter and Pro plan cards with prices.", ""),
            ("TC-ACC-08", "Select 'Starter' plan.",
             "Plan card selected/highlighted. Features list shown. Price shown.", ""),
            ("TC-ACC-09", "Toggle 'Annual (save 20%)'.",
             "Annual billing selected. Price shows 20% discount applied.", ""),
            ("TC-ACC-10", "Fill First Name, Last Name, Phone. Click 'Pay LKR 3,450'.",
             "PayHere sandbox checkout page opens.", ""),
            ("TC-ACC-11", "Complete sandbox payment with test card.",
             "Payment success. Redirected to /app/dashboard. Plan badge shows 'STARTER'.", ""),
            ("TC-ACC-12", "Click Cancel on PayHere checkout page.",
             "Redirected back to /app/upgrade. Plan unchanged.", ""),
            ("TC-ACC-13", "Leave First Name blank. Click Pay.",
             "Validation error. Payment not initiated.", "Negative"),
            ("TC-ACC-14", "On Pro plan, attempt to pay for Starter.",
             "Error: 'Cannot downgrade. Contact support.'", "Negative"),
        ]
    },
])

# ── Module 7: Guest Portal ────────────────────────────────────────────────────
add_module_sheet("07 GUEST PORTAL", "7B6000", [
    {
        "name": "7.1  Guest Self Check-In",
        "preconditions": "A booking must exist with a valid booking reference",
        "rows": [
            ("TC-GST-01", "Open /guest-registration?ref=BK-0001 in a browser (no login).",
             "Check-in page loads with the guest's booking details.", ""),
            ("TC-GST-02", "Fill guest details (name, ID type, ID number, nationality). Submit.",
             "Guest registered. Check-in status updated. Success screen shown.", ""),
            ("TC-GST-03", "Use an invalid booking reference.",
             "Error: 'Booking not found'.", "Negative"),
            ("TC-GST-04", "Use a reference already checked in.",
             "Message: 'You are already checked in'.", "Edge Case"),
            ("TC-GST-05", "Leave required fields blank. Click Submit.",
             "Per-field validation errors shown.", "Negative"),
            ("TC-GST-06", "Open check-in page on a mobile phone browser.",
             "Fully responsive. No login prompt. Usable on small screen.", "Mobile"),
        ]
    },
    {
        "name": "7.2  Guest Menu (QR Table Ordering)",
        "preconditions": "Menu items and tables configured. URL format: /menu/:propertyId/:tableId",
        "rows": [
            ("TC-GST-07", "Open guest menu URL in browser (no login).",
             "Menu loads with categories and items. Property name/logo shown.", ""),
            ("TC-GST-08", "Browse and select a menu category.",
             "Only items in that category shown.", ""),
            ("TC-GST-09", "Add items to cart. Adjust quantities.",
             "Cart updates. Subtotals recalculate correctly.", ""),
            ("TC-GST-10", "Remove an item from cart.",
             "Item removed. Total recalculates.", ""),
            ("TC-GST-11", "Confirm and place the order.",
             "Order sent to KDS. Confirmation message shown to guest.", ""),
            ("TC-GST-12", "Staff toggles an item to 'Unavailable'.",
             "Item shown as greyed out on guest menu. Cannot be added to cart.", ""),
            ("TC-GST-13", "Open guest menu on mobile phone.",
             "Fully responsive. Easy to navigate on small screen.", "Mobile"),
        ]
    },
    {
        "name": "7.3  Guest Room Service",
        "preconditions": "URL format: /room-service/:propertyId/:roomNumber",
        "rows": [
            ("TC-GST-14", "Open room service URL in browser (no login).",
             "Menu loads filtered for room service items. Room number shown.", ""),
            ("TC-GST-15", "Add items and place a room service order.",
             "Order sent to KDS with 'Room Service' tag and room number.", ""),
            ("TC-GST-16", "Order appears in KDS and Orders screen.",
             "Tagged as Room Service. Correct room number shown.", ""),
        ]
    },
])

# ── Module 8: Property Management ─────────────────────────────────────────────
add_module_sheet("08 PROPERTY MGMT", "2C3E50", [
    {
        "name": "8.1  Add / Edit Property",
        "preconditions": "Logged in as Owner",
        "rows": [
            ("TC-PROP-01", "Click 'Add Property' in the sidebar.",
             "Property setup screen opens.", ""),
            ("TC-PROP-02", "Fill property name, type, address, primary colour. Save.",
             "New property created. Appears in property switcher.", ""),
            ("TC-PROP-03", "Attempt to add a property beyond the plan limit.",
             "Upgrade prompt shown.", "Plan Limit"),
            ("TC-PROP-04", "Edit a property's name via 'Manage Properties'. Save.",
             "Updated name shown in sidebar and app header.", ""),
            ("TC-PROP-05", "Change a property's primary colour. Save.",
             "Sidebar accent colour updates to the new colour.", ""),
            ("TC-PROP-06", "Upload a new property logo.",
             "Logo displayed in sidebar header.", ""),
            ("TC-PROP-07", "Mark a property as Inactive.",
             "Property shows 'Inactive' warning banner inside the app.", ""),
        ]
    },
])

# ── Module 9: Superadmin ──────────────────────────────────────────────────────
add_module_sheet("09 SUPERADMIN", "6C0F0F", [
    {
        "name": "9.1  Superadmin Dashboard",
        "preconditions": "Logged in with superadmin credentials",
        "rows": [
            ("TC-SA-01", "Login as superadmin. Navigate to /superadmin.",
             "Dashboard shows total organisations, revenue metrics, and recent signups.", ""),
        ]
    },
    {
        "name": "9.2  Companies / Organisations",
        "preconditions": "At least one registered organisation",
        "rows": [
            ("TC-SA-02", "Click 'Companies' in superadmin menu.",
             "List of all registered organisations shown.", ""),
            ("TC-SA-03", "Click a company name.",
             "Detail screen: org name, owner email, current plan, properties, staff count.", ""),
            ("TC-SA-04", "Update org status to 'Suspended'.",
             "Organisation users cannot log in (or see suspended message).", ""),
            ("TC-SA-05", "Delete an organisation. Confirm.",
             "Organisation and all associated data removed.", ""),
        ]
    },
    {
        "name": "9.3  Enterprise Leads",
        "preconditions": "Superadmin logged in",
        "rows": [
            ("TC-SA-06", "Click 'Leads' in superadmin menu.",
             "List of enterprise enquiries shown.", ""),
            ("TC-SA-07", "Click 'Provision Access' on a lead whose account already exists.",
             "Enterprise plan applied. Organisation limits set per configuration.", ""),
            ("TC-SA-08", "Provision access for an email not yet registered.",
             "Invitation email sent. Status shows 'Invitation Sent'.", ""),
            ("TC-SA-09", "Invited user signs up via invite link and completes onboarding.",
             "Enterprise plan automatically applied. No manual superadmin action needed.", ""),
        ]
    },
    {
        "name": "9.4  Plans Management",
        "preconditions": "Superadmin logged in",
        "rows": [
            ("TC-SA-10", "Click 'Plans'. View all plans: Free, Starter, Pro, Enterprise.",
             "All four plans listed with prices, limits, and active status.", ""),
            ("TC-SA-11", "Edit the Starter plan monthly price. Save.",
             "New price shown on public landing page pricing section and upgrade screen.", ""),
            ("TC-SA-12", "Toggle a plan's 'is_active' to OFF.",
             "Plan disappears from public pricing page and upgrade screen.", ""),
            ("TC-SA-13", "Update a plan's max_rooms limit. Save.",
             "New limit enforced for new accounts on that plan.", ""),
        ]
    },
])

# ── Module 10: Landing Page ───────────────────────────────────────────────────
add_module_sheet("10 LANDING PAGE", "1A5276", [
    {
        "name": "10.1  Public Landing Page",
        "preconditions": "Not logged in. Browser in incognito mode.",
        "rows": [
            ("TC-LND-01", "Visit root URL / when not logged in.",
             "Landing page loads: hero, features, comparison table, pricing, testimonials.", ""),
            ("TC-LND-02", "Click 'Get Started' / 'Start Free' in hero section.",
             "Redirected to /signup.", ""),
            ("TC-LND-03", "Verify pricing section plan cards.",
             "Plans, prices, and feature lists fetched from DB. Correct prices shown.", ""),
            ("TC-LND-04", "Verify comparison table 'Starting price' row for HotRest.",
             "Shows the actual Starter plan price from DB (not a hardcoded stale value).", ""),
            ("TC-LND-05", "Click 'Upgrade' on Starter plan card.",
             "Redirected to /signup?plan=starter.", ""),
            ("TC-LND-06", "Click 'Contact Us' on Enterprise plan.",
             "Enterprise enquiry form/dialog opens.", ""),
            ("TC-LND-07", "Submit enterprise enquiry form.",
             "Lead saved in superadmin leads. Confirmation shown to user.", ""),
            ("TC-LND-08", "Visit / when already logged in.",
             "Auto-redirected to /app/dashboard.", ""),
            ("TC-LND-09", "Navigate to /terms, /privacy, /returns.",
             "Correct legal page content loads for each.", ""),
            ("TC-LND-10", "Navigate to /help.",
             "Help and documentation page loads.", ""),
        ]
    },
])

# ── Module 11: Mobile App ─────────────────────────────────────────────────────
add_module_sheet("11 MOBILE APP", "2C3E50", [
    {
        "name": "11.1  Booking Lookup",
        "preconditions": "A booking must exist with a known reference number",
        "rows": [
            ("TC-MOB-01", "Open the mobile app. Enter a valid booking reference. Tap Search.",
             "Booking details shown: guest name, room, dates, status.", ""),
            ("TC-MOB-02", "Enter an invalid booking reference.",
             "Error: 'No booking found with this reference'.", "Negative"),
            ("TC-MOB-03", "Leave the field blank. Tap Search.",
             "Validation error: field required.", "Negative"),
        ]
    },
    {
        "name": "11.2  Mobile Check-In Confirmation",
        "preconditions": "A pending booking must exist",
        "rows": [
            ("TC-MOB-04", "From lookup results, tap 'Check In'. Confirm.",
             "Guest status → Checked In. Room → Occupied.", ""),
            ("TC-MOB-05", "Try to check in a booking already checked in.",
             "Message: 'Guest is already checked in'.", "Negative"),
            ("TC-MOB-06", "Try to check in a cancelled booking.",
             "Error: 'Cannot check in a cancelled booking'.", "Negative"),
        ]
    },
])

# ── Module 12: Cross-Cutting ──────────────────────────────────────────────────
add_module_sheet("12 CROSS-CUTTING", "1A252F", [
    {
        "name": "12.1  Plan Limit Enforcement",
        "preconditions": "Account on Free or Starter plan",
        "rows": [
            ("TC-CC-01", "Attempt to add rooms beyond plan limit (Free=10, Starter=30, Pro=150).",
             "Upgrade dialog shown. Room not created.", "Plan Limit"),
            ("TC-CC-02", "Attempt to add staff beyond limit (Free=3, Starter=6, Pro=25).",
             "Upgrade dialog shown. Staff not created.", "Plan Limit"),
            ("TC-CC-03", "Attempt to add tables beyond limit (Free=5, Starter=15, Pro=30).",
             "Upgrade dialog shown. Table not created.", "Plan Limit"),
            ("TC-CC-04", "Attempt to add properties beyond limit (Free=1, Starter=2, Pro=5).",
             "Upgrade dialog shown. Property not created.", "Plan Limit"),
            ("TC-CC-05", "Upgrade plan. Immediately try to add item at the new higher limit.",
             "New limit enforced immediately. No app restart needed.", ""),
        ]
    },
    {
        "name": "12.2  Permission-Based Access",
        "preconditions": "Staff accounts with various permission levels configured",
        "rows": [
            ("TC-CC-06", "Log in as Staff with Hotel = None.",
             "Rooms, Check-Ins, Reservations, Financials, Expenses absent from sidebar.", ""),
            ("TC-CC-07", "Log in as Staff with Hotel = View.",
             "Sections visible. Add/Edit/Delete buttons hidden or disabled.", ""),
            ("TC-CC-08", "Log in as Staff with Hotel = Edit.",
             "Full CRUD access to hotel sections.", ""),
            ("TC-CC-09", "Log in as Staff with Restaurant = None.",
             "POS, Kitchen, Tables, Orders, Analytics absent from sidebar.", ""),
            ("TC-CC-10", "Log in as Manager.",
             "All sections accessible. No billing/plan settings visible.", ""),
            ("TC-CC-11", "Log in as Owner.",
             "All sections accessible including billing and property management.", ""),
        ]
    },
    {
        "name": "12.3  Multi-Property Data Isolation",
        "preconditions": "Account with 2+ properties",
        "rows": [
            ("TC-CC-12", "Switch to Property A. Add a room. Switch to Property B.",
             "Room added to A does not appear under Property B.", ""),
            ("TC-CC-13", "Create a reservation under Property A. Switch to Property B.",
             "Reservation not visible under Property B.", ""),
            ("TC-CC-14", "Staff assigned only to Property A — log in.",
             "Cannot see or access Property B's data.", ""),
        ]
    },
    {
        "name": "12.4  Real-Time Updates (Restaurant)",
        "preconditions": "POS open in Tab A. Kitchen open in Tab B.",
        "rows": [
            ("TC-CC-15", "Place order from POS (Tab A). Check Kitchen (Tab B).",
             "Order appears in KDS within 2–3 seconds. No page refresh needed.", "Real-Time"),
            ("TC-CC-16", "Move order to 'Ready' in Kitchen. Check Tables screen.",
             "Table status updates without page refresh.", "Real-Time"),
        ]
    },
    {
        "name": "12.5  Currency & Number Formatting",
        "preconditions": None,
        "rows": [
            ("TC-CC-17", "Set currency to LKR in Account Settings. Check POS, Financials, Expenses.",
             "All monetary values show 'LKR' symbol.", ""),
            ("TC-CC-18", "Set currency to USD. Check POS totals.",
             "All amounts show '$' symbol.", ""),
            ("TC-CC-19", "View a value above 1,000 (e.g. LKR 10,000.00).",
             "Comma thousands separator used. Two decimal places shown.", ""),
        ]
    },
])

# ── Save ──────────────────────────────────────────────────────────────────────
output_path = r"c:\Users\gphks\Documents\MyDoc\Proj\ideadeck\my_projects\proj_1\HotRest_QA_Test_Document.xlsx"
wb.save(output_path)
print(f"Saved: {output_path}")
