import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../../services/organization_service.dart'
    show kCountries, validateCompanyEmail, validateCompanyPhone;

class Step1CompanyDetails extends StatefulWidget {
  final void Function(Map<String, String> data) onNext;
  const Step1CompanyDetails({super.key, required this.onNext});

  @override
  State<Step1CompanyDetails> createState() => _Step1CompanyDetailsState();
}

class _Step1CompanyDetailsState extends State<Step1CompanyDetails> {
  final _formKey = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _slugController    = TextEditingController();
  final _phoneController   = TextEditingController();
  final _emailController   = TextEditingController();

  /// ISO 3166-1 alpha-2 of the selected country. Null until the user picks one,
  /// which is what makes the dropdown a required field.
  String? _countryCode;

  bool _slugEdited = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);

    // Most owners we serve are small independents with no company domain —
    // their sign-in address IS their business address. Pre-fill it so the
    // common case is zero typing, while still leaving the field editable for
    // anyone who bills to a separate account. Null for username-based logins.
    _emailController.text =
        Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  void _onNameChanged() {
    if (!_slugEdited) {
      final generated = _nameController.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      _slugController.text = generated;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _slugController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final country = kCountries.firstWhere((c) => c.code == _countryCode);
      widget.onNext({
        'name':        _nameController.text.trim(),
        'slug':        _slugController.text.trim(),
        'country':     country.name,
        'countryCode': country.code,
        'phone':       _phoneController.text.trim(),
        'email':       _emailController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Company Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.sidebarDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us about your organization. You can update this later.',
            style: TextStyle(fontSize: 14, color: AppTheme.adminTextMuted),
          ),
          const SizedBox(height: 28),

          // Company name
          const _FieldLabel(text: 'Company Name *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Grand Hospitality Group',
              prefixIcon: Icon(Icons.business_rounded),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Company name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Slug
          const _FieldLabel(text: 'Company Slug'),
          const SizedBox(height: 4),
          Text(
            'URL-friendly identifier. Auto-generated from name.',
            style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _slugController,
            decoration: const InputDecoration(
              hintText: 'e.g. grand-hospitality-group',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _slugEdited = true,
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                final clean = RegExp(r'^[a-z0-9\-]+$');
                if (!clean.hasMatch(v)) {
                  return 'Only lowercase letters, numbers, and hyphens allowed';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Country — a fixed list rather than free text, so the stored value
          // is always a valid ISO code and spellings cannot drift.
          const _FieldLabel(text: 'Country *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: const Key('onboarding_country'),
            initialValue: _countryCode,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Select a country',
              prefixIcon: Icon(Icons.flag_rounded),
            ),
            items: [
              for (final c in kCountries)
                DropdownMenuItem(value: c.code, child: Text(c.name)),
            ],
            // The field keeps its own display state; this mirror is what
            // _submit() reads, so no rebuild is needed here.
            onChanged: (v) => _countryCode = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please select a country' : null,
          ),
          const SizedBox(height: 18),

          // Phone
          const _FieldLabel(text: 'Phone *'),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('onboarding_phone'),
            controller: _phoneController,
            decoration: const InputDecoration(
              hintText: 'e.g. +94 77 165 3296',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: validateCompanyPhone,
          ),
          const SizedBox(height: 18),

          // Contact email — where invoices and account notices go. Stored on the
          // organization so it survives an owner leaving. Pre-filled from the
          // sign-in address; a personal address is perfectly valid here.
          const _FieldLabel(text: 'Contact Email *'),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('onboarding_email'),
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'e.g. yourname@gmail.com',
              helperText: 'For invoices and account notices. '
                  'A personal address is fine.',
              prefixIcon: Icon(Icons.email_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: validateCompanyEmail,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 32),

          // Next button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
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
                  Text('Next', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
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
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
    );
  }
}
