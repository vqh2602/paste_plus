import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../clipboard_history/domain/clipboard_content_type.dart';
import '../../../clipboard_history/domain/clipboard_item.dart';

class AiContextPickerSheet extends StatelessWidget {
  const AiContextPickerSheet({
    super.key,
    required this.items,
    required this.selectedItemId,
  });

  final List<ClipboardItem> items;
  final String? selectedItemId;

  static Future<ClipboardItem?> show(
    BuildContext context, {
    required List<ClipboardItem> items,
    String? selectedItemId,
  }) {
    return showCupertinoModalPopup<ClipboardItem>(
      context: context,
      builder: (_) =>
          AiContextPickerSheet(items: items, selectedItemId: selectedItemId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.68;
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height.clamp(320, 620),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ai_choose_context_title'.tr,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CupertinoIconControl(
                      icon: CupertinoIcons.xmark,
                      tooltip: 'close'.tr,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const CupertinoDivider(),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('ai_no_context_items'.tr))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const CupertinoDivider(indent: 54),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final selected = item.id == selectedItemId;
                          return CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            onPressed: () => Navigator.pop(context, item),
                            child: Row(
                              children: [
                                Icon(
                                  item.contentType == ClipboardContentType.image
                                      ? CupertinoIcons.photo
                                      : CupertinoIcons.doc_text,
                                  size: 19,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.content.isEmpty
                                            ? item.contentType.name
                                            : item.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: CupertinoColors.label,
                                        ),
                                      ),
                                      if (item.sourceAppName?.isNotEmpty ==
                                          true)
                                        Text(
                                          item.sourceAppName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color:
                                                CupertinoColors.secondaryLabel,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: CupertinoColors.activeBlue,
                                    size: 20,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
