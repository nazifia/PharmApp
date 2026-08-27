import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_api_client.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';

const _kImportExtensions = ['csv', 'tsv', 'txt', 'xlsx', 'xlsm', 'pdf'];

/// Opens the bulk item upload sheet. Returns true when items were imported.
Future<bool> showBulkImportSheet(BuildContext context, {String store = 'retail'}) async {
  final imported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BulkImportSheet(store: store),
  );
  return imported ?? false;
}

/// Pick a CSV / Excel / PDF stock sheet, preview what it would change, then import.
///
/// The preview is the backend's own dry run, so what the sheet shows is exactly
/// what the real upload will do.
class BulkImportSheet extends ConsumerStatefulWidget {
  final String store;
  const BulkImportSheet({super.key, required this.store});

  @override
  ConsumerState<BulkImportSheet> createState() => _BulkImportSheetState();
}

class _BulkImportSheetState extends ConsumerState<BulkImportSheet> {
  String? _fileName;
  List<int>? _bytes;
  String _stockMode = 'replace';
  bool _busy = false;
  String? _error;
  BulkImportResult? _preview;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kImportExtensions,
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    setState(() {
      _fileName = file.name;
      _bytes = file.bytes;
      _preview = null;
      _error = null;
    });
    await _run(dryRun: true);
  }

  Future<void> _run({required bool dryRun}) async {
    if (_bytes == null || _fileName == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(inventoryApiProvider).bulkImportItems(
            fileName: _fileName!,
            bytes: _bytes!,
            dryRun: dryRun,
            store: widget.store,
            stockMode: _stockMode,
            branchId: ref.read(activeBranchProvider)?.id,
          );
      if (!mounted) return;
      if (dryRun) {
        setState(() => _preview = result);
        return;
      }
      ref.invalidate(retailInventoryProvider);
      ref.invalidate(wholesaleInventoryProvider);
      ref.invalidate(inventoryListProvider);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.primaryTeal,
        content: Text(
          '${result.created} added, ${result.updated} updated'
          '${result.skipped > 0 ? ', ${result.skipped} skipped' : ''}.',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: context.borderColor),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.upload_file_rounded,
                  color: EnhancedTheme.primaryTeal, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Import ${widget.store} items',
                    style: TextStyle(
                        color: context.labelColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CSV, Excel (.xlsx) or a PDF with a real table. The file needs a '
                'header row; a "name" column is required, and columns like price, '
                'cost, qty, barcode, batch and expiry are picked up automatically.',
                style: TextStyle(
                    color: context.subLabelColor, fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            _fileButton(context),
            const SizedBox(height: 14),
            _stockModeSelector(context),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _banner(context, _error!, EnhancedTheme.errorRed, Icons.error_outline_rounded),
            ],
            if (preview != null) ...[
              const SizedBox(height: 16),
              _previewSummary(context, preview),
              if (preview.errors.isNotEmpty) ...[
                const SizedBox(height: 10),
                _errorList(context, preview),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy || (preview.created + preview.updated) == 0
                      ? null
                      : () => _run(dryRun: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.download_done_rounded, size: 18),
                  label: Text(
                    'Import ${preview.created + preview.updated} item(s)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _fileButton(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _pickFile,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.labelColor,
            side: BorderSide(color: context.borderColor),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.attach_file_rounded, size: 18),
          label: Text(_fileName ?? 'Choose a file',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  Widget _stockModeSelector(BuildContext context) => Row(children: [
        Expanded(
          child: Text('Stock in the file',
              style: TextStyle(color: context.subLabelColor, fontSize: 12)),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'replace', label: Text('Replaces')),
            ButtonSegment(value: 'add', label: Text('Adds to')),
          ],
          selected: {_stockMode},
          showSelectedIcon: false,
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11, color: context.labelColor)),
            visualDensity: VisualDensity.compact,
          ),
          onSelectionChanged: _busy
              ? null
              : (selection) {
                  setState(() => _stockMode = selection.first);
                  // The preview depends on the mode, so re-run it.
                  _run(dryRun: true);
                },
        ),
      ]);

  Widget _previewSummary(BuildContext context, BulkImportResult r) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.totalRows} row(s) read from ${r.fileName}',
              style: TextStyle(
                  color: context.labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '${r.created} new item(s), ${r.updated} existing item(s) updated'
            '${r.skipped > 0 ? ', ${r.skipped} row(s) skipped' : ''}.',
            style: TextStyle(color: context.subLabelColor, fontSize: 12, height: 1.4),
          ),
          if (r.preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...r.preview.take(5).map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${row['action'] == 'create' ? '+' : '~'} ${row['name']}  '
                    'qty ${row['stock']}  @ ${row['price']}',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
            if (r.preview.length > 5)
              Text('...and ${r.preview.length - 5} more',
                  style: TextStyle(color: context.subLabelColor, fontSize: 11)),
          ],
        ]),
      );

  Widget _errorList(BuildContext context, BulkImportResult r) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.skipped} row(s) skipped',
              style: const TextStyle(
                  color: EnhancedTheme.errorRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...r.errors.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('Row ${e['row']}: ${e['name']} — ${e['detail']}',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              )),
          if (r.errors.length > 5)
            Text('...and ${r.errors.length - 5} more',
                style: TextStyle(color: context.subLabelColor, fontSize: 11)),
        ]),
      );

  Widget _banner(BuildContext context, String text, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: context.labelColor, fontSize: 12, height: 1.4)),
          ),
        ]),
      );
}
