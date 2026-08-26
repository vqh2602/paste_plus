import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_item.dart';
import '../../domain/url_preview_metadata.dart';

class UrlPreviewCard extends ConsumerStatefulWidget {
  const UrlPreviewCard({super.key, required this.item, this.imageHeight = 190});

  final ClipboardItem item;
  final double imageHeight;

  @override
  ConsumerState<UrlPreviewCard> createState() => _UrlPreviewCardState();
}

class _UrlPreviewCardState extends ConsumerState<UrlPreviewCard> {
  String? _requestedItemId;

  @override
  void initState() {
    super.initState();
    _schedulePreviewLoad();
  }

  @override
  void didUpdateWidget(covariant UrlPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _schedulePreviewLoad();
  }

  void _schedulePreviewLoad() {
    if (_requestedItemId == widget.item.id) return;
    _requestedItemId = widget.item.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(historyControllerProvider.notifier)
          .ensureUrlPreview(widget.item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final currentItem = state.items
        .where((item) => item.id == widget.item.id)
        .firstOrNull;
    final item = currentItem ?? widget.item;
    final preview = UrlPreviewMetadata.fromClipboardMetadata(item.metadataJson);
    final uri = Uri.tryParse(item.primaryUrl ?? item.content.trim());
    final host = uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? item.content;
    final title = preview?.displayTitle(uri ?? Uri());

    return CupertinoPressable(
      onPressed: () {
        final url = item.primaryUrl ?? item.content;
        ref.read(desktopIntegrationProvider).openUrl(url);
      },
      child: Container(
        key: const Key('url-preview-card'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: resolveColor(context, ClipFlowColors.border),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview?.imageUrl case final imageUrl?)
              CachedNetworkImage(
                key: const Key('url-preview-image'),
                url: imageUrl,
                width: double.infinity,
                height: widget.imageHeight,
                fit: BoxFit.cover,
                errorBuilder: _LinkImageFallback(host: host),
              )
            else
              _LinkImageFallback(host: host, height: widget.imageHeight),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title?.isNotEmpty == true ? title! : host,
                    key: const Key('url-preview-title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (preview?.description case final description?) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      key: const Key('url-preview-description'),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkImageFallback extends StatelessWidget {
  const _LinkImageFallback({required this.host, this.height});

  final String host;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('url-preview-image-fallback'),
      width: double.infinity,
      height: height,
      color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.09),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.link,
              size: 30,
              color: CupertinoTheme.of(context).primaryColor,
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: resolveColor(context, ClipFlowColors.secondaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
