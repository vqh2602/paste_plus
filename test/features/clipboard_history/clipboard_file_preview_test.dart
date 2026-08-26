import 'dart:io';

import 'package:clipflow/features/clipboard_history/presentation/widgets/clipboard_file_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('parses file URIs and reports the combined size', () {
    final directory = Directory.systemTemp.createTempSync(
      'clipflow-file-preview-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final first = File('${directory.path}/first.txt')
      ..writeAsStringSync('hello');
    final second = File('${directory.path}/second.txt')
      ..writeAsStringSync('world!');
    final content = '${first.uri}\n${second.path}';

    expect(clipboardFilePaths(content), [first.path, second.path]);
    expect(firstExistingClipboardFilePath(content), first.path);
    expect(clipboardFilesSize(content), 11);
    expect(formatFileSize(11), '11 B');
    expect(formatFileSize(1536), '1.50 KB');
    expect(formatFileSize(10 * 1024 * 1024), '10.0 MB');
  });

  testWidgets('renders image files as the file preview', (tester) async {
    final path =
        '${Directory.current.path}/assets/branding/clipflow_app_icon.png';

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ClipboardFilePreview(content: path, height: 240),
        ),
      ),
    );

    expect(find.byKey(const Key('clipboard-file-preview')), findsOneWidget);
    expect(
      find.byKey(const Key('clipboard-file-preview-image')),
      findsOneWidget,
    );
  });

  testWidgets('shows a file-type fallback when the file no longer exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: ClipboardFilePreview(
            content: '/missing/report.pdf',
            height: 240,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('clipboard-file-preview-fallback')),
      findsOneWidget,
    );
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
  });

  testWidgets('renders a folder icon for a copied directory path', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'clipflow-folder-preview-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ClipboardFilePreview(content: directory.path, height: 240),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('clipboard-file-preview-folder-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('clipboard-file-preview-document-icon')),
      findsNothing,
    );
    expect(find.text(p.basename(directory.path)), findsOneWidget);
  });
}
