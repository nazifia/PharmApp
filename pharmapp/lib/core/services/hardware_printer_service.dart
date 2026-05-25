import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

export 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart'
    show BluetoothInfo;

class HardwarePrinterService {
  static const int _cols = 42; // 80mm paper @ standard thermal font

  static bool get isBtSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<bool> isBluetoothEnabled() async {
    if (!isBtSupported) return false;
    return PrintBluetoothThermal.bluetoothEnabled;
  }

  static Future<List<BluetoothInfo>> pairedPrinters() async {
    if (!isBtSupported) return [];
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<void> printReceipt(
      String mac, Map<String, dynamic> saleData) async {
    final connected =
        await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!connected) {
      throw Exception(
          'Cannot connect to printer.\nMake sure it is on and paired.');
    }
    try {
      final bytes = _buildEscPos(saleData);
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) throw Exception('Printer did not acknowledge data.');
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }

  // ── ESC/POS receipt builder ───────────────────────────────────────────────

  static List<int> _buildEscPos(Map<String, dynamic> data) {
    final buf = <int>[];

    void esc(List<int> cmd) => buf.addAll(cmd);

    // Encode string — replace non-Latin-1 chars with safe equivalents
    void str(String s) {
      final safe = s
          .replaceAll('₦', 'N')
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll('‘', "'")
          .replaceAll('’', "'");
      buf.addAll(safe.codeUnits.map((c) => c > 255 ? 0x3F : c));
    }

    void ln([String s = '']) {
      str(s);
      buf.add(0x0A);
    }

    void feed([int n = 1]) {
      for (var i = 0; i < n; i++) { buf.add(0x0A); }
    }

    // ESC/POS command helpers
    void align(int a) => esc([0x1B, 0x61, a]); // 0=left 1=center 2=right
    void bold(bool on) => esc([0x1B, 0x45, on ? 1 : 0]);
    void dblSize(bool on) => esc([0x1D, 0x21, on ? 0x11 : 0x00]);
    void dblHeight(bool on) => esc([0x1D, 0x21, on ? 0x01 : 0x00]);

    String sep1() => '=' * _cols;
    String sep2() => '-' * _cols;
    String money(double v) => 'N${_fmt(v)}';

    // Field extraction
    final orgName =
        data['organizationName'] as String? ?? 'PharmApp';
    final orgAddress =
        data['organizationAddress'] as String? ?? '';
    final orgPhone =
        data['organizationPhone'] as String? ?? '';
    final branchAddress =
        data['branchAddress'] as String? ?? '';
    final branchPhone =
        data['branchPhone'] as String? ?? '';
    final displayAddress =
        branchAddress.isNotEmpty ? branchAddress : orgAddress;
    final displayPhone =
        branchPhone.isNotEmpty ? branchPhone : orgPhone;

    final receiptId =
        data['receiptId'] as String? ?? '#${data['id']}';
    final customerName = (data['customerName'] ??
            data['customer_name'] ??
            data['patientName'] ??
            data['patient_name'] ??
            'Walk-in') as String;
    final cashierName = data['cashierName'] as String? ?? '';
    final dispenserName = data['dispenserName'] as String? ?? '';
    final isWholesale = data['isWholesale'] as bool? ?? false;
    final total =
        (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final discountTotal =
        (data['discountTotal'] as num?)?.toDouble() ?? 0;
    final items = data['items'] as List<dynamic>? ?? [];

    final raw = data['created'] as String? ??
        data['createdAt'] as String? ??
        data['created_at'] as String? ??
        '';
    String dateStr = raw;
    try {
      final dt = DateTime.parse(raw).toLocal();
      const ms = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mi = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour < 12 ? 'AM' : 'PM';
      dateStr =
          '${ms[dt.month - 1]} ${dt.day}, ${dt.year} $h:$mi $ap';
    } catch (_) {}

    final payments = <String, double>{};
    for (final p in data['payments'] as List<dynamic>? ?? []) {
      final pm = p as Map<String, dynamic>;
      final method = pm['paymentMethod'] as String? ?? 'cash';
      final amount = (pm['amount'] as num?)?.toDouble() ?? 0;
      final label = _methodLabel(method);
      payments[label] = (payments[label] ?? 0) + amount;
    }

    // ── Build receipt ────────────────────────────────────────────────────────

    esc([0x1B, 0x40]); // initialize printer

    // Header
    align(1);
    dblSize(true);
    ln(_trunc(orgName, 20));
    dblSize(false);
    if (displayAddress.isNotEmpty) ln(_trunc(displayAddress, _cols));
    if (displayPhone.isNotEmpty) ln(displayPhone);
    ln(sep1());

    // Meta
    align(0);
    ln('Receipt : $receiptId');
    ln('Date    : $dateStr');
    ln('Customer: ${_trunc(customerName, _cols - 10)}');
    final servedBy =
        dispenserName.isNotEmpty ? dispenserName : cashierName;
    if (servedBy.isNotEmpty) ln('Served  : ${_trunc(servedBy, _cols - 10)}');
    if (isWholesale) ln('Type    : Wholesale');
    ln(sep2());

    // Column header row: name(25) qty(5) total(12)
    const nW = 25;
    const qW = 5;
    const tW = 12;
    ln('${'ITEM'.padRight(nW)}${'QTY'.padLeft(qW)}${'AMOUNT'.padLeft(tW)}');
    ln(sep2());

    // Items
    for (final item in items) {
      final itm = item as Map<String, dynamic>;
      final name =
          itm['itemName'] as String? ?? itm['name'] as String? ?? 'Item';
      final qty = (itm['quantity'] as num?)?.toInt() ?? 1;
      final lineTotal = (itm['lineTotal'] as num?)?.toDouble() ??
          (itm['totalPrice'] as num?)?.toDouble() ??
          0;

      if (name.length <= nW) {
        ln('${name.padRight(nW)}${'x$qty'.padLeft(qW)}${_fmt(lineTotal).padLeft(tW)}');
      } else {
        // Long name: wrap
        ln(_trunc(name, _cols));
        ln('${''.padRight(nW)}${'x$qty'.padLeft(qW)}${_fmt(lineTotal).padLeft(tW)}');
      }
    }

    ln(sep2());

    // Totals (right-aligned)
    align(2);
    if (discountTotal > 0) {
      ln('Subtotal : ${money(total + discountTotal)}');
      ln('Discount : -${money(discountTotal)}');
    }
    bold(true);
    dblHeight(true);
    ln('TOTAL : ${money(total)}');
    dblHeight(false);
    bold(false);
    align(0);

    ln(sep1());

    // Payments
    if (payments.isEmpty) {
      ln('Cash'.padRight(_cols - 12) + money(total).padLeft(12));
    } else {
      for (final e in payments.entries) {
        ln(e.key.padRight(_cols - 12) + money(e.value).padLeft(12));
      }
    }

    ln(sep1());

    // Footer
    align(1);
    ln('Thank you for your patronage!');
    ln('Powered by PharmApp');

    feed(4);
    esc([0x1D, 0x56, 0x41, 0x03]); // partial cut

    return buf;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _fmt(double v) {
    final s = v == v.truncateToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  static String _trunc(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}~';

  static String _methodLabel(String m) {
    switch (m.toLowerCase()) {
      case 'pos':
      case 'card':
        return 'Card/POS';
      case 'transfer':
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'wallet':
        return 'Wallet';
      default:
        return 'Cash';
    }
  }
}
