import 'package:flutter/cupertino.dart';

class SearchSyntaxField extends StatefulWidget {
  const SearchSyntaxField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  State<SearchSyntaxField> createState() => _SearchSyntaxFieldState();
}

class _SearchSyntaxFieldState extends State<SearchSyntaxField> {
  static const _suggestions = ['app:', 'note:', 'type:', 'is:pinned', 'after:'];

  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  double _fieldWidth = 280;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
    widget.controller.addListener(_refreshOverlay);
  }

  @override
  void didUpdateWidget(SearchSyntaxField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshOverlay);
      widget.controller.addListener(_refreshOverlay);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    widget.controller.removeListener(_refreshOverlay);
    _removeOverlay();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _refreshOverlay() => _overlayEntry?.markNeedsBuild();

  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) _fieldWidth = box.size.width;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  Widget _buildOverlay(BuildContext context) {
    final colors = CupertinoTheme.of(context);
    return Positioned.fill(
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 5),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            key: const Key('search-syntax-suggestions'),
            width: _fieldWidth.clamp(220, 430),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBackground,
                context,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.separator,
                  context,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final suggestion in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CupertinoButton(
                        key: Key('search-suggestion-$suggestion'),
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        color: colors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                        onPressed: () => _insertSuggestion(suggestion),
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: colors.primaryColor,
                          ),
                        ),
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

  void _insertSuggestion(String suggestion) {
    final value = widget.controller.value;
    final cursor = value.selection.isValid
        ? value.selection.baseOffset.clamp(0, value.text.length)
        : value.text.length;
    final before = value.text.substring(0, cursor);
    final tokenStart = before.lastIndexOf(RegExp(r'\s')) + 1;
    final currentToken = before.substring(tokenStart);
    final replaceCurrent =
        currentToken.isEmpty ||
        _suggestions.any((item) => item.startsWith(currentToken.toLowerCase()));
    final start = replaceCurrent ? tokenStart : cursor;
    final prefix = !replaceCurrent && cursor > 0 && !before.endsWith(' ')
        ? ' '
        : '';
    final inserted = '$prefix$suggestion';
    final text = value.text.replaceRange(start, cursor, inserted);
    final nextCursor = start + inserted.length;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    widget.onChanged(text);
    widget.focusNode.requestFocus();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: CupertinoSearchTextField(
        key: widget.fieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        placeholder: widget.placeholder,
        onChanged: widget.onChanged,
      ),
    );
  }
}
