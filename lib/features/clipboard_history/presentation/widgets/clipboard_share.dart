import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/clipboard_item.dart';

Future<bool> shareClipboardItem(
  BuildContext context,
  ClipboardItem item,
) async {
  final path = item.imagePath;
  final imageFile = path == null ? null : File(path);
  final files = <XFile>[
    if (imageFile != null && imageFile.existsSync()) XFile(imageFile.path),
  ];
  final text = item.content.trim();
  if (files.isEmpty && text.isEmpty) return false;

  final renderBox = context.findRenderObject() as RenderBox?;
  final origin = renderBox == null
      ? null
      : renderBox.localToGlobal(Offset.zero) & renderBox.size;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text.isEmpty ? null : text,
        files: files,
        sharePositionOrigin: origin,
      ),
    );
    return true;
  } on Object {
    return false;
  }
}
