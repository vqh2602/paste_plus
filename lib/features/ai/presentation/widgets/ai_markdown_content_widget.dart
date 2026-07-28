import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';

class AiMarkdownContentWidget extends StatelessWidget {
  const AiMarkdownContentWidget({
    super.key,
    required this.content,
    required this.onCopy,
  });

  final String content;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseMarkdownBlocks(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          _MarkdownBlockWidget(
            key: ValueKey('ai-response-block-$index'),
            block: blocks[index],
            onCopy: onCopy,
          ),
          if (index != blocks.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

enum _MarkdownBlockType { paragraph, listItem, code }

class _MarkdownBlock {
  const _MarkdownBlock({
    required this.type,
    required this.displayText,
    required this.copyText,
    this.listMarker,
  });

  final _MarkdownBlockType type;
  final String displayText;
  final String copyText;
  final String? listMarker;
}

class _MarkdownBlockWidget extends StatelessWidget {
  const _MarkdownBlockWidget({
    super.key,
    required this.block,
    required this.onCopy,
  });

  final _MarkdownBlock block;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final isCode = block.type == _MarkdownBlockType.code;
    final secondary = resolveColor(context, ClipFlowColors.secondaryText);
    final contentWidget = isCode
        ? SelectableText(
            block.displayText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              fontFamily: 'monospace',
            ),
          )
        : SelectableText.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: resolveColor(context, ClipFlowColors.text),
              ),
              children: _inlineMarkdownSpans(context, block.displayText),
            ),
          );

    return Container(
      padding: EdgeInsets.fromLTRB(isCode ? 12 : 10, 9, 6, 9),
      decoration: BoxDecoration(
        color: isCode
            ? resolveColor(context, ClipFlowColors.sidebar)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(10),
        border: isCode
            ? Border.all(color: resolveColor(context, ClipFlowColors.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.listMarker != null) ...[
            SizedBox(
              width: 24,
              child: Text(
                block.listMarker!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          Expanded(child: contentWidget),
          const SizedBox(width: 6),
          CupertinoIconControl(
            icon: CupertinoIcons.doc_on_doc,
            size: 13,
            color: secondary,
            tooltip: 'copy_part'.tr,
            onPressed: block.copyText.isEmpty
                ? null
                : () => onCopy(block.copyText),
          ),
        ],
      ),
    );
  }
}

List<_MarkdownBlock> _parseMarkdownBlocks(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <_MarkdownBlock>[];
  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    if (line.trim().isEmpty) {
      index++;
      continue;
    }
    if (line.trimLeft().startsWith('```')) {
      index++;
      final code = <String>[];
      while (index < lines.length &&
          !lines[index].trimLeft().startsWith('```')) {
        code.add(lines[index]);
        index++;
      }
      if (index < lines.length) index++;
      final value = code.join('\n').trimRight();
      blocks.add(
        _MarkdownBlock(
          type: _MarkdownBlockType.code,
          displayText: value,
          copyText: value,
        ),
      );
      continue;
    }

    final ordered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line.trimLeft());
    final unordered = RegExp(r'^[-•*]\s+(.*)$').firstMatch(line.trimLeft());
    if (ordered != null || unordered != null) {
      final firstLine = ordered?.group(2) ?? unordered!.group(1)!;
      final continuation = <String>[];
      index++;
      while (index < lines.length &&
          lines[index].trim().isNotEmpty &&
          !RegExp(r'^(\d+\.\s+|[-•*]\s+)').hasMatch(lines[index].trimLeft()) &&
          !lines[index].trimLeft().startsWith('```')) {
        continuation.add(lines[index].trim());
        index++;
      }
      final display = [firstLine, ...continuation].join('\n');
      final clipboardOnly = ordered != null && continuation.isNotEmpty
          ? continuation.join('\n')
          : display;
      blocks.add(
        _MarkdownBlock(
          type: _MarkdownBlockType.listItem,
          displayText: display,
          copyText: _stripInlineMarkdown(clipboardOnly),
          listMarker: ordered != null ? '${ordered.group(1)}.' : '•',
        ),
      );
      continue;
    }

    final paragraph = <String>[line.trim()];
    index++;
    while (index < lines.length && lines[index].trim().isNotEmpty) {
      if (lines[index].trimLeft().startsWith('```') ||
          RegExp(r'^(\d+\.\s+|[-•*]\s+)').hasMatch(lines[index].trimLeft())) {
        break;
      }
      paragraph.add(lines[index].trim());
      index++;
    }
    final value = paragraph.join('\n');
    blocks.add(
      _MarkdownBlock(
        type: _MarkdownBlockType.paragraph,
        displayText: value,
        copyText: _stripInlineMarkdown(value),
      ),
    );
  }
  return blocks;
}

List<InlineSpan> _inlineMarkdownSpans(BuildContext context, String text) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`|(?<!\*)\*[^*]+\*(?!\*))');
  var offset = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, match.start)));
    }
    final token = match.group(0)!;
    if (token.startsWith('**')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (token.startsWith('`')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            backgroundColor: resolveColor(context, ClipFlowColors.sidebar),
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    offset = match.end;
  }
  if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
  return spans;
}

String _stripInlineMarkdown(String value) => value
    .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
    .replaceAll(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), r'$1')
    .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
    .trim();
