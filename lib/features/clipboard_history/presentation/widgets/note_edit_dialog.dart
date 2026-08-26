import 'dart:async';

import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_item.dart';

/// Shows an auto-saving note dialog for editing notes on a clipboard item.
/// Typing inside the text field auto-saves in real-time without needing a save button.
Future<void> showNoteEditDialog(
  BuildContext context,
  WidgetRef ref,
  ClipboardItem item,
) async {
  final controller = TextEditingController(text: item.note ?? '');
  Timer? debounceTimer;

  void save(String text) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 200), () {
      ref.read(historyControllerProvider.notifier).updateNote(item, text);
    });
  }

  await showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.pencil,
            size: 18,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(width: 6),
          Text(
            item.note?.isNotEmpty == true
                ? context.l10n.edit_note
                : context.l10n.add_note,
          ),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CupertinoTextField(
              controller: controller,
              placeholder: context.l10n.type_note_placeholder,
              maxLines: 4,
              minLines: 2,
              autofocus: true,
              onChanged: save,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: resolveColor(ctx, ClipFlowColors.surface),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: resolveColor(ctx, ClipFlowColors.border),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ctx.l10n.auto_save_note_hint,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: resolveColor(
                  ctx,
                  ClipFlowColors.secondaryText,
                ).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () {
            debounceTimer?.cancel();
            ref
                .read(historyControllerProvider.notifier)
                .updateNote(item, controller.text);
            Navigator.pop(ctx);
          },
          child: Text(context.l10n.cancel),
        ),
      ],
    ),
  );

  debounceTimer?.cancel();
  controller.dispose();
}
