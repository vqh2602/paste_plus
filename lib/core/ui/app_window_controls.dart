import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

/// Renders native window control buttons (Minimize, Maximize/Restore, Close)
/// for Windows & Linux platforms where `TitleBarStyle.hidden` strips system window controls.
class AppWindowControls extends StatefulWidget {
  const AppWindowControls({
    super.key,
    this.brightness,
  });

  final Brightness? brightness;

  @override
  State<AppWindowControls> createState() => _AppWindowControlsState();
}

class _AppWindowControlsState extends State<AppWindowControls> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux) {
      _checkMaximized();
    }
  }

  Future<void> _checkMaximized() async {
    final max = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = max;
      });
    }
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _checkMaximized();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final isDark =
        (widget.brightness ?? CupertinoTheme.of(context).brightness) ==
            Brightness.dark;
    final iconColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final hoverBg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : CupertinoColors.black.withValues(alpha: 0.08);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minimize Button
        _WindowControlButton(
          icon: CupertinoIcons.minus,
          iconColor: iconColor,
          hoverColor: hoverBg,
          onPressed: () => windowManager.minimize(),
        ),
        // Maximize/Restore Button
        _WindowControlButton(
          icon: _isMaximized
              ? CupertinoIcons.square_on_square
              : CupertinoIcons.square,
          iconColor: iconColor,
          hoverColor: hoverBg,
          onPressed: _toggleMaximize,
        ),
        // Close Button
        _WindowControlButton(
          icon: CupertinoIcons.xmark,
          iconColor: iconColor,
          hoverColor: CupertinoColors.systemRed,
          hoverIconColor: CupertinoColors.white,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.iconColor,
    required this.hoverColor,
    required this.onPressed,
    this.hoverIconColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color hoverColor;
  final Color? hoverIconColor;
  final VoidCallback onPressed;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeIconColor = (_isHovered && widget.hoverIconColor != null)
        ? widget.hoverIconColor!
        : widget.iconColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 44,
          height: 38,
          color: _isHovered ? widget.hoverColor : CupertinoColors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 13,
            color: activeIconColor,
          ),
        ),
      ),
    );
  }
}

/// A drag-to-move header title bar for Windows/Linux with title & window controls.
class AppWindowHeader extends StatelessWidget {
  const AppWindowHeader({
    super.key,
    this.title,
    this.leading,
    this.height = 38.0,
    this.showTitle = true,
  });

  final String? title;
  final Widget? leading;
  final double height;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final displayTitle = title ?? 'ClipFlow';

    return DragToMoveArea(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (leading != null) ...[
              const SizedBox(width: 12),
              leading!,
            ],
            if (showTitle) ...[
              Padding(
                padding: EdgeInsets.only(left: leading != null ? 8.0 : 14.0),
                child: Text(
                  displayTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
            const Spacer(),
            const AppWindowControls(),
          ],
        ),
      ),
    );
  }
}
