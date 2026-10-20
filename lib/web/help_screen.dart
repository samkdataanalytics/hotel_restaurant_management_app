import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ── Palette (matches landing page light theme) ─────────────────────────────────
class _C {
  static const bg      = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8FAFC);
  static const card    = Color(0xFFFFFFFF);
  static const border  = Color(0xFFE2E8F0);
  static const text    = Color(0xFF0F172A);
  static const sub     = Color(0xFF64748B);
  static const gold    = Color(0xFF0A7D77);

  static const hotel     = Color(0xFF3B82F6);
  static const restaurant= Color(0xFFF97316);
  static const guest     = Color(0xFFEC4899);
  static const finance   = Color(0xFF10B981);
  static const team      = Color(0xFF8B5CF6);
  static const settings  = Color(0xFF64748B);
}

// ── Data models ────────────────────────────────────────────────────────────────

class _Step {
  final String title;
  final String body;
  final String? tip;
  final String? note;
  const _Step(this.title, this.body, {this.tip, this.note});
}

class _Topic {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final String category;
  final Color catColor;
  final List<_Step> steps;
  const _Topic({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.catColor,
    required this.steps,
  });
  int get readMinutes => ((steps.length * 25) / 60).ceil().clamp(1, 10);
}

// ── All topics ─────────────────────────────────────────────────────────────────

