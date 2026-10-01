import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/expense.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/guest_documents.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';
import '../frontdesk/document_capture.dart';
import '../../data/money.dart';

const _uuid = Uuid();

/// Log a purchase where it happens, with the receipt attached.
///
/// The point of the ticket is not the form — the web has one — it is the
/// camera. Carrying a fistful of till receipts back to the office is where they
/// get lost, so photographing one at the counter is the whole value.
class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.supplies;
  Uint8List? _receipt;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayAdd = session?.canEdit('hotel_expenses') ?? false;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Log an expense')),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!mayAdd)
            Container(
              width: double.infinity,
              color: scheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'View only — you cannot record expenses.',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  TextFormField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'What was it for',
                      hintText: 'e.g. vegetables from the market',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'A description is needed'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (v) {
                      final parsed = double.tryParse((v ?? '').trim());
                      if (parsed == null) return 'Enter an amount';
                      if (parsed <= 0) return 'Amount must be more than zero';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  Text('Category',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in ExpenseCategory.values)
                        ChoiceChip(
                          label: Text(_label(category)),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text('Receipt',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Optional, but it is the reason to do this at the counter '
                    'rather than back at the office.',
                    style:
                        TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _ReceiptTile(
                    preview: _receipt,
                    onCapture: _captureReceipt,
                    onClear: () => setState(() => _receipt = null),
                  ),

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: (!mayAdd || _saving) ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Saving' : 'Save expense'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _label(ExpenseCategory c) => switch (c) {
        ExpenseCategory.cleaning => 'Cleaning',
        ExpenseCategory.maintenance => 'Maintenance',
        ExpenseCategory.utilities => 'Utilities',
        ExpenseCategory.supplies => 'Supplies',
        ExpenseCategory.restaurant => 'Restaurant',
        ExpenseCategory.other => 'Other',
      };

  Future<void> _captureReceipt() async {
    try {
      final bytes = await captureIdPhoto(context);
      if (bytes != null && mounted) setState(() => _receipt = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Could not use the camera: $e'),
        ));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final isOnline = ref.read(isOnlineProvider);
    final hotelId =
        ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;

    final expense = Expense(
      id: _uuid.v4(),
      description: _description.text.trim(),
      amount: double.parse(_amount.text.trim()),
      category: _category,
      date: DateTime.now(),
    );

    try {
      await ref.read(bookingServiceProvider).addExpense(expense);

      // Uploaded after the expense is saved, and a failure does not undo it —
      // losing the amount because the photo would not upload would be worse
      // than an expense with no picture attached.
      if (_receipt != null && hotelId != null) {
        try {
          await ref.read(expenseReceiptsProvider).upload(
                hotelId: hotelId,
                checkInId: expense.id,
                kind: 'receipt',
                bytes: _receipt!,
              );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: const Text(
                  'Expense saved, but the receipt photo did not upload.',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ));
          }
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Logged ${ref.read(moneyProvider).format(expense.amount)}'),
        ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Saving the expense',
      );
    }
  }
}

class _ReceiptTile extends StatelessWidget {
  final Uint8List? preview;
  final VoidCallback onCapture;
  final VoidCallback onClear;

  const _ReceiptTile({
    required this.preview,
    required this.onCapture,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onCapture,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: preview != null
                    ? Image.memory(preview!, fit: BoxFit.cover)
                    : Icon(Icons.receipt_long_outlined,
                        color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  preview != null
                      ? 'Photo attached — tap to retake'
                      : 'Photograph the receipt',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: preview != null
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (preview != null)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
