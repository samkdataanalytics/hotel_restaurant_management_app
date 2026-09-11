import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/invoice_service.dart';

/// Riverpod provider for [InvoiceService].
///
/// Deliberately kept OUT of `service_providers.dart`: `invoice_service.dart`
/// imports `dart:js_interop` and `package:web/web.dart`, which are web-only
/// libraries. Importing it from the shared provider file would drag those into
/// every consumer of that file — including the staff mobile app — and break the
/// native build at the compile stage.
///
/// Import this file directly from web screens that need invoices.
final invoiceServiceProvider =
    Provider<InvoiceService>((_) => InvoiceService());
