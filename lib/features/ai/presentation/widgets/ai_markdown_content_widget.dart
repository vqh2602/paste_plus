import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

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
    if (block.type == _MarkdownBlockType.listItem) {
      return _ResultCardWidget(
        listMarker: block.listMarker,
        displayText: block.displayText,
        copyText: block.copyText,
        onCopy: onCopy,
      );
    }

    final isCode = block.type == _MarkdownBlockType.code;
    final secondary = resolveColor(context, ClipFlowColors.secondaryText);
    final cleanDisplay = _cleanTechnicalIds(block.displayText);

    final contentWidget = isCode
        ? SelectableText(
            cleanDisplay,
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
              children: _inlineMarkdownSpans(context, cleanDisplay),
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
          Expanded(child: contentWidget),
          const SizedBox(width: 6),
          CupertinoIconControl(
            icon: CupertinoIcons.doc_on_doc,
            size: 13,
            color: secondary,
            tooltip: context.l10n.copy_part,
            onPressed: block.copyText.isEmpty
                ? null
                : () => onCopy(block.copyText),
          ),
        ],
      ),
    );
  }
}

class _ResultCardWidget extends StatelessWidget {
  const _ResultCardWidget({
    required this.listMarker,
    required this.displayText,
    required this.copyText,
    required this.onCopy,
  });

  final String? listMarker;
  final String displayText;
  final String copyText;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final cleanDisplay = _cleanTechnicalIds(displayText);
    final urlMatch = RegExp(r'https?://[^\s<"]+').firstMatch(cleanDisplay);
    final url = urlMatch?.group(0);
    final isImgUrl = url != null && _isImageUrl(url);
    final isCode =
        cleanDisplay.contains('curl ') ||
        cleanDisplay.contains('flutter ') ||
        cleanDisplay.contains('build/macos');

    final appName = _extractAppName(cleanDisplay);

    final primary = CupertinoTheme.of(context).primaryColor;
    final secondary = resolveColor(context, ClipFlowColors.secondaryText);
    final surfaceColor = resolveColor(context, ClipFlowColors.sidebar);
    final borderColor = resolveColor(context, ClipFlowColors.border);

    final (badgeIcon, badgeLabel, badgeColor) = isImgUrl
        ? (
            CupertinoIcons.photo,
            context.l10n.image_link,
            CupertinoColors.systemIndigo,
          )
        : url != null
        ? (CupertinoIcons.link, context.l10n.url, CupertinoColors.activeBlue)
        : isCode
        ? (
            CupertinoIcons.chevron_left_slash_chevron_right,
            context.l10n.code,
            CupertinoColors.systemOrange,
          )
        : (
            CupertinoIcons.doc_text,
            context.l10n.text,
            CupertinoColors.systemGrey,
          );

    final bodyText = _extractBodyText(cleanDisplay, url, appName);
    final cleanCopy = _stripInlineMarkdown(copyText);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (listMarker != null && listMarker!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    listMarker!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (appName != null && appName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '•  $appName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: secondary,
                  ),
                ),
              ],
              const Spacer(),
              CupertinoIconControl(
                icon: CupertinoIcons.doc_on_doc,
                size: 13,
                color: secondary,
                tooltip: context.l10n.copy_part,
                onPressed: cleanCopy.isEmpty ? null : () => onCopy(cleanCopy),
              ),
              if (url != null) ...[
                const SizedBox(width: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(26, 26),
                  onPressed: () => _openUrlInBrowser(url),
                  child: const Icon(
                    CupertinoIcons.arrow_up_right_square,
                    size: 14,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (url != null)
            GestureDetector(
              onTap: () => _openUrlInBrowser(url),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          url,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: badgeColor,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.arrow_up_right,
                        size: 12,
                        color: badgeColor,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SelectableText.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: resolveColor(context, ClipFlowColors.text),
                ),
                children: _inlineMarkdownSpans(context, bodyText),
              ),
            ),
        ],
      ),
    );
  }
}

String _cleanTechnicalIds(String text) {
  return text
      .replaceAll(RegExp(r'\[clip:[^\]]+\]'), '')
      .replaceAll(RegExp(r'clip:[a-zA-Z0-9_-]+'), '')
      .replaceAll(RegExp(r'\s+·\s+'), ' ')
      .trim();
}

bool _isImageUrl(String url) {
  final lower = url.toLowerCase();
  const exts = [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.svg',
    '.heic',
    '.avif',
  ];
  const domains = [
    'iili.io',
    'freeimage.host',
    'imgur.com',
    'gyazo.com',
    'cloudinary.com',
    'unsplash.com',
    'postimg.cc',
  ];
  return exts.any(lower.contains) || domains.any(lower.contains);
}

String? _extractAppName(String text) {
  final cleaned = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
  final appMatch = RegExp(
    r'(?:^|—\s*|:\s*)([A-Z][a-zA-Z0-9_\s]{1,20})(?::|\s+·|\s+-|\s+https?:)',
  ).firstMatch(cleaned);
  if (appMatch != null) {
    final name = appMatch.group(1)!.trim();
    if (name != 'LINK ÁNH' &&
        name != 'LINK' &&
        name != 'CODE' &&
        name != 'URL' &&
        name != 'TEXT') {
      return name;
    }
  }
  final colonMatch = RegExp(
    r'^([A-Z][a-zA-Z0-9_\s]{1,20}):\s+',
  ).firstMatch(cleaned);
  if (colonMatch != null) {
    final name = colonMatch.group(1)!.trim();
    if (name != 'LINK ÁNH' &&
        name != 'LINK' &&
        name != 'CODE' &&
        name != 'URL' &&
        name != 'TEXT') {
      return name;
    }
  }
  return null;
}

String _extractBodyText(String text, String? url, String? appName) {
  var body = text;
  if (appName != null) {
    body = body.replaceAll(RegExp('^${RegExp.escape(appName)}:?\\s*'), '');
    body = body.replaceAll(RegExp(r'—\s*' + RegExp.escape(appName)), '');
  }
  body = body
      .replaceAll(RegExp(r'^\*\*(LINK ÁNH|LINK|URL|CODE|TEXT)\*\*\s*—?\s*'), '')
      .trim();
  return body.isEmpty ? (url ?? text) : body;
}

void _openUrlInBrowser(String url) {
  final uri = url.trim();
  if (uri.isEmpty) return;
  try {
    if (Platform.isMacOS) {
      Process.run('open', [uri]);
    } else if (Platform.isWindows) {
      Process.run('start', [uri], runInShell: true);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [uri]);
    }
  } catch (_) {}
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
    .replaceAll(RegExp(r'\[clip:[^\]]+\]'), '')
    .replaceAll(RegExp(r'clip:[a-zA-Z0-9_-]+'), '')
    .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
    .replaceAll(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), r'$1')
    .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
    .replaceAll(RegExp(r'\s+·\s+'), ' ')
    .trim();
