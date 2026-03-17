import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/booking.dart';
import '../models/guest.dart';

class GuestResponsesDialog extends StatelessWidget {
  final Booking booking;
  final Guest guest;

  const GuestResponsesDialog({
    super.key,
    required this.booking,
    required this.guest,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.adminPrimary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guest Registration Responses',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Booking Ref: ${booking.bookingRef} | Guest: ${guest.fullName}',
                          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Profile Information', Icons.person_rounded),
                    const SizedBox(height: 16),
                    _buildInfoRow('Full Name', guest.fullName),
                    _buildInfoRow('Passport / NIC', guest.passportOrNic ?? guest.idNumber),
                    _buildInfoRow('Nationality', guest.nationality.isNotEmpty ? guest.nationality : '-'),
                    _buildInfoRow('Date of Birth', guest.dateOfBirth != null ? dateFormatter.format(guest.dateOfBirth!) : '-'),
                    _buildInfoRow('WhatsApp / Phone', guest.whatsApp ?? guest.phone),
                    _buildInfoRow('Email', guest.email.isNotEmpty ? guest.email : '-'),
                    
                    const SizedBox(height: 32),
                    
                    _buildSectionHeader('Guest Preferences (\x61dditional Services)', Icons.room_preferences_rounded),
                    const SizedBox(height: 16),
                    if (booking.guestPreferences == null || booking.guestPreferences!.isEmpty)
                      const Text('No preferences provided.', style: TextStyle(color: Colors.black54))
                    else
                      ...booking.guestPreferences!.entries.map((e) {
                        return _buildInfoRow(_formatCamelCaseToTitle(e.key), e.value.toString());
                      }).toList(),
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.adminPrimary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.adminPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCamelCaseToTitle(String text) {
    if (text.isEmpty) return text;
    final result = text.replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}');
    return result[0].toUpperCase() + result.substring(1);
  }
}