const _kTopics = <_Topic>[
  _Topic(
    id: 'first-setup',
    emoji: '🚀',
    title: 'Setting Up for the First Time',
    subtitle: 'Create your account, add your property and get running',
    category: 'Hotel',
    catColor: _C.hotel,
    steps: [
      _Step('Create your account',
          'Sign up with your email. You\'ll land on the onboarding screen automatically.'),
      _Step('Fill in your property details',
          'Enter your hotel or restaurant name, pick the type (Hotel only, Restaurant only, or Both), and upload your logo.',
          tip: 'Your logo shows up on guest receipts and the QR portal pages — make it look good!'),
      _Step('Add your rooms',
          'Go to "Rooms" in the sidebar. Click "+ Add Room", enter a room number and type, set the price per night, and save.'),
      _Step('Add your menu (if you have a restaurant)',
          'Go to "Restaurant" in the sidebar. Click "+ Add Item" and fill in the name, category, and price.',
          note: 'Categories like Starters, Mains, Drinks create tabs on the guest menu automatically.'),
      _Step('You\'re live!',
          'That\'s it. Your property is ready. You can always add more rooms, menu items, or staff at any time.'),
    ],
  ),
  _Topic(
    id: 'add-room',
    emoji: '🛏️',
    title: 'Adding & Managing Rooms',
    subtitle: 'Add rooms, set prices, change status',
    category: 'Hotel',
    catColor: _C.hotel,
    steps: [
      _Step('Go to Rooms', 'Click "Rooms" in the left sidebar.'),
      _Step('Add a new room',
          'Click the "+ Add Room" button in the top-right corner.',
          tip: 'Room numbers don\'t have to be actual numbers — "Penthouse" or "Garden Suite" works too!'),
      _Step('Fill in the details',
          'Enter the room number, pick the type (Single, Double, Suite, etc.), set the price per night, and add a description if you like.'),
      _Step('Change room status',
          'Click the toggle next to any room to flip between Available, Occupied, and Unavailable.',
          note: 'Mark a room "Unavailable" when it\'s being cleaned or repaired so it won\'t be booked by mistake.'),
      _Step('Get the Room Service QR',
          'Click the QR code icon on a room card to get a printable QR code for room service ordering.'),
    ],
  ),
  _Topic(
    id: 'checkin',
    emoji: '🛎️',
    title: 'Checking In a Guest',
    subtitle: 'Find a booking and check a guest in',
    category: 'Hotel',
    catColor: _C.hotel,
    steps: [
      _Step('Go to Check-Ins', 'Click "Check-Ins" in the sidebar.'),
      _Step('Find the booking',
          'Search by guest name, phone number, or booking reference (e.g. BK-0042).'),
      _Step('Click Check In',
          'Hit the green "Check In" button on the booking card.',
          tip: 'The room status switches to "Occupied" automatically — no extra steps needed.'),
      _Step('Guest details are saved',
          'All guest information (name, ID, contact) is stored against the booking for your records.'),
      _Step('Check out',
          'When the guest leaves, come back to Check-Ins, find the booking, and click "Check Out". The room frees up instantly.'),
    ],
  ),
  _Topic(
    id: 'reservation',
    emoji: '📅',
    title: 'Making a Reservation',
    subtitle: 'Book a room for a future guest',
    category: 'Hotel',
    catColor: _C.hotel,
    steps: [
      _Step('Go to Reservations', 'Click "Reservations" in the sidebar.'),
      _Step('Click + New Reservation',
          'Hit the button in the top-right corner.'),
      _Step('Enter guest info',
          'Add the guest\'s name, phone number, and email.',
          tip: 'Phone number is the easiest way to search for a guest later.'),
      _Step('Pick dates and room',
          'Select the check-in date, check-out date, and which room to book. The system won\'t let you double-book.'),
      _Step('Save it',
          'Click Save — the booking is confirmed and the room is reserved for those dates.'),
      _Step('Share the self check-in QR',
          'Click the QR icon on the booking to send a self check-in link to the guest before they arrive.',
          note: 'The guest fills in their passport and details on their phone. Saves time at the front desk!'),
    ],
  ),
  _Topic(
    id: 'self-checkin',
    emoji: '📱',
    title: 'Guest Self Check-In QR',
    subtitle: 'Let guests fill in their own details',
    category: 'Guest Portal',
    catColor: _C.guest,
    steps: [
      _Step('Find the booking',
          'Open any booking in Check-Ins or Reservations.'),
      _Step('Open the QR code',
          'Click the QR code icon on the booking card.'),
      _Step('Share with the guest',
          'Print it, or copy the link and send it via WhatsApp or email.',
          tip: 'Put the QR in a confirmation email before the guest arrives — they arrive already checked in!'),
      _Step('Guest scans on their phone',
          'They see a friendly form to fill in their name, passport/NIC, and contact details.'),
      _Step('Info appears in your system',
          'As soon as they submit, their details save automatically to the booking. You don\'t have to type anything.'),
    ],
  ),
  _Topic(
    id: 'pos',
    emoji: '🍽️',
    title: 'Taking a Dine-In Order (POS)',
    subtitle: 'Open a table and place food orders',
    category: 'Restaurant',
    catColor: _C.restaurant,
    steps: [
      _Step('Go to POS', 'Click "POS" in the sidebar.'),
      _Step('Select a table',
          'Pick the table from the grid on the left side.',
          tip: 'For takeaway orders, select "Takeaway" at the top instead of a table.'),
      _Step('Add items',
          'Browse the menu on the right. Click any item to add it. Tap again to increase the quantity.'),
      _Step('Customise (optional)',
          'If an item has modifiers (like size or extras), a popup appears so the guest can choose.'),
      _Step('Place the order',
          'Click "Place Order" — the order goes to the kitchen screen immediately.'),
      _Step('Mark as paid',
          'When the guest is ready to pay, click "Pay". Choose cash or card and confirm.',
          note: 'You can split the bill across multiple people using the split bill option.'),
    ],
  ),
  _Topic(
    id: 'kitchen',
    emoji: '👨‍🍳',
    title: 'How the Kitchen Display Works',
    subtitle: 'Manage orders in the kitchen in real time',
    category: 'Restaurant',
    catColor: _C.restaurant,
    steps: [
      _Step('Open Kitchen on a screen in the kitchen',
          'Click "Kitchen" in the sidebar. Keep this open on a tablet or monitor.',
          note: 'The screen refreshes automatically. You don\'t need to keep pressing refresh.'),
      _Step('New orders appear as cards',
          'When a waiter places an order, a card pops up with all the items. Newest orders come in first.'),
      _Step('Click "Start" when you begin cooking',
          'This lets the front of house know the order is being prepared.'),
      _Step('Click "Ready" when the food is done',
          'The waiter gets a visual notification to pick up and deliver.'),
      _Step('Served orders disappear',
          'Once marked as served, the card clears. Your screen stays clean and focused.',
          tip: 'Use the filter at the top to show only specific order types (Room Service, Dine-In, Takeaway).'),
    ],
  ),
  _Topic(
    id: 'guest-menu',
    emoji: '📲',
    title: 'Table QR Menu (Guests Order Themselves)',
    subtitle: 'Put a QR on the table so guests can order from their phone',
    category: 'Guest Portal',
    catColor: _C.guest,
    steps: [
      _Step('Go to Restaurant → Tables tab',
          'In the sidebar click "Restaurant", then select the "Tables" tab at the top.'),
      _Step('Find your table and click the QR icon',
          'Each table has a small QR code button. Click it.'),
      _Step('Print or display the QR',
          'Download the QR image and print it on a card or stand for the table.',
          tip: 'Laminate it! Guests spill things.'),
      _Step('Guest scans and browses the menu',
          'They see your full menu on their phone with photos, descriptions, and prices.'),
      _Step('Guest places an order',
          'They tap items, choose options, and hit "Place Order". It arrives in your POS and Kitchen instantly.'),
      _Step('Track from POS',
          'You see the order in POS linked to that table. Process payment when they\'re done.',
          note: 'Guests can order multiple rounds — each new order is added as an add-on to the same table.'),
    ],
  ),
  _Topic(
    id: 'room-service',
    emoji: '🏨',
    title: 'Room Service QR',
    subtitle: 'Guests order food from their room',
    category: 'Guest Portal',
    catColor: _C.guest,
    steps: [
      _Step('Go to Rooms', 'Click "Rooms" in the sidebar.'),
      _Step('Find the room and click the QR icon',
          'Each room card has a QR code button. Click it.'),
      _Step('Print and place in the room',
          'Put it in a frame or on the desk in the room.',
          note: 'Each room has its own unique QR — scanning it automatically knows which room to deliver to.'),
      _Step('Guest orders from their phone',
          'They scan the QR, browse your menu, and tap to order.'),
      _Step('Order goes to the kitchen',
          'The kitchen screen shows it as a "Room Service" order with the room number.',
          tip: 'The guest can track their order status on their phone in real time!'),
    ],
  ),
  _Topic(
    id: 'menu-items',
    emoji: '🍕',
    title: 'Adding Menu Items & Modifiers',
    subtitle: 'Set up your food menu with sizes, extras, and options',
    category: 'Restaurant',
    catColor: _C.restaurant,
    steps: [
      _Step('Go to Restaurant', 'Click "Restaurant" in the sidebar.'),
      _Step('Click + Add Item',
          'Fill in the item name, category (Starters, Mains, Drinks, Desserts, etc.), price, and description.'),
      _Step('Toggle availability',
          'The on/off switch controls whether guests and staff can see and order this item.',
          tip: 'Sold out of something? Just toggle it off. Toggle back on when it\'s back.'),
      _Step('Add modifiers (optional)',
          'Modifiers are choices like "Size: Small / Large" or "Add extra cheese +100". Click "+ Add Modifier Group" to set them up.'),
      _Step('Set prices on modifiers',
          'Each modifier option can have a price adjustment. "Large +50" means the item costs 50 more when Large is selected.',
          note: 'Required modifiers force the guest to choose before adding to cart. Optional ones are just extra choices.'),
    ],
  ),
  _Topic(
    id: 'financials',
    emoji: '💰',
    title: 'Viewing Your Revenue',
    subtitle: 'Check income, invoices, and daily summaries',
    category: 'Finance',
    catColor: _C.finance,
    steps: [
      _Step('Go to Financials', 'Click "Financials" in the sidebar.'),
      _Step('See today\'s snapshot',
          'The top section shows check-ins today, total revenue, occupied rooms, and more.'),
      _Step('Change the date range',
          'Use the date picker to look at a specific week, month, or custom range.',
          tip: 'Compare this month vs last month to spot trends in your business.'),
      _Step('View individual invoices',
          'Scroll down to see each booking\'s invoice — room rate, extra charges, discounts, and total.'),
      _Step('Export as PDF',
          'Click the PDF icon on any invoice to download or print it for your records.',
          note: 'Invoices include your property logo and all the details needed for accounting.'),
    ],
  ),
  _Topic(
    id: 'expenses',
    emoji: '🧾',
    title: 'Recording Expenses',
    subtitle: 'Track what your property spends',
    category: 'Finance',
    catColor: _C.finance,
    steps: [
      _Step('Go to Expenses', 'Click "Expenses" in the sidebar.'),
      _Step('Click + Add Expense',
          'Pick a category (Maintenance, Utilities, Supplies, etc.), enter the amount and a short note.'),
      _Step('Save it',
          'The expense is logged with today\'s date.',
          tip: 'Add expenses as they happen — it\'s much easier than trying to remember them all at end of month!'),
      _Step('View expense history',
          'Filter by category or date range to see where your money is going.'),
      _Step('Room-level expenses',
          'For guest-specific charges (mini bar, laundry, damages), open the booking in Check-Ins and click "Add Expense" on the room.',
          note: 'Room expenses are added to the guest\'s invoice automatically.'),
    ],
  ),
  _Topic(
    id: 'analytics',
    emoji: '📊',
    title: 'Restaurant Analytics',
    subtitle: 'See what\'s selling and how much you\'re making',
    category: 'Finance',
    catColor: _C.finance,
    steps: [
      _Step('Go to Analytics', 'Click "Analytics" in the sidebar under Restaurant.'),
      _Step('See your headline numbers',
          'Total revenue, number of orders, average order value — all right at the top.'),
      _Step('Top-selling items',
          'A chart shows which menu items are most popular. Use this to decide what to promote or remove.',
          tip: 'Items that never sell are dead weight on your menu — consider removing them.'),
      _Step('Change the time scale',
          'Switch between Daily, Weekly, Monthly, or a custom date range.'),
      _Step('Order type breakdown',
          'See how much comes from Dine-In vs Takeaway vs Room Service.',
          note: 'If Room Service is high, your room service QR codes are working great!'),
    ],
  ),
  _Topic(
    id: 'team',
    emoji: '👥',
    title: 'Adding Staff Members',
    subtitle: 'Invite your team and control what they can see',
    category: 'Team',
    catColor: _C.team,
    steps: [
      _Step('Go to Team Members', 'Click "Team Members" in the sidebar.'),
      _Step('Click Invite Staff Member',
          'Enter their email address and choose a role.'),
      _Step('They get an email invite',
          'Your staff member receives a link to set up their password and join.',
          tip: 'Tell them to check spam if they don\'t see it within a minute.'),
      _Step('Set permissions',
          'After they join, click their name to edit exactly which screens they can access.'),
      _Step('They log in and see their view',
          'Staff only see the pages you gave them access to — everything else is hidden.',
          note: 'A cashier might see POS only. A chef might see Kitchen and Orders only. You decide.'),
    ],
  ),
  _Topic(
    id: 'roles',
    emoji: '🔑',
    title: 'Understanding Roles',
    subtitle: 'Owner, Manager, and Staff — what\'s the difference?',
    category: 'Team',
    catColor: _C.team,
    steps: [
      _Step('Owner',
          'Full access to everything. Can add and remove staff, create properties, and manage billing. That\'s you!'),
      _Step('Manager',
          'Full access to all day-to-day operations (check-ins, POS, kitchen, analytics). Cannot manage the team or billing.'),
      _Step('Staff',
          'Sees only the specific pages you allow. Great for cashiers, chefs, and front-desk staff.',
          tip: 'Give the kitchen staff access to Kitchen and Orders. Give cashiers access to POS only.'),
      _Step('Changing a role',
          'Go to Team Members, find the staff member, and edit their role or permissions at any time.'),
    ],
  ),
  _Topic(
    id: 'account',
    emoji: '⚙️',
    title: 'Account & Property Settings',
    subtitle: 'Update your logo, currency, tax rates, and more',
    category: 'Settings',
    catColor: _C.settings,
    steps: [
      _Step('Go to Account Settings',
          'Click your name or the settings icon at the top of the sidebar, or click "Account" in the menu.'),
      _Step('Update property info',
          'Change your hotel name, address, phone, and website.',
          note: 'Changes take effect immediately and appear on guest-facing pages.'),
      _Step('Upload a new logo',
          'Click the logo area and pick an image file. It\'s compressed automatically.',
          tip: 'A square logo (1:1) looks best on receipts and the guest portal.'),
      _Step('Set currency and tax',
          'Pick your currency symbol and enter your tax rate (as a %). This applies to all invoices and the guest menu.'),
      _Step('Service charge',
          'Enable a service charge percentage if you want to add it to restaurant bills automatically.'),
    ],
  ),
  _Topic(
    id: 'cancellations',
    emoji: '↩️',
    title: 'Cancellations & Refunds',
    subtitle: 'Cancel bookings and refund restaurant orders',
    category: 'Finance',
    catColor: _C.finance,
    steps: [
      _Step('Cancelling a hotel booking',
          'Open the booking in Check-Ins or Reservations and click the Cancel button. The room is freed up immediately.'),
      _Step('Refunding a restaurant order',
          'Go to "Cancellations" in the sidebar. Find the order.',
          tip: 'You can do partial refunds — just select which specific items to refund.'),
      _Step('Choose items to refund',
          'Tick each item and enter how many to refund. You don\'t have to refund the full order.'),
      _Step('Process the refund',
          'Click "Process Refund". The item quantities are reversed in the system.',
          note: 'Refunds are logged for your records but actual money movement happens outside the app — handle that separately with your payment processor.'),
    ],
  ),
  _Topic(
    id: 'tables-floor',
    emoji: '🗺️',
    title: 'Managing Your Restaurant Floor',
    subtitle: 'See live table statuses and manage the floor plan',
    category: 'Restaurant',
    catColor: _C.restaurant,
    steps: [
      _Step('Go to Tables', 'Click "Tables" in the sidebar under Restaurant.'),
      _Step('Read the colour codes',
          '🟢 Green = available, 🔴 Red = occupied, 🟡 Yellow = reserved.',
          note: 'Statuses update in real time as orders are placed and cleared.'),
      _Step('Click a table',
          'Opens a panel showing all active orders for that table.'),
      _Step('Create a table reservation',
          'Click the clock icon on a table to reserve it for a specific time slot.',
          tip: 'Reservations show as yellow so your staff knows not to seat new guests there.'),
      _Step('Add or edit tables',
          'Go to "Restaurant" → the Tables management tab → "+ Add Table" to grow your floor plan.'),
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class HelpScreen extends StatefulWidget {
  /// When true (public /help route) shows a slim top-bar with a back-to-home link.
  final bool standalone;
  const HelpScreen({super.key, this.standalone = false});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _categories = ['All', 'Hotel', 'Restaurant', 'Guest Portal', 'Finance', 'Team', 'Settings'];
  static const _placeholders = [
    'How do I check in a guest?',
    'How do I add a menu item?',
    'How does the kitchen display work?',
    'What are the QR codes for?',
    'How do I invite a staff member?',
    'How do I view my revenue?',
    'How do I set up room service?',
  ];

  String _query        = '';
  String _category     = 'All';
  String? _expandedId;
  int _placeholderIdx  = 0;
  final Set<String> _opened = {};
  final _searchCtrl    = TextEditingController();
  final _searchFocus   = FocusNode();
  final _keyboardFocus = FocusNode();
  late Timer _phTimer;

  @override
  void initState() {
    super.initState();
    _phTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _placeholderIdx = (_placeholderIdx + 1) % _placeholders.length);
    });
  }

  @override
  void dispose() {
    _phTimer.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  List<_Topic> get _filtered {
    return _kTopics.where((t) {
      final matchCat = _category == 'All' || t.category == _category;
      if (!matchCat) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          t.steps.any((s) => s.title.toLowerCase().contains(q) || s.body.toLowerCase().contains(q));
    }).toList();
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Hotel':       return _C.hotel;
      case 'Restaurant':  return _C.restaurant;
      case 'Guest Portal':return _C.guest;
      case 'Finance':     return _C.finance;
      case 'Team':        return _C.team;
      case 'Settings':    return _C.settings;
      default:            return _C.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.slash) {
          _searchFocus.requestFocus();
        }
      },
      child: Scaffold(
        backgroundColor: _C.surface,
        body: CustomScrollView(
          slivers: [
            if (widget.standalone) SliverToBoxAdapter(child: _buildStandaloneTopBar()),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildCategoryRow()),
            SliverToBoxAdapter(child: _buildResults()),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  // ── Standalone top bar (public /help route) ─────────────────────────────────

  Widget _buildStandaloneTopBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: _C.bg,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(children: [
        Image.asset('assets/images/hotrest_mark.png', width: 36, height: 36, fit: BoxFit.contain),
        const SizedBox(width: 10),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF0D9B94), _C.gold],
          ).createShader(bounds),
          child: const Text('HotRest',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded, size: 14, color: _C.sub),
          label: const Text('Back to home', style: TextStyle(color: _C.sub, fontSize: 13)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _C.gold),
            foregroundColor: _C.gold,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
        ),
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D9B94), Color(0xFF0A7D77)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF0A7D77).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('HotRest Guide',
                style: TextStyle(color: _C.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text('${_kTopics.length} topics · plain and simple',
                style: const TextStyle(color: _C.sub, fontSize: 13)),
          ]),
          const Spacer(),
          if (_opened.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.finance.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.finance.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🎯', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text('${_opened.length} / ${_kTopics.length} explored',
                    style: const TextStyle(color: _C.finance, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),

        const SizedBox(height: 24),

        // Search bar
        Container(
          decoration: BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            style: const TextStyle(color: _C.text, fontSize: 15),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: _placeholders[_placeholderIdx],
              hintStyle: const TextStyle(color: _C.sub, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _C.sub, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: _C.sub, size: 18),
                      onPressed: () => setState(() { _query = ''; _searchCtrl.clear(); }),
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _C.border),
                      ),
                      child: const Text('/', style: TextStyle(color: _C.sub, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Category chips ──────────────────────────────────────────────────────────

  Widget _buildCategoryRow() {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _categories.map((cat) {
          final selected = _category == cat;
          final color = cat == 'All' ? _C.gold : _catColor(cat);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: () => setState(() => _category = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.18) : _C.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color.withOpacity(0.6) : _C.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: selected ? color : _C.sub,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Results grid ────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final topics = _filtered;
    if (topics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text('No results for "$_query"',
                style: const TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Try different keywords or clear the search',
                style: TextStyle(color: _C.sub, fontSize: 13)),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: topics.map((t) => SizedBox(width: cardWidth, child: _TopicCard(
            topic: t,
            isExpanded: _expandedId == t.id,
            onTap: () => setState(() {
              _expandedId = _expandedId == t.id ? null : t.id;
              _opened.add(t.id);
            }),
          ))).toList(),
        );
      }),
    );
  }
}

