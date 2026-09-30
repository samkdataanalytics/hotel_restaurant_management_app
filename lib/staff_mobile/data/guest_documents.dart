import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads guest identity documents and signatures.
///
/// ## Where these go, and why it matters
///
/// The `guest-documents` bucket is PRIVATE, unlike `property-logos`. These are
/// photographed passports and national ID cards — a public bucket would expose
/// them to anyone who guessed a URL.
///
/// Object paths are `{hotel_id}/{check_in_id}/{kind}.{ext}`. The first segment
/// is the tenant key, which is what the bucket's RLS policies gate on via
/// `is_hotel_member()`, so a member of one property cannot read another's
/// documents even with a path.
///
/// ## Retention is not handled here
///
/// Nothing deletes these. A photographed passport kept indefinitely is a
/// liability under most privacy regimes, and how long to keep one is an
/// operator decision rather than something to hard-code. [deleteForCheckIn]
/// exists so a retention job has something to call.
class GuestDocuments {
  /// Overridden by subclasses that store into a different private bucket.
  String get bucketName => 'guest-documents';

  SupabaseClient get _db => Supabase.instance.client;

  /// What a stored file represents.
  static const kindId = 'id';
  static const kindSignature = 'signature';

  /// Uploads [bytes] and returns the object path to store on the check-in.
  ///
  /// Returns the path rather than a public URL: the bucket is private, so a
  /// URL would be meaningless without a signed token anyway, and paths survive
  /// the project being restored to a different domain.
  Future<String> upload({
    required String hotelId,
    required String checkInId,
    required String kind,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final path = '$hotelId/$checkInId/$kind.$extension';
    await _db.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            // Overwrite rather than fail: retaking a blurred ID photo during
            // the same check-in should just replace it.
            upsert: true,
          ),
        );
    return path;
  }

  /// A short-lived URL for viewing a stored document.
  ///
  /// Signed, and deliberately short: a link to someone's passport should not
  /// keep working after the screen showing it is closed.
  Future<String> signedUrl(String path, {Duration ttl = const Duration(minutes: 5)}) =>
      _db.storage.from(bucketName).createSignedUrl(path, ttl.inSeconds);

  /// Removes every document for one check-in. For a retention job to call.
  Future<void> deleteForCheckIn({
    required String hotelId,
    required String checkInId,
  }) async {
    try {
      final prefix = '$hotelId/$checkInId';
      final files = await _db.storage.from(bucketName).list(path: prefix);
      if (files.isEmpty) return;
      await _db.storage
          .from(bucketName)
          .remove(files.map((f) => '$prefix/${f.name}').toList());
    } catch (e) {
      debugPrint('GuestDocuments: cleanup for $checkInId failed: $e');
      rethrow;
    }
  }
}

final guestDocumentsProvider = Provider<GuestDocuments>(
  (ref) => GuestDocuments(),
);

/// Receipt photos attached to expenses.
///
/// Its own bucket rather than sharing `guest-documents`, because the two have
/// genuinely different lifetimes: a receipt wants keeping for the tax year, a
/// photographed passport wants deleting as soon as the stay is reconciled.
/// One bucket would force one retention policy onto both.
class ExpenseReceipts extends GuestDocuments {
  @override
  String get bucketName => 'expense-receipts';
}

final expenseReceiptsProvider = Provider<ExpenseReceipts>(
  (ref) => ExpenseReceipts(),
);
