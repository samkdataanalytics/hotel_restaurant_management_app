import 'package:flutter/material.dart';
import '../../app_theme.dart';

class Step2AdminProfile extends StatefulWidget {
  final void Function(Map<String, String> data) onComplete;
  final VoidCallback onBack;
  const Step2AdminProfile({super.key, required this.onComplete, required this.onBack});

  @override
  State<Step2AdminProfile> createState() => _Step2AdminProfileState();
}

class _Step2AdminProfileState extends State<Step2AdminProfile> {
  final _formKey       = GlobalKey<FormState>();
  final _nameController  = TextEditingController();
  final _titleController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onComplete({
        'fullName':  _nameController.text.trim(),
        'jobTitle':  _titleController.text.trim(),
        'phone':     _phoneController.text.trim(),
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
            'Admin Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.sidebarDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set up your administrator profile for this organization.',
            style: TextStyle(fontSize: 14, color: AppTheme.adminTextMuted),
          ),
          const SizedBox(height: 28),

          // Full name
          _FieldLabel(text: 'Full Name *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Jane Smith',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Full name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Job title
          _FieldLabel(text: 'Job Title'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'e.g. General Manager',
              prefixIcon: Icon(Icons.work_rounded),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // Phone
          _FieldLabel(text: 'Phone'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              hintText: 'e.g. +1 555 000 1234',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 32),

          // Buttons row
          Row(
            children: [
              // Back
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: widget.onBack,
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
              // Complete setup
              Expanded(
                flex: 2,
                child: SizedBox(
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
                        Text('Complete Setup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
    );
  }
}
