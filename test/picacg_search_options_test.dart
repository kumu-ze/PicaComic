import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/pages/picacg/search_options.dart';
import 'package:pica_comic/tools/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    appdata.settings[50] = 'cn';
    await AppTranslation.init();
  });

  Widget page(List<String> initial, ValueChanged<List<String>> onChanged) =>
      MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: PicacgSearchOptions(initialValues: initial, onChanged: onChanged),
      )));

  testWidgets('editing, chip deletion and clear retain the sort', (tester) async {
    var options = ['ld', '', ''];
    await tester.pumpWidget(page(options, (value) => options = value));
    await tester.enterText(find.byKey(const ValueKey('包含所有标签')), '冒险，彩色');
    await tester.pump();
    expect(find.widgetWithText(InputChip, '冒险'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '彩色'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('排除任一标签')), '草稿');
    await tester.pump();
    expect(options, ['ld', '冒险，彩色', '草稿']);
    final chip = tester.widget<InputChip>(find.widgetWithText(InputChip, '冒险'));
    chip.onDeleted!();
    await tester.pump();
    expect(options, ['ld', '彩色', '草稿']);
    await tester.tap(find.text('清除标签'));
    await tester.pump();
    expect(options, ['ld', '', '']);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('reopening and external reset preserve the correct values', (tester) async {
    var options = ['vd', 'Science Fiction, 彩色', '草稿'];
    await tester.pumpWidget(page(options, (value) => options = value));
    expect(tester.widget<TextField>(find.byKey(const ValueKey('包含所有标签'))).controller!.text,
        'Science Fiction, 彩色');
    await tester.pumpWidget(page(['dd'], (value) => options = value));
    expect(find.byType(InputChip), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('排除任一标签'))).controller!.text, '');
  });

  testWidgets('conflicting tags show an explanation', (tester) async {
    await tester.pumpWidget(page(['dd', 'Adventure', 'adventure'], (_) {}));
    expect(find.text('同一标签同时被包含和排除，不会有匹配结果'), findsOneWidget);
  });

  testWidgets('narrow viewport scrolls without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(page(['dd', 'Adventure, Science Fiction, 彩色', 'Draft'], (_) {}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('排除任一标签')));
    expect(tester.takeException(), isNull);
  });
}