// ── Topic card ─────────────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  final _Topic topic;
  final bool isExpanded;
  final VoidCallback onTap;
  const _TopicCard({required this.topic, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isExpanded ? _C.card : _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? topic.catColor.withOpacity(0.5) : _C.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [BoxShadow(color: topic.catColor.withOpacity(0.12), blurRadius: 20, spreadRadius: 2)]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  // Emoji in a bubble
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: topic.catColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: topic.catColor.withOpacity(0.2)),
                    ),
                    child: Center(child: Text(topic.emoji, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(topic.title,
                        style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(topic.subtitle,
                        style: const TextStyle(color: _C.sub, fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 8),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: topic.catColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(topic.category,
                          style: TextStyle(color: topic.catColor, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    // Read time
                    Text('~${topic.readMinutes} min',
                        style: const TextStyle(color: _C.sub, fontSize: 10)),
                  ]),
                ]),
              ),
            ),

            // Expand indicator bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              color: isExpanded ? topic.catColor.withOpacity(0.4) : Colors.transparent,
            ),

            // Expanded steps
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isExpanded ? _buildSteps() : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...topic.steps.asMap().entries.map((e) => _StepRow(
            step: e.value,
            index: e.key,
            total: topic.steps.length,
            accentColor: topic.catColor,
          )),
          const SizedBox(height: 8),
          // Footer
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 14, color: topic.catColor),
            const SizedBox(width: 6),
            Text('${topic.steps.length} steps · ${topic.category}',
                style: TextStyle(color: topic.catColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

// ── Step row ───────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final _Step step;
  final int index;
  final int total;
  final Color accentColor;
  const _StepRow({required this.step, required this.index, required this.total, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline column
        SizedBox(
          width: 28,
          child: Column(children: [
            const SizedBox(height: 4),
            // Number circle
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.4)),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
            // Connector line
            if (!isLast)
              Expanded(child: Container(
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: accentColor.withOpacity(0.15),
              )),
          ]),
        ),
        const SizedBox(width: 10),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 3),
              Text(step.title,
                  style: const TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(step.body,
                  style: const TextStyle(color: _C.sub, fontSize: 12, height: 1.55)),
              if (step.tip != null) ...[
                const SizedBox(height: 8),
                _InfoBox(text: step.tip!, isNote: false),
              ],
              if (step.note != null) ...[
                const SizedBox(height: 8),
                _InfoBox(text: step.note!, isNote: true),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Info box (tip / note) ──────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final String text;
  final bool isNote; // true = blue note, false = amber tip
  const _InfoBox({required this.text, required this.isNote});

  @override
  Widget build(BuildContext context) {
    final color = isNote ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24);
    final icon  = isNote ? Icons.info_outline_rounded : Icons.lightbulb_outline_rounded;
    final label = isNote ? 'Note' : 'Tip';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Expanded(child: RichText(
          text: TextSpan(
            children: [
              TextSpan(text: '$label: ',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
              TextSpan(text: text,
                  style: TextStyle(color: color.withOpacity(0.85), fontSize: 11, height: 1.5)),
            ],
          ),
        )),
      ]),
    );
  }
}
