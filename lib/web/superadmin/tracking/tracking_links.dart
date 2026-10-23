import 'package:flutter/material.dart';

import '../../../services/organization_service.dart';
import '../company_detail_screen.dart';
import '../users/user_detail_dialog.dart';
import 'property_detail_dialog.dart';

/// Opens the right dialog for a person, a company or a property, from anywhere in
/// the console. Every screen that mentions one of them links to it through these,
/// so a superadmin can follow any thread: company → property → person → what they did.

Future<void> openUser(BuildContext context, String userId) {
  if (userId.isEmpty) return Future.value();
  return showUserDetail(context, userId);
}

Future<void> openProperty(BuildContext context, String propertyId) {
  if (propertyId.isEmpty) return Future.value();
  return showPropertyDetail(context, propertyId);
}

Future<void> openCompany(BuildContext context, String orgId) async {
  if (orgId.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final org = await OrganizationService().getOrganization(orgId);
    if (org == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('That company no longer exists.')));
      return;
    }
    if (!context.mounted) return;
    await showDialog<bool>(context: context, builder: (_) => CompanyDetailScreen(org: org));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('Could not open the company: $e')));
  }
}
