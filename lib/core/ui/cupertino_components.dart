import 'package:flutter/cupertino.dart';

import '../../features/clipboard_history/domain/search_query.dart';

class ClipFlowColors {
  const ClipFlowColors._();

  static const surface = CupertinoDynamicColor.withBrightness(
    color: CupertinoColors.white,
    darkColor: Color(0xFF1C1D24),
  );
  static const elevatedSurface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF9F9FC),
    darkColor: Color(0xFF25262E),
  );
  static const sidebar = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF4F4F8),
    darkColor: Color(0xFF18191F),
  );
  static const border = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE2E2E8),
    darkColor: Color(0xFF383942),
  );
  static const secondaryText = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF707078),
    darkColor: Color(0xFFA6A6AF),
  );
}

Color resolveColor(BuildContext context, Color color) =>
    CupertinoDynamicColor.resolve(color, context);

class CupertinoDivider extends StatelessWidget {
  const CupertinoDivider({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: resolveColor(context, ClipFlowColors.border)),
      ),
    );
  }
}

class CupertinoSurface extends StatelessWidget {
  const CupertinoSurface({
    super.key,
    required this.child,
    this.padding,
    this.color = ClipFlowColors.surface,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final BorderRadius borderRadius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolveColor(context, color),
        borderRadius: borderRadius,
        border: border
            ? Border.all(color: resolveColor(context, ClipFlowColors.border))
            : null,
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
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

class CupertinoIconControl extends StatelessWidget {
  const CupertinoIconControl({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 20,
    this.padding = const EdgeInsets.all(8),
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: padding,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Icon(icon, size: size, color: color),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return CupertinoPressable(
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.14)
              : resolveColor(context, ClipFlowColors.elevatedSurface),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.65)
                : resolveColor(context, ClipFlowColors.border),
            width: selected ? 1.2 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? primary : null),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? primary : null,
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 9),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class StaggeredAnimatedItem extends StatefulWidget {
  const StaggeredAnimatedItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 30),
    this.slideOffset = const Offset(0, 0.08),
  });

  final int index;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;
  final Offset slideOffset;

  @override
  State<StaggeredAnimatedItem> createState() => _StaggeredAnimatedItemState();
}

class _StaggeredAnimatedItemState extends State<StaggeredAnimatedItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(curved);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(curved);

    final delay = widget.staggerDelay * widget.index.clamp(0, 10);
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

void showCupertinoNotice(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      bottom: 32,
      child: IgnorePointer(
        child: Center(
          child: _AnimatedToastNotice(message: message),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1800), entry.remove);
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(curve);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(curve);

    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1450), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
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
                  Icon(
                    CupertinoIcons.checkmark_alt_circle_fill,
                    size: 18,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 14,
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

class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty || text.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }

    final terms = ClipboardSearchQuery.parse(query)
        .terms
        .where((t) => t.trim().isNotEmpty)
        .toList();

    if (terms.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }

    final lowerText = text.toLowerCase();
    final matches = <_MatchRange>[];

    for (final term in terms) {
      final lowerTerm = term.toLowerCase();
      int start = 0;
      while (start < text.length) {
        final index = lowerText.indexOf(lowerTerm, start);
        if (index == -1) break;
        matches.add(_MatchRange(index, index + lowerTerm.length));
        start = index + lowerTerm.length;
      }
    }

    if (matches.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_MatchRange>[];
    for (final m in matches) {
      if (merged.isEmpty) {
        merged.add(m);
      } else {
        final last = merged.last;
        if (m.start <= last.end) {
          merged[merged.length - 1] = _MatchRange(
            last.start,
            m.end > last.end ? m.end : last.end,
          );
        } else {
          merged.add(m);
        }
      }
    }

    final baseStyle = style ?? const TextStyle();
    const highlightBg = Color(0xFFFFD600); // Bright yellow highlight
    const highlightFg = Color(0xFF18191F); // Dark contrasting text

    final spans = <TextSpan>[];
    int current = 0;

    for (final range in merged) {
      if (range.start > current) {
        spans.add(
          TextSpan(
            text: text.substring(current, range.start),
            style: baseStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: baseStyle.copyWith(
            backgroundColor: highlightBg,
            color: highlightFg,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      current = range.end;
    }

    if (current < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(current),
          style: baseStyle,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class _MatchRange {
  const _MatchRange(this.start, this.end);
  final int start;
  final int end;
}


