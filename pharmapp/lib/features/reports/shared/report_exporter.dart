import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/reports_api_client.dart';

/// Generates and shares/prints PDF reports using the pdf + printing packages.
class ReportExporter {
  ReportExporter._();

  // ── Brand colours (light PDF palette) ─────────────────────────────────────
  static final _teal   = PdfColor.fromHex('#0D9488');
  static final _navy   = PdfColor.fromHex('#0F172A');
  static final _slate  = PdfColor.fromHex('#475569');
  static final _border = PdfColor.fromHex('#CBD5E1');
  static final _amber  = PdfColor.fromHex('#D97706');
  static final _red    = PdfColor.fromHex('#DC2626');
  static final _green  = PdfColor.fromHex('#059669');
  static final _bgAlt  = PdfColor.fromHex('#F8FAFC');

  static String _currency(double v) {
    // Use NGN prefix — PDF built-in fonts don't support the ₦ glyph.
    final nf = NumberFormat('#,##0.00', 'en_US');
    if (v >= 10000000) return 'NGN ${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000)   return 'NGN ${(v / 100000).toStringAsFixed(2)}L';
    return 'NGN ${nf.format(v)}';
  }

  static String _generated() =>
      DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());

  // ── Shared layout blocks ────────────────────────────────────────────────────

  static pw.Widget _pageHeader(String title, String subtitle) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: pw.BoxDecoration(color: _navy),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PharmApp',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Container(
                    width: 36, height: 2, color: _teal),
                pw.SizedBox(height: 8),
                pw.Text(title,
                    style: pw.TextStyle(
                        color: _teal,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(subtitle,
                    style: const pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.54), fontSize: 9)),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated',
                    style: const pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.38), fontSize: 8)),
                pw.SizedBox(height: 2),
                pw.Text(_generated(),
                    style: const pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.60), fontSize: 9)),
              ],
            ),
          ],
        ),
      );

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10, top: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: _navy,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _kpiCard(String label, String value,
      {PdfColor? valueColor}) =>
      pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _bgAlt,
            border: pw.Border.all(color: _border, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style:
                      pw.TextStyle(color: _slate, fontSize: 8)),
              pw.SizedBox(height: 5),
              pw.Text(value,
                  style: pw.TextStyle(
                      color: valueColor ?? _navy,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  static pw.TableRow _tableHeaderRow(List<String> cols) => pw.TableRow(
        decoration: pw.BoxDecoration(color: _navy),
        children: cols
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: pw.Text(c,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                ))
            .toList(),
      );

  static pw.TableRow _tableDataRow(List<String> cells,
      {bool shaded = false}) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(
            color: shaded ? _bgAlt : PdfColors.white),
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  child: pw.Text(c,
                      style: pw.TextStyle(
                          color: _navy, fontSize: 9)),
                ))
            .toList(),
      );

  static pw.Widget _footer() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 24),
        child: pw.Row(children: [
          pw.Container(width: 32, height: 1.5, color: _teal),
          pw.SizedBox(width: 8),
          pw.Text('PharmApp — Pharmacy Management System',
              style: pw.TextStyle(color: _slate, fontSize: 7)),
        ]),
      );

  // ── Sales report ─────────────────────────────────────────────────────────────

  static Future<void> exportSalesReport(
      SalesReportData data, String periodLabel) async {
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (_) => _pageHeader('Sales Report', 'Period: $periodLabel'),
      build: (ctx) => [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle('Summary'),
              pw.Row(children: [
                _kpiCard('Total Revenue', _currency(data.totalRevenue),
                    valueColor: _green),
                _kpiCard('Retail Sales', _currency(data.totalRetail)),
                _kpiCard('Wholesale Sales',
                    _currency(data.totalWholesale)),
                _kpiCard('Transactions', '${data.totalSales}',
                    valueColor: _teal),
              ]),
              if (data.topItems.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _sectionTitle('Top Selling Items'),
                pw.Table(
                  border: pw.TableBorder.all(
                      color: _border, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    _tableHeaderRow(
                        ['#', 'Item Name', 'Qty Sold', 'Revenue']),
                    ...data.topItems.asMap().entries.map((e) =>
                        _tableDataRow([
                          '${e.key + 1}',
                          e.value.name,
                          '${e.value.qty}',
                          _currency(e.value.revenue),
                        ], shaded: e.key.isOdd)),
                  ],
                ),
              ],
              _footer(),
            ],
          ),
        ),
      ],
    ));

    final bytes = await doc.save();
    await Printing.sharePdf(
        bytes: bytes,
        filename:
            'sales_report_${periodLabel.toLowerCase().replaceAll(' ', '_')}.pdf');
  }

  // ── Inventory report ──────────────────────────────────────────────────────────

  static Future<void> exportInventoryReport(
      InventoryReportData data) async {
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (_) =>
          _pageHeader('Inventory Report', 'Stock status & valuation'),
      build: (ctx) => [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle('Summary'),
              pw.Row(children: [
                _kpiCard('Total Items', '${data.totalItems}'),
                _kpiCard('Low Stock Items',
                    '${data.lowStockCount}',
                    valueColor: _amber),
                _kpiCard('Total Stock Value',
                    _currency(data.stockValue),
                    valueColor: _green),
                pw.Expanded(child: pw.SizedBox()),
              ]),
              if (data.lowStockItems.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _sectionTitle(
                    'Low Stock Items (${data.lowStockItems.length})'),
                pw.Table(
                  border: pw.TableBorder.all(
                      color: _border, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    _tableHeaderRow([
                      'Item Name',
                      'Current Stock',
                      'Min Threshold',
                      'Status',
                    ]),
                    ...data.lowStockItems.asMap().entries.map((e) {
                      final item = e.value;
                      final status =
                          item.stock == 0 ? 'Out of Stock' : 'Low Stock';
                      return _tableDataRow([
                        item.name,
                        '${item.stock}',
                        '${item.lowStockThreshold}',
                        status,
                      ], shaded: e.key.isOdd);
                    }),
                  ],
                ),
              ],
              _footer(),
            ],
          ),
        ),
      ],
    ));

    final bytes = await doc.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'inventory_report.pdf');
  }

  // ── Customer report ───────────────────────────────────────────────────────────

  static Future<void> exportCustomerReport(
      CustomerReportData data) async {
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (_) => _pageHeader(
          'Customer Report', 'Analytics & debt tracking'),
      build: (ctx) => [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle('Summary'),
              pw.Row(children: [
                _kpiCard('Total Customers', '${data.total}'),
                _kpiCard('Retail Customers',
                    '${data.retail}'),
                _kpiCard('Wholesale Customers',
                    '${data.wholesale}'),
                _kpiCard('Outstanding Debt',
                    _currency(data.totalDebt),
                    valueColor: _red),
              ]),
              if (data.topCustomers.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _sectionTitle('Top Customers by Spend'),
                pw.Table(
                  border: pw.TableBorder.all(
                      color: _border, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    _tableHeaderRow(
                        ['#', 'Customer Name', 'Total Spent']),
                    ...data.topCustomers.asMap().entries.map((e) =>
                        _tableDataRow([
                          '${e.key + 1}',
                          e.value.name,
                          _currency(e.value.spent),
                        ], shaded: e.key.isOdd)),
                  ],
                ),
              ],
              _footer(),
            ],
          ),
        ),
      ],
    ));

    final bytes = await doc.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'customer_report.pdf');
  }

  // ── Profit report ─────────────────────────────────────────────────────────────

  static Future<void> exportProfitReport(
      ProfitReportData data, String periodLabel) async {
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Column(
        children: [
          _pageHeader('Profit Report', 'Period: $periodLabel'),
          pw.Padding(
            padding:
                const pw.EdgeInsets.fromLTRB(28, 20, 28, 28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionTitle('Summary'),
                pw.Row(children: [
                  _kpiCard('Revenue',
                      _currency(data.revenue)),
                  _kpiCard('Gross Profit',
                      _currency(data.profit),
                      valueColor: _green),
                  _kpiCard('Profit Margin',
                      '${data.margin.toStringAsFixed(1)}%',
                      valueColor:
                          data.margin >= 20 ? _green : _amber),
                  pw.Expanded(child: pw.SizedBox()),
                ]),
                pw.SizedBox(height: 20),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: _bgAlt,
                    border: pw.Border.all(
                        color: _border, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6)),
                  ),
                  child: pw.Row(children: [
                    pw.Container(
                        width: 3,
                        height: 40,
                        color: data.margin >= 20
                            ? _green
                            : _amber),
                    pw.SizedBox(width: 12),
                    pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                              data.margin >= 30
                                  ? 'Excellent margin'
                                  : data.margin >= 20
                                      ? 'Healthy margin'
                                      : data.margin >= 10
                                          ? 'Moderate margin'
                                          : 'Low margin — review pricing',
                              style: pw.TextStyle(
                                  color: _navy,
                                  fontSize: 11,
                                  fontWeight:
                                      pw.FontWeight.bold)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                              'For every NGN 100 of revenue, '
                              'NGN ${data.margin.toStringAsFixed(1)} is profit.',
                              style: pw.TextStyle(
                                  color: _slate,
                                  fontSize: 9)),
                        ]),
                  ]),
                ),
                _footer(),
              ],
            ),
          ),
        ],
      ),
    ));

    final bytes = await doc.save();
    await Printing.sharePdf(
        bytes: bytes,
        filename:
            'profit_report_${periodLabel.toLowerCase().replaceAll(' ', '_')}.pdf');
  }
}
