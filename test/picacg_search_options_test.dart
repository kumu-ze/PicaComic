import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/base_comic.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/pages/search_result_page.dart';
import 'package:pica_comic/pages/picacg/search_options.dart';
import 'package:pica_comic/tools/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    appdata.settings[50] = 'cn';
    await AppTranslation.init();
  });

  Widget page(List<String> initial, ValueChanged<List<String>> onChanged) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PicacgSearchOptions(
              initialValues: initial,
              onChanged: onChanged,
            ),
          ),
        ),
      );

  testWidgets('editing, chip deletion and clear retain the sort', (
    tester,
  ) async {
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

  testWidgets('reopening and external reset preserve the correct values', (
    tester,
  ) async {
    var options = ['vd', 'Science Fiction, 彩色', '草稿'];
    await tester.pumpWidget(page(options, (value) => options = value));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('包含所有标签')))
          .controller!
          .text,
      'Science Fiction, 彩色',
    );
    await tester.pumpWidget(page(['dd'], (value) => options = value));
    expect(find.byType(InputChip), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('排除任一标签')))
          .controller!
          .text,
      '',
    );
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
    await tester.pumpWidget(
      page(['dd', 'Adventure, Science Fiction, 彩色', 'Draft'], (_) {}),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('排除任一标签')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('result-page options survive reopening, cancel and apply', (
    tester,
  ) async {
    final previousSources = ComicSource.sources;
    addTearDown(() => ComicSource.sources = previousSources);
    final requests = <List<String>>[];
    ComicSource.sources = [
      ComicSource.named(
        name: 'picacg',
        key: 'picacg',
        filePath: 'fixture',
        searchPageData: SearchPageData.named(
          searchOptions: [
            SearchOptions.named(
              label: '排序',
              options: LinkedHashMap.of({'dd': '新到旧'}),
            ),
          ],
          customOptionsBuilder: (context, initial, changed) =>
              PicacgSearchOptions(initialValues: initial, onChanged: changed),
          loadPage: (keyword, page, options) async {
            requests.add(List.of(options));
            return const Res<List<BaseComic>>([], subData: 1);
          },
        ),
      ),
    ];
    appdata.settings[25] = '0';
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: App.navigatorKey,
        home: const SearchResultPage(
          keyword: 'fixture',
          sourceKey: 'picacg',
          options: ['ld', 'Adventure, Full Color', 'Draft'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests.last, ['ld', 'Adventure, Full Color', 'Draft']);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('包含所有标签')))
          .controller!
          .text,
      'Adventure, Full Color',
    );
    await tester.enterText(find.byKey(const ValueKey('包含所有标签')), 'Cancelled');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(requests.length, 1);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('包含所有标签')))
          .controller!
          .text,
      'Adventure, Full Color',
    );
    await tester.enterText(
      find.byKey(const ValueKey('包含所有标签')),
      'Updated, Full Color',
    );
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(requests.last, ['ld', 'Updated, Full Color', 'Draft']);
    expect(requests.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
