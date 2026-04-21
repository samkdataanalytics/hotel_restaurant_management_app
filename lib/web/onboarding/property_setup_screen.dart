import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../providers/app_auth_provider.dart';
import '../../services/organization_service.dart';

// ─── Timezone constants ───────────────────────────────────────────────────────

const _timezones = [
  'UTC',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Toronto',
  'America/Sao_Paulo',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Moscow',
  'Asia/Dubai',
  'Asia/Kolkata',
  'Asia/Bangkok',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Australia/Sydney',
  'Pacific/Auckland',
];

// ─── Property type option ─────────────────────────────────────────────────────

class _PropertyTypeOption {
  final String value;
  final String label;
  final IconData icon;
  final String description;

  const _PropertyTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
  });
}

const _typeOptions = [
  _PropertyTypeOption(
    value: 'hotel',
    label: 'Hotel Only',
    icon: Icons.hotel_rounded,
    description: 'Manage rooms, check-ins, and reservations',
  ),
  _PropertyTypeOption(
    value: 'restaurant',
    label: 'Restaurant Only',
    icon: Icons.restaurant_rounded,
    description: 'Tables, orders, POS, and kitchen display',
  ),
  _PropertyTypeOption(
    value: 'both',
    label: 'Hotel + Restaurant',
    icon: Icons.business_rounded,
    description: 'Full property with both hotel and restaurant',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class PropertySetupScreen extends ConsumerStatefulWidget {
  final bool isFirstProperty;
  const PropertySetupScreen({super.key, this.isFirstProperty = false});

  @override
  ConsumerState<PropertySetupScreen> createState() => _PropertySetupScreenState();
}

class _PropertySetupScreenState extends ConsumerState<PropertySetupScreen> {
  // Step A
  String? _selectedType;

  // Step B
  final _formKey         = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController    = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController   = TextEditingController();
  final _emailController   = TextEditingController();
  String _selectedTimezone = 'UTC';
  String _selectedCurrency = 'USD';

  // Step C — booking channels (only for hotel/both)
  final Set<String> _selectedChannels = {'direct'};

  bool _isStepB = false;
  bool _isStepC = false;
  bool _isSubmitting = false;
  Uint8List? _logoBytes;
  String? _logoFileName;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _proceedToStepB() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property type to continue.')),
      );
      return;
    }
    setState(() => _isStepB = true);
  }

  void _proceedToStepC() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isStepC = true);
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _logoBytes = file.bytes;
      _logoFileName = file.name;
    });
  }

  Future<void> _submitProperty() async {
    // Form is only mounted on Step B — skip validation when called from Step C
    if (!_isStepC && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final authState = ref.read(authProvider).valueOrNull;
      final orgId = authState?.organization?.id ?? '';

      final newProperty = await OrganizationService().addProperty(
        orgId:           orgId,
        name:            _nameController.text.trim(),
        type:            _selectedType!,
        address:         _addressController.text.trim(),
        city:            _cityController.text.trim(),
        country:         _countryController.text.trim(),
        phone:           _phoneController.text.trim(),
        email:           _emailController.text.trim(),
        timezone:        _selectedTimezone,
        currency:        _selectedCurrency,
        bookingChannels: _selectedChannels.isEmpty ? ['direct'] : _selectedChannels.toList(),
      );

      // Upload logo if one was picked
      if (_logoBytes != null && _logoFileName != null) {
        final logoUrl = await OrganizationService().uploadPropertyLogo(
          newProperty.id, _logoBytes!, _logoFileName!,
        );
        await OrganizationService().updatePropertyLogo(newProperty.id, logoUrl);
      }

      // Persist as active property
      await OrganizationService().setActivePropertyId(newProperty.id);

      // Set in Riverpod
      ref.read(activePropertyProvider.notifier).setProperty(newProperty);

      // Refresh auth state so hasProperties becomes true
      await ref.read(authProvider.notifier).refreshAfterOnboarding();

      if (!mounted) return;
      context.go('/app/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create property: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // When on Step C, intercept back → go to Step B.
      // On Step B/A, allow normal browser back navigation.
      canPop: !_isStepC,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isStepC) {
          setState(() => _isStepC = false);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.sidebarDark,
                AppTheme.sidebarBg,
                const Color(0xFF1E3A5F),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/images/hotrest_logo.webp',
          width: 100,
          height: 100,
        ),
        const SizedBox(height: 8),
        Text(
          widget.isFirstProperty
              ? 'Welcome! Let\'s set up your first property.'
              : 'Add a New Property',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isStepC
              ? 'Which booking channels does this property use?'
              : _isStepB
                  ? 'Enter the property details below.'
                  : 'What type of property are you adding?',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(36),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: _isStepC
                ? _buildStepC(key: const ValueKey('stepC'))
                : _isStepB
                    ? _buildStepB(key: const ValueKey('stepB'))
                    : _buildStepA(key: const ValueKey('stepA')),
          ),
          if (_isSubmitting)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Creating your property...',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Step A: Property type selection ───────────────────────────────────────

  Widget _buildStepA({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Property Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.sidebarDark,
          ),
        ),
        const SizedBox(height: 20),
        ..._typeOptions.map((option) => _buildTypeCard(option)),
        const SizedBox(height: 28),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _proceedToStepB,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.adminPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard(_PropertyTypeOption option) {
    final isSelected = _selectedType == option.value;
    final Color accentColor = option.value == 'restaurant'
        ? AppTheme.restaurantAccent
        : option.value == 'both'
            ? AppTheme.goldPrimary
            : AppTheme.adminPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedType = option.value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: accentColor.withOpacity(0.12), blurRadius: 12)]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withOpacity(0.12) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.icon,
                  color: isSelected ? accentColor : AppTheme.adminTextMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? accentColor : AppTheme.sidebarDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.description,
                      style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: accentColor, size: 22)
              else
                const Icon(Icons.radio_button_unchecked_rounded,
                    color: Color(0xFFCBD5E1), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step B: Property details form ─────────────────────────────────────────

  Widget _buildStepB({Key? key}) {
    return Form(
      key: _formKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Property Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.sidebarDark,
            ),
          ),
          const SizedBox(height: 20),

          const _FieldLabel(text: 'Property Name *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. The Grand Hotel',
              prefixIcon: Icon(Icons.domain_rounded),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Property name is required' : null,
          ),
          const SizedBox(height: 16),

          const _FieldLabel(text: 'Address'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Street address',
              prefixIcon: Icon(Icons.location_on_rounded),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(text: 'City'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(hintText: 'City'),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(text: 'Country'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(hintText: 'Country'),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(text: 'Phone'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: '+1 800 000 0000',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(text: 'Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'property@example.com',
                        prefixIcon: Icon(Icons.email_rounded),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const _FieldLabel(text: 'Timezone'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedTimezone,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.adminPrimary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.schedule_rounded),
            ),
            items: _timezones
                .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                .toList(),
            onChanged: (v) => setState(() => _selectedTimezone = v ?? 'UTC'),
          ),
          const SizedBox(height: 16),

          const _FieldLabel(text: 'Currency'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedCurrency,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.adminPrimary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.attach_money_rounded),
            ),
            items: kCurrencies.map((c) => DropdownMenuItem(
              value: c.code,
              child: Text('${c.code}  –  ${c.name}  (${c.symbol})'),
            )).toList(),
            onChanged: (v) => setState(() => _selectedCurrency = v ?? 'USD'),
          ),
          const SizedBox(height: 20),

          // Logo picker
          const _FieldLabel(text: 'Property Logo  (optional)'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(
                  color: _logoBytes != null
                      ? AppTheme.adminPrimary.withOpacity(0.5)
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _logoBytes != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.memory(
                            _logoBytes!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          top: 6, right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _logoBytes = null;
                              _logoFileName = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            size: 28, color: Colors.grey.shade400),
                        const SizedBox(height: 6),
                        Text(
                          'Click to upload logo',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                        Text(
                          'PNG, JPG, WEBP — max 2 MB',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 28),

          // Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isStepB = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.adminTextMuted,
                      side: BorderSide(color: AppTheme.adminTextMuted.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Back', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    // Hotel/both → go to channel step; restaurant-only → submit directly
                    onPressed: _selectedType == 'restaurant' ? _submitProperty : _proceedToStepC,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.adminPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedType == 'restaurant' ? 'Create Property' : 'Continue',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _selectedType == 'restaurant' ? Icons.check_rounded : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step C: Booking channel selection ────────────────────────────────────

  Widget _buildStepC({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Booking Channels',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.sidebarDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select all channels your property accepts reservations from. You can change this later in settings.',
          style: TextStyle(fontSize: 13, color: AppTheme.adminTextMuted),
        ),
        const SizedBox(height: 24),
        ..._kChannels.map((ch) => _buildChannelCard(ch)),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isStepC = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.adminTextMuted,
                    side: BorderSide(color: AppTheme.adminTextMuted.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Back', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitProperty,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.adminPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Create Property', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.check_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChannelCard(_ChannelOption ch) {
    final isSelected = _selectedChannels.contains(ch.value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() {
          if (isSelected) {
            _selectedChannels.remove(ch.value);
          } else {
            _selectedChannels.add(ch.value);
          }
        }),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? ch.color.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? ch.color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: ch.color.withOpacity(0.12), blurRadius: 12)]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? ch.color.withOpacity(0.12) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(ch.icon, color: isSelected ? ch.color : AppTheme.adminTextMuted, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ch.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? ch.color : AppTheme.sidebarDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(ch.description, style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: isSelected ? ch.color : const Color(0xFFCBD5E1),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Channel option data ──────────────────────────────────────────────────────

class _ChannelOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _ChannelOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const _kChannels = [
  _ChannelOption(
    value: 'bookingCom',
    label: 'Booking.com',
    description: 'World\'s largest accommodation platform',
    icon: Icons.language_rounded,
    color: Color(0xFF003580),
  ),
  _ChannelOption(
    value: 'airbnb',
    label: 'Airbnb',
    description: 'Short-term rental and experience platform',
    icon: Icons.house_rounded,
    color: Color(0xFFFF5A5F),
  ),
  _ChannelOption(
    value: 'expedia',
    label: 'Expedia',
    description: 'Global travel & hotel booking platform',
    icon: Icons.flight_rounded,
    color: Color(0xFF00355F),
  ),
  _ChannelOption(
    value: 'direct',
    label: 'Direct / Walk-in',
    description: 'Reservations made directly with your property',
    icon: Icons.person_rounded,
    color: Color(0xFF16A34A),
  ),
  _ChannelOption(
    value: 'other',
    label: 'Other',
    description: 'Any other channel or travel agent',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF64748B),
  ),
];

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
    );
  }
}
