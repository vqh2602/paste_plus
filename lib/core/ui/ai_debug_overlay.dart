import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/providers.dart';
import '../localization/localization_extensions.dart';
import '../services/ai_debug_service.dart';
import 'cupertino_components.dart';

class AiDebugOverlay extends ConsumerStatefulWidget {
  const AiDebugOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AiDebugOverlay> createState() => _AiDebugOverlayState();
}

class _AiDebugOverlayState extends ConsumerState<AiDebugOverlay> {
  static const _buttonSize = 46.0;
  Offset? _position;
  var _showPanel = false;

  @override
  Widget build(BuildContext context) {
    final debugState = ref.watch(aiDebugControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maximumX = (constraints.maxWidth - _buttonSize).clamp(
          0.0,
          double.infinity,
        );
        final maximumY = (constraints.maxHeight - _buttonSize).clamp(
          0.0,
          double.infinity,
        );
        final current = _position ?? Offset(maximumX - 16, 72);
        final position = Offset(
          current.dx.clamp(0.0, maximumX),
          current.dy.clamp(0.0, maximumY),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (debugState.isEnabled && !_showPanel)
              Positioned(
                left: position.dx,
                top: position.dy,
                child: _DebugFloatingButton(
                  entryCount: debugState.entries.length,
                  onTap: () => setState(() => _showPanel = true),
                  onDrag: (delta) {
                    setState(() {
                      _position = Offset(
                        (position.dx + delta.dx).clamp(0.0, maximumX),
                        (position.dy + delta.dy).clamp(0.0, maximumY),
                      );
                    });
                  },
                ),
              ),
            if (debugState.isEnabled && _showPanel)
              _DebugLogPanel(
                entries: debugState.entries,
                onClose: () => setState(() => _showPanel = false),
                onClear: () =>
                    ref.read(aiDebugControllerProvider.notifier).clear(),
                onCopy: () async {
                  final text = ref
                      .read(aiDebugControllerProvider.notifier)
                      .exportText();
                  await Clipboard.setData(ClipboardData(text: text));
                },
                onDisable: () {
                  setState(() => _showPanel = false);
                  ref.read(aiDebugControllerProvider.notifier).disable();
                },
              ),
          ],
        );
      },
    );
  }
}

class _DebugFloatingButton extends StatelessWidget {
  const _DebugFloatingButton({
    required this.entryCount,
    required this.onTap,
    required this.onDrag,
  });

  final int entryCount;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.ai_debug_open_log,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onPanUpdate: (details) => onDrag(details.delta),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _AiDebugOverlayState._buttonSize,
                height: _AiDebugOverlayState._buttonSize,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemIndigo,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.white.withValues(alpha: 0.75),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const FaIcon(
                  FontAwesomeIcons.bug,
                  size: 19,
                  color: CupertinoColors.white,
                ),
              ),
              if (entryCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 19),
                    height: 19,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entryCount > 99 ? '99+' : '$entryCount',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugLogPanel extends StatelessWidget {
  const _DebugLogPanel({
    required this.entries,
    required this.onClose,
    required this.onClear,
    required this.onCopy,
    required this.onDisable,
  });

  final List<AiDebugEntry> entries;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 820,
                  maxHeight: 620,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CupertinoSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.bug,
                                    size: 16,
                                    color: CupertinoColors.systemIndigo,
                                  ),
                                  const SizedBox(width: 9),
                                  const Text(
                                    'AI Debug',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${entries.length} log',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: resolveColor(
                                        context,
                                        ClipFlowColors.secondaryText,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  CupertinoButton(
                                    padding: const EdgeInsets.all(6),
                                    minimumSize: const Size(34, 34),
                                    onPressed: onClose,
                                    child: const Icon(
                                      CupertinoIcons.xmark,
                                      size: 17,
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                alignment: WrapAlignment.end,
                                children: [
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(34, 34),
                                    onPressed: onCopy,
                                    child: Text(context.l10n.copy),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(34, 34),
                                    onPressed: onClear,
                                    child: Text(
                                      context.l10n.ai_debug_clear_log,
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(34, 34),
                                    onPressed: onDisable,
                                    child: Text(
                                      context.l10n.ai_debug_disable,
                                      style: const TextStyle(
                                        color: CupertinoColors.systemRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const CupertinoDivider(),
                        Expanded(
                          child: entries.isEmpty
                              ? Center(
                                  child: Text(
                                    context.l10n.ai_debug_no_logs,
                                  ),
                                )
                              : CupertinoScrollbar(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    reverse: true,
                                    itemCount: entries.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final entry =
                                          entries[entries.length - index - 1];
                                      return _DebugLogEntry(entry: entry);
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugLogEntry extends StatelessWidget {
  const _DebugLogEntry({required this.entry});

  final AiDebugEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      AiDebugLevel.info => CupertinoColors.activeBlue,
      AiDebugLevel.success => CupertinoColors.activeGreen,
      AiDebugLevel.warning => CupertinoColors.systemOrange,
      AiDebugLevel.error => CupertinoColors.systemRed,
    };
    final request = entry.requestId == null ? '' : ' · ${entry.requestId}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.elevatedSurface),
        borderRadius: BorderRadius.circular(9),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.timestamp.toIso8601String()} · ${entry.stage}$request',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            entry.message,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (entry.details?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            SelectableText(
              entry.details!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
