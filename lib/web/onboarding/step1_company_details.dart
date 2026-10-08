import 'package:flutter/material.dart';
import '../../app_theme.dart';

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
  final _countryController = TextEditingController();
  final _phoneController   = TextEditingController();

  bool _slugEdited = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
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
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onNext({
        'name':    _nameController.text.trim(),
        'slug':    _slugController.text.trim(),
        'country': _countryController.text.trim(),
        'phone':   _phoneController.text.trim(),
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

          // Country
          const _FieldLabel(text: 'Country'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _countryController,
            decoration: const InputDecoration(
              hintText: 'e.g. United States',
              prefixIcon: Icon(Icons.flag_rounded),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Phone
          const _FieldLabel(text: 'Phone'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              hintText: 'e.g. +1 800 123 4567',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 32),

          // Next button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandOnDark,
                foregroundColor: AppTheme.onBrandOnDark,
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
