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

  bool _isStepB = false;
  bool _isSubmitting = false;

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

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authState = ref.read(authProvider).valueOrNull;
      final orgId = authState?.organization?.id ?? '';

      final newProperty = await OrganizationService().addProperty(
        orgId:    orgId,
        name:     _nameController.text.trim(),
        type:     _selectedType!,
        address:  _addressController.text.trim(),
        city:     _cityController.text.trim(),
        country:  _countryController.text.trim(),
        phone:    _phoneController.text.trim(),
        email:    _emailController.text.trim(),
        timezone: _selectedTimezone,
        currency: _selectedCurrency,
      );

      // Persist as active property
      await OrganizationService().setActivePropertyId(newProperty.id);

      // Set in Riverpod
      ref.read(activePropertyProvider.notifier).setProperty(newProperty);

      // Refresh auth state so hasProperties becomes true
      await ref.read(authProvider.notifier).refreshAfterOnboarding();

      if (!mounted) return;
      context.go('/app');
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
    return Scaffold(
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
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4A853), Color(0xFFE8C97A)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.goldPrimary.withOpacity(0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.domain_add_rounded, color: Color(0xFF0F172A), size: 28),
        ),
        const SizedBox(height: 16),
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
          _isStepB
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
            child: _isStepB
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
                Icon(Icons.radio_button_unchecked_rounded,
                    color: const Color(0xFFCBD5E1), size: 22),
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

          _FieldLabel(text: 'Property Name *'),
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

          _FieldLabel(text: 'Address'),
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
                    _FieldLabel(text: 'City'),
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
                    _FieldLabel(text: 'Country'),
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
                    _FieldLabel(text: 'Phone'),
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
                    _FieldLabel(text: 'Email'),
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

          _FieldLabel(text: 'Timezone'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedTimezone,
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

          _FieldLabel(text: 'Currency'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedCurrency,
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
          const SizedBox(height: 32),

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
                    onPressed: _submitProperty,
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
      ),
    );
  }
}

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
