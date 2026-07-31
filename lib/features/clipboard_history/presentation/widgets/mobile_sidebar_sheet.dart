import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../domain/clipboard_item.dart';
import '../history_controller.dart';
import 'sidebar_widget.dart';

class MobileSidebarSheet extends StatelessWidget {
  const MobileSidebarSheet({
    super.key,
    required this.state,
    required this.collections,
    required this.onOpenSettings,
    required this.onCreateCollection,
    required this.onDeleteCollection,
  });

  final ClipboardHistoryState state;
  final List<ClipboardCollection> collections;
  final VoidCallback onOpenSettings;
  final VoidCallback onCreateCollection;
  final ValueChanged<ClipboardCollection> onDeleteCollection;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: ClipRRect(
            key: const Key('mobile-sidebar-sheet'),
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: math.min(420, math.max(0, size.width - 24)),
              height: math.min(620, size.height * 0.78),
              child: SidebarWidget(
                state: state,
                collections: collections,
                onNavigationSelected: () => Navigator.pop(context),
                onOpenSettings: () {
                  Navigator.pop(context);
                  onOpenSettings();
                },
                onCreateCollection: onCreateCollection,
                onDeleteCollection: onDeleteCollection,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
