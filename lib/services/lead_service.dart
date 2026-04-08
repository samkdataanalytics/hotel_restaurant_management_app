import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

enum LeadStatus { newLead, contacted, converted, declined }

extension LeadStatusX on LeadStatus {
  String get value => switch (this) {
        LeadStatus.newLead   => 'new',
        LeadStatus.contacted => 'contacted',
        LeadStatus.converted => 'converted',
        LeadStatus.declined  => 'declined',
      };

  String get label => switch (this) {
        LeadStatus.newLead   => 'New',
        LeadStatus.contacted => 'Contacted',
        LeadStatus.converted => 'Converted',
        LeadStatus.declined  => 'Declined',
      };

  static LeadStatus fromValue(String v) => switch (v) {
        'contacted' => LeadStatus.contacted,
        'converted' => LeadStatus.converted,
        'declined'  => LeadStatus.declined,
        _           => LeadStatus.newLead,
      };
}

class EnterpriseLead {
  final String id;
  final String name;
  final String company;
  final String email;
  final String? phone;
  final int? propertyCount;
  final String? message;
  final LeadStatus status;
  final String? adminNotes;
  final DateTime createdAt;

  const EnterpriseLead({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    this.phone,
    this.propertyCount,
    this.message,
    required this.status,
    this.adminNotes,
    required this.createdAt,
  });

  factory EnterpriseLead.fromRow(Map<String, dynamic> r) => EnterpriseLead(
        id:            r['id'] as String,
        name:          r['name'] as String,
        company:       r['company'] as String,
        email:         r['email'] as String,
        phone:         r['phone'] as String?,
        propertyCount: r['property_count'] as int?,
        message:       r['message'] as String?,
        status:        LeadStatusX.fromValue(r['status'] as String? ?? 'new'),
        adminNotes:    r['admin_notes'] as String?,
        createdAt:     DateTime.parse(r['created_at'] as String),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class LeadService {
  final _db = Supabase.instance.client;

  /// Public — submit from landing page (no auth required).
  Future<void> submitLead({
    required String name,
    required String company,
    required String email,
    String? phone,
    int? propertyCount,
    String? message,
  }) async {
    await _db.from('enterprise_leads').insert({
      'name':           name,
      'company':        company,
      'email':          email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (propertyCount != null) 'property_count': propertyCount,
      if (message != null && message.isNotEmpty) 'message': message,
    });
  }

  /// Superadmin — fetch all leads newest first.
  Future<List<EnterpriseLead>> getAllLeads() async {
    final rows = await _db
        .from('enterprise_leads')
        .select()
        .order('created_at', ascending: false);
    return rows.map((r) => EnterpriseLead.fromRow(r)).toList();
  }

  /// Superadmin — update status and optional notes.
  Future<void> updateLead(String id, {required String status, String? adminNotes}) async {
    await _db.from('enterprise_leads').update({
      'status':      status,
      if (adminNotes != null) 'admin_notes': adminNotes,
      'updated_at':  DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
