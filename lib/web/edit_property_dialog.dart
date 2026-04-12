import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart' show hexToColor;
import '../services/organization_service.dart';

// ─── Preset brand colours ─────────────────────────────────────────────────────
const _kPresetColors = [
  '#D4A853', // Gold (default)
  '#2563EB', // Royal Blue
  '#059669', // Emerald Green
  '#7C3AED', // Deep Purple
  '#EF4444', // Red
  '#0891B2', // Cyan
  '#F97316', // Orange
  '#EC4899', // Pink
  '#64748B', // Slate
  '#10B981', // Green
  '#8B5CF6', // Violet
  '#1D4ED8', // Navy Blue
];

// ─── Timezones (shared with property_setup_screen) ────────────────────────────

const _kTimezones = [
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

/// Edit dialog for an existing property.
///
/// Shows the same fields as property setup Step B (name, address, city, country,
/// phone, email, timezone, currency, logo). Returns `true` via
/// `Navigator.pop(true)` when changes are saved successfully.
class EditPropertyDialog extends StatefulWidget {
  final OrgProperty property;

  const EditPropertyDialog({super.key, required this.property});

  @override
  State<EditPropertyDialog> createState() => _EditPropertyDialogState();
}

class _EditPropertyDialogState extends State<EditPropertyDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late String _timezone;
  late String _currency;

  Uint8List? _newLogoBytes;
  String? _newLogoFileName;
  bool _clearLogo = false;
  bool _saving = false;
  late String _primaryColor;   // hex e.g. '#D4A853'
  late final TextEditingController _hexCtrl;
  late List<String> _selectedChannels;

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    _nameCtrl    = TextEditingController(text: p.name);
    _addressCtrl = TextEditingController(text: p.address);
    _cityCtrl    = TextEditingController(text: p.city);
    _countryCtrl = TextEditingController(text: p.country);
    _phoneCtrl   = TextEditingController(text: p.phone);
    _emailCtrl   = TextEditingController(text: p.email);
    _timezone        = _kTimezones.contains(p.timezone) ? p.timezone : 'UTC';
    _currency        = kCurrencies.any((c) => c.code == p.currency) ? p.currency : 'USD';
    _primaryColor    = p.primaryColor.isNotEmpty ? p.primaryColor : '#D4A853';
    _hexCtrl         = TextEditingController(text: _primaryColor);
    _selectedChannels = List<String>.from(
      p.bookingChannels.isNotEmpty ? p.bookingChannels : ['direct'],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
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
      _newLogoBytes = file.bytes;
      _newLogoFileName = file.name;
      _clearLogo = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await OrganizationService().updateProperty(
        propertyId:      widget.property.id,
        name:            _nameCtrl.text.trim(),
        address:         _addressCtrl.text.trim(),
        city:            _cityCtrl.text.trim(),
        country:         _countryCtrl.text.trim(),
        phone:           _phoneCtrl.text.trim(),
        email:           _emailCtrl.text.trim(),
        timezone:        _timezone,
        currency:        _currency,
        primaryColor:    _primaryColor,
        bookingChannels: _selectedChannels,
      );

      if (_newLogoBytes != null && _newLogoFileName != null) {
        final logoUrl = await OrganizationService().uploadPropertyLogo(
          widget.property.id, _newLogoBytes!, _newLogoFileName!,
        );
        await OrganizationService().updatePropertyLogo(widget.property.id, logoUrl);
      } else if (_clearLogo) {
        await OrganizationService().updatePropertyLogo(widget.property.id, '');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─ Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 18),
                  const SizedBox(width: 10),
                  const Text('Edit Property',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.black45),
                  ),
                ],
              ),
            ),

            // ─ Body (scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _label('Property Name *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. The Grand Hotel',
                          prefixIcon: Icon(Icons.domain_rounded),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Property name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Address
                      _label('Address'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Street address',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // City + Country
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('City'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cityCtrl,
                                  decoration: const InputDecoration(hintText: 'City'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Country'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _countryCtrl,
                                  decoration: const InputDecoration(hintText: 'Country'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Phone + Email
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Phone'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  decoration: const InputDecoration(
                                    hintText: '+1 800 000 0000',
                                    prefixIcon: Icon(Icons.phone_rounded),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Email'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'property@example.com',
                                    prefixIcon: Icon(Icons.email_rounded),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Timezone
                      _label('Timezone'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _timezone,
                        decoration: _dropdownDec(Icons.schedule_rounded),
                        items: _kTimezones
                            .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                            .toList(),
                        onChanged: (v) => setState(() => _timezone = v ?? 'UTC'),
                      ),
                      const SizedBox(height: 14),

                      // Currency
                      _label('Currency'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: _dropdownDec(Icons.attach_money_rounded),
                        items: kCurrencies
                            .map((c) => DropdownMenuItem(
                                  value: c.code,
                                  child: Text('${c.code}  –  ${c.name}  (${c.symbol})'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                      ),
                      const SizedBox(height: 14),

                      // Brand colour
                      _label('Brand Colour'),
                      const SizedBox(height: 8),
                      _buildColorPicker(),
                      const SizedBox(height: 14),

                      // Booking Channels (hotel / both only)
                      if (widget.property.type != 'restaurant') ...[
                        const SizedBox(height: 4),
                        const Divider(),
                        const SizedBox(height: 4),
                        _label('Booking Channels'),
                        const SizedBox(height: 4),
                        Text(
                          'Select the channels through which guests can book this property.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 10),
                        _buildChannelPicker(),
                        const SizedBox(height: 4),
                      ],

                      // Logo
                      _label('Property Logo  (optional)'),
                      const SizedBox(height: 8),
                      _buildLogoPicker(),
                    ],
                  ),
                ),
              ),
            ),

            // ─ Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_saving ? 'Saving…' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.adminPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final currentColor = hexToColor(_primaryColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset swatches
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPresetColors.map((hex) {
            final selected = hex.toLowerCase() == _primaryColor.toLowerCase();
            final c = hexToColor(hex);
            return GestureDetector(
              onTap: () => setState(() {
                _primaryColor = hex;
                _hexCtrl.text = hex;
              }),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? const Color(0xFF1E293B) : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Custom hex input
        Row(
          children: [
            // Live preview swatch
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _hexCtrl,
                decoration: InputDecoration(
                  hintText: '#D4A853',
                  prefixText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _primaryColor)),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (v) {
                  if (v.length == 7 && v.startsWith('#')) {
                    setState(() => _primaryColor = v);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _kChannels = [
    {'key': 'bookingCom', 'label': 'Booking.com', 'icon': Icons.language_rounded},
    {'key': 'airbnb',     'label': 'Airbnb',       'icon': Icons.home_rounded},
    {'key': 'expedia',    'label': 'Expedia',       'icon': Icons.flight_rounded},
    {'key': 'direct',     'label': 'Direct',        'icon': Icons.phone_in_talk_rounded},
    {'key': 'other',      'label': 'Other',         'icon': Icons.more_horiz_rounded},
  ];

  Widget _buildChannelPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kChannels.map((ch) {
        final key = ch['key'] as String;
        final label = ch['label'] as String;
        final icon = ch['icon'] as IconData;
        final selected = _selectedChannels.contains(key);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                // Always keep at least one channel
                if (_selectedChannels.length > 1) {
                  _selectedChannels.remove(key);
                }
              } else {
                _selectedChannels.add(key);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.adminPrimary.withOpacity(0.08) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppTheme.adminPrimary : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16,
                    color: selected ? AppTheme.adminPrimary : Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppTheme.adminPrimary : Colors.grey.shade700,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.adminPrimary),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogoPicker() {
    final hasNew      = _newLogoBytes != null;
    final hasExisting = widget.property.logoUrl.isNotEmpty && !_clearLogo;
    final showImage   = hasNew || hasExisting;

    return GestureDetector(
      onTap: _pickLogo,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(
            color: showImage
                ? AppTheme.adminPrimary.withOpacity(0.4)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: showImage
            ? Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: hasNew
                        ? Image.memory(
                            _newLogoBytes!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            widget.property.logoUrl,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image_rounded,
                              size: 32,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                  // Clear button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        if (_newLogoBytes != null) {
                          setState(() {
                            _newLogoBytes = null;
                            _newLogoFileName = null;
                          });
                        } else {
                          setState(() => _clearLogo = true);
                        }
                      },
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
                  // "Click to replace" hint
                  Positioned(
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Click to replace',
                        style: TextStyle(fontSize: 10, color: Colors.white),
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
                  Text('Click to upload logo',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  Text('PNG, JPG, WEBP — max 2 MB',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
      );

  InputDecoration _dropdownDec(IconData icon) => InputDecoration(
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
        prefixIcon: Icon(icon),
      );
}
