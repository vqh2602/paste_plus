import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;

import '../../app/theme/app_theme.dart';
export '../../app/theme/app_theme.dart';

class CupertinoSurface extends StatelessWidget {
  const CupertinoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.surface),
        borderRadius: borderRadius,
        border: Border.all(
          color: resolveColor(context, ClipFlowColors.border),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CupertinoPressable extends StatefulWidget {
  const CupertinoPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;

  @override
  State<CupertinoPressable> createState() => _CupertinoPressableState();
}

class _CupertinoPressableState extends State<CupertinoPressable> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: widget.onPressed == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onPressed == null
            ? null
            : () => setState(() => _pressed = false),
        onTapUp: widget.onPressed == null
            ? null
            : (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _pressed ? 0.75 : 1,
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class CupertinoSectionLabel extends StatelessWidget {
  const CupertinoSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: resolveColor(context, ClipFlowColors.secondaryText),
        ),
      ),
    );
  }
}

class CupertinoDivider extends StatelessWidget {
  const CupertinoDivider({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(
        height: 1,
        color: resolveColor(context, ClipFlowColors.border),
      ),
    );
  }
}

class CupertinoChoicePill extends StatelessWidget {
  const CupertinoChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return CupertinoPressable(
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary
              : resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? primary
                : resolveColor(context, ClipFlowColors.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? CupertinoColors.white
                    : resolveColor(context, ClipFlowColors.secondaryText),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? CupertinoColors.white
                    : resolveColor(context, ClipFlowColors.text),
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 6), badge!],
          ],
        ),
      ),
    );
  }
}

class CupertinoIconControl extends StatelessWidget {
  const CupertinoIconControl({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 18,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final control = CupertinoPressable(
      onPressed: onPressed,
      child: Container(
        width: size + 14,
        height: size + 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0x00000000),
        ),
        child: Icon(
          icon,
          size: size,
          color:
              color ??
              (onPressed == null
                  ? resolveColor(
                      context,
                      ClipFlowColors.secondaryText,
                    ).withValues(alpha: 0.4)
                  : resolveColor(context, ClipFlowColors.text)),
        ),
      ),
    );
    final message = tooltip?.trim();
    if (message == null || message.isEmpty) return control;
    return Tooltip(message: message, child: control);
  }
}

class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? const TextStyle(fontSize: 13, height: 1.4);
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matches = <TextSpan>[];
    var start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        matches.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        matches.add(TextSpan(text: text.substring(start, index)));
      }

      final matchText = text.substring(index, index + lowerQuery.length);
      matches.add(
        TextSpan(
          text: matchText,
          style: baseStyle.copyWith(
            backgroundColor: CupertinoColors.systemYellow.withValues(
              alpha: 0.4,
            ),
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      start = index + lowerQuery.length;
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: matches),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

void showCupertinoNotice(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  Timer? removeTimer;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: IgnorePointer(
        child: Center(child: _AnimatedToastNotice(message: message)),
      ),
    ),
  );
  overlay.insert(entry);
  removeTimer = Timer(const Duration(milliseconds: 1800), () {
    removeTimer?.cancel();
    if (entry.mounted) {
      entry.remove();
    }
  });
}

class _AnimatedToastNotice extends StatefulWidget {
  const _AnimatedToastNotice({required this.message});

  final String message;

  @override
  State<_AnimatedToastNotice> createState() => _AnimatedToastNoticeState();
}

class _AnimatedToastNoticeState extends State<_AnimatedToastNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(curve);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(curve);

    _controller.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 1450), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.activeGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
