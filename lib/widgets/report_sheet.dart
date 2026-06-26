import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/report_store.dart';
import '../models/report.dart';
import '../l10n/app_localizations.dart';

/// Opens the "report a problem" sheet. Saves the report locally on submit and
/// offers to send it on to the developer via the share sheet.
///
/// Pass [species*]/[zoo*] context to attach it, [presetCategory] to preselect,
/// and [lockCategory] to fix the category (e.g. "missing species" from a zoo).
Future<void> showReportSheet(
  BuildContext context, {
  ReportCategory? presetCategory,
  bool lockCategory = false,
  String? speciesId,
  String? speciesName,
  String? zooId,
  String? zooName,
  String? title,
}) async {
  final resolvedTitle =
      title ?? AppLocalizations.of(context).reportSheetReportAProblem;
  final report = await showModalBottomSheet<Report>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ReportSheet(
        title: resolvedTitle,
        presetCategory: presetCategory ?? ReportCategory.other,
        lockCategory: lockCategory,
        speciesId: speciesId,
        speciesName: speciesName,
        zooId: zooId,
        zooName: zooName,
      ),
    ),
  );

  if (report == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.reportSheetThanksReportSaved),
      action: SnackBarAction(
        label: l10n.reportSheetSend,
        onPressed: () => _share(messenger, report.toReadable(), l10n),
      ),
    ),
  );
}

Future<void> _share(
    ScaffoldMessengerState messenger, String text, AppLocalizations l10n) async {
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: l10n.reportSheetShareSubject),
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.reportSheetCopiedToClipboard)),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final String title;
  final ReportCategory presetCategory;
  final bool lockCategory;
  final String? speciesId;
  final String? speciesName;
  final String? zooId;
  final String? zooName;

  const _ReportSheet({
    required this.title,
    required this.presetCategory,
    required this.lockCategory,
    this.speciesId,
    this.speciesName,
    this.zooId,
    this.zooName,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  late ReportCategory _category = widget.presetCategory;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final report = await ReportStore.add(
      category: _category,
      speciesId: widget.speciesId,
      speciesName: widget.speciesName,
      zooId: widget.zooId,
      zooName: widget.zooName,
      note: _note.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(report);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    final context_ = <String>[
      if (widget.speciesName != null) widget.speciesName!,
      if (widget.zooName != null) widget.zooName!,
    ];
    final isMissing = _category == ReportCategory.missingSpecies;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: Theme.of(context).textTheme.titleLarge),
          if (context_.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(context_.join(' · '), style: TextStyle(color: muted)),
          ],
          const SizedBox(height: 16),

          if (!widget.lockCategory)
            DropdownButtonFormField<ReportCategory>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).reportSheetWhatsWrong,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final c in ReportCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
          if (!widget.lockCategory) const SizedBox(height: 12),

          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: isMissing
                  ? AppLocalizations.of(context).reportSheetWhichSpecies
                  : AppLocalizations.of(context).reportSheetNotesOptional,
              hintText: isMissing
                  ? AppLocalizations.of(context).reportSheetMissingHint
                  : AppLocalizations.of(context).reportSheetDescribeProblem,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (_saving ||
                        (isMissing && _note.text.trim().isEmpty))
                    ? null
                    : _submit,
                child: Text(_saving
                    ? AppLocalizations.of(context).reportSheetSaving
                    : AppLocalizations.of(context).reportSheetSubmit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
