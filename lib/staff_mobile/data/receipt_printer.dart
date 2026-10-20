import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'local_store.dart';
import 'receipt_builder.dart';

/// A paired thermal printer.
class PrinterDevice {
  final String name;

  /// MAC address on Android, or the platform's device identifier.
  final String address;

  const PrinterDevice({required this.name, required this.address});

  Map<String, dynamic> toMap() => {'name': name, 'address': address};

  factory PrinterDevice.fromMap(Map<String, dynamic> m) => PrinterDevice(
        name: m['name'] as String? ?? 'Printer',
        address: m['address'] as String? ?? '',
      );
}

/// What went wrong, in terms a person on the floor can act on.
class PrintFailure implements Exception {
  final String message;
  const PrintFailure(this.message);
  @override
  String toString() => message;
}

/// Prints receipts over Bluetooth to an ESC/POS thermal printer.
///
/// ## Not verified against hardware
///
/// Everything below the receipt layout is written against the ESC/POS standard
/// and the plugin's API, but it has never run against a real printer — there
/// was none to test with, and the iOS simulator has no Bluetooth stack at all.
/// Treat the transport as unproven until someone pairs an actual device.
///
/// ## Which printers
///
/// The roadmap left "which receipt printers must be supported?" open, and the
/// answer changes the size of this problem: named models make it small, "any
/// printer the customer already owns" makes it an open-ended compatibility
/// exercise. This targets generic ESC/POS over Bluetooth Classic (SPP), which
/// is what the common no-name 58mm and 80mm units speak. It will not drive a
/// Star or Epson printer in its native mode, nor anything BLE-only.
///
/// iOS is a further caveat: Bluetooth Classic requires the printer to be MFi
/// certified, which the cheap units are not. In practice this is an Android
/// feature until a specific iOS-compatible model is chosen.
class ReceiptPrinter {
  static const _savedPrinterKey = 'hotrest_staff_printer';
  static const _paperKey = 'hotrest_staff_printer_paper';

  final LocalStore _store;
  const ReceiptPrinter(this._store);

  /// The printer this device prints to, if one has been chosen.
  PrinterDevice? get savedPrinter {
    final raw = _store.readCache('device', _savedPrinterKey)?.value;
    if (raw is! Map) return null;
    final device = PrinterDevice.fromMap(Map<String, dynamic>.from(raw));
    return device.address.isEmpty ? null : device;
  }

  ReceiptPaper get paper {
    final raw = _store.readCache('device', _paperKey)?.value;
    return raw == ReceiptPaper.mm58.name ? ReceiptPaper.mm58 : ReceiptPaper.mm80;
  }

  Future<void> savePaper(ReceiptPaper value) =>
      _store.writeCache('device', _paperKey, value.name);

  Future<void> savePrinter(PrinterDevice device) =>
      _store.writeCache('device', _savedPrinterKey, device.toMap());

  Future<void> forgetPrinter() =>
      _store.writeCache('device', _savedPrinterKey, <String, dynamic>{});

  /// Printers already paired at the OS level.
  ///
  /// Pairing itself is deliberately left to the system settings rather than
  /// reimplemented here — it needs a PIN prompt and platform UI that a Flutter
  /// plugin reproduces badly.
  Future<List<PrinterDevice>> pairedPrinters() async {
    try {
      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        throw const PrintFailure(
          'Bluetooth is off. Turn it on, then try again.',
        );
      }
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices
          .map((d) => PrinterDevice(name: d.name, address: d.macAdress))
          .toList();
    } on PrintFailure {
      rethrow;
    } catch (e) {
      debugPrint('ReceiptPrinter: listing paired devices failed: $e');
      throw const PrintFailure(
        'Could not read paired Bluetooth devices. Check that Bluetooth '
        'permission is granted for this app.',
      );
    }
  }

  /// Sends [bytes] to the saved printer.
  ///
  /// Connects, writes, and disconnects each time rather than holding the link
  /// open: a phone that walks out of range with a live connection leaves the
  /// printer unusable for the next person until it times out.
  Future<void> printBytes(List<int> bytes) async {
    final printer = savedPrinter;
    if (printer == null) {
      throw const PrintFailure(
        'No printer chosen on this device yet.',
      );
    }

    try {
      final connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        final ok = await PrintBluetoothThermal.connect(
          macPrinterAddress: printer.address,
        );
        if (!ok) {
          throw PrintFailure(
            'Could not connect to ${printer.name}. Check it is on, has paper, '
            'and is in range.',
          );
        }
      }

      final written = await PrintBluetoothThermal.writeBytes(bytes);
      if (!written) {
        throw PrintFailure(
          'Connected to ${printer.name} but the receipt did not send. It may '
          'be out of paper.',
        );
      }
    } on PrintFailure {
      rethrow;
    } catch (e) {
      debugPrint('ReceiptPrinter: print failed: $e');
      throw PrintFailure('Printing failed: $e');
    } finally {
      // Best effort — a failed disconnect must not mask a successful print.
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
    }
  }
}

final receiptPrinterProvider = Provider<ReceiptPrinter>(
  (ref) => ReceiptPrinter(ref.read(localStoreProvider)),
);
