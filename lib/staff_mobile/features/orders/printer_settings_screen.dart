import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/receipt_builder.dart';
import '../../data/receipt_printer.dart';

/// Choose which paired printer this device prints to, and what paper it holds.
///
/// Per device, not per property: the printer is physically next to this phone,
/// and two staff on the same property may stand at different tills.
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState
    extends ConsumerState<PrinterSettingsScreen> {
  List<PrinterDevice>? _devices;
  String? _error;
  bool _loading = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await ref.read(receiptPrinterProvider).pairedPrinters();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.read(receiptPrinterProvider);
    final saved = printer.savedPrinter;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt printer'),
        actions: [
          IconButton(
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _scan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paper width',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final p in ReceiptPaper.values) ...[
                        ChoiceChip(
                          label: Text(p.label),
                          selected: printer.paper == p,
                          onSelected: (_) async {
                            await printer.savePaper(p);
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Paired printers',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pair the printer in your device Bluetooth settings first, then '
            'choose it here.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!,
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            )
          else if ((_devices ?? []).isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No paired Bluetooth printers found on this device.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final device in _devices!)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    saved?.address == device.address
                        ? Icons.print_rounded
                        : Icons.print_outlined,
                    color: saved?.address == device.address
                        ? scheme.primary
                        : null,
                  ),
                  title: Text(device.name),
                  subtitle: Text(device.address),
                  trailing: saved?.address == device.address
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : null,
                  onTap: () async {
                    await printer.savePrinter(device);
                    if (mounted) setState(() {});
                  },
                ),
              ),

          if (saved != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _testing ? null : _testPrint,
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.receipt_long_rounded),
              label: Text(_testing ? 'Printing' : 'Print a test receipt'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await printer.forgetPrinter();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Forget this printer'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    final printer = ref.read(receiptPrinterProvider);
    try {
      final builder = await ReceiptBuilder.create(paper: printer.paper);
      await printer.printBytes(builder.buildTestPage());
      if (!mounted) return;
      setState(() => _testing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Test receipt sent')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _testing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ));
    }
  }
}
