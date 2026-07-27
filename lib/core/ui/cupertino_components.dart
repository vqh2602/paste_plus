import 'package:flutter/cupertino.dart';

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
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 90),
          opacity: _pressed ? 0.55 : 1,
          child: widget.child,
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
        duration: const Duration(milliseconds: 160),
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
          ),
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

void showCupertinoNotice(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      bottom: 28,
      child: IgnorePointer(
        child: Center(
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1400), entry.remove);
}
