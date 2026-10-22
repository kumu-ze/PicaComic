import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/base_comic.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/network/picacg_network/search_filters.dart';
import 'package:pica_comic/pages/search_result_page.dart';
import 'package:pica_comic/pages/picacg/search_options.dart';
import 'package:pica_comic/tools/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    appdata.settings[50] = 'cn';
    await AppTranslation.init();
  });
  List<String> options(String sort, List<String> categories) =>
      PicacgSearchFilters(sort: sort, categories: categories).toOptions();
  Finder category(String name) => find.byKey(ValueKey('picacg-category-$name'));
  Widget page(List<String> initial, ValueChanged<List<String>> onChanged) =>
      MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PicacgSearchOptions(
          initialValues: initial,
          onChanged: onChanged,
        ))),
      );

  testWidgets('multiple categories toggle and clear without losing sort',
      (tester) async {
    var selected = options('ld', []);
    await tester.pumpWidget(page(selected, (value) => selected = value));
    await tester.tap(category('全彩'));
    await tester.pump();
    await tester.tap(category('短篇'));
    await tester.pump();
    expect(PicacgSearchFilters.fromOptions(selected).categories, ['全彩', '短篇']);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(category('全彩'));
    await tester.pump();
    expect(PicacgSearchFilters.fromOptions(selected).categories, ['短篇']);
    await tester.tap(find.text('清除分类'));
    await tester.pump();
    expect(selected, options('ld', []));
  });

  testWidgets(
      'restored and externally reset categories are displayed correctly',
      (tester) async {
    await tester.pumpWidget(page(options('vd', ['全彩']), (_) {}));
    expect(tester.widget<FilterChip>(category('全彩')).selected, isTrue);
    await tester.pumpWidget(page(['dd'], (_) {}));
    expect(tester.widget<FilterChip>(category('全彩')).selected, isFalse);
  });

  testWidgets('category options fit a narrow screen and can scroll',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(page(options('dd', ['全彩']), (_) {}));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(category(PicacgSearchFilters.availableCategories.last));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'native result page preserves keyword and applies or cancels category changes',
      (tester) async {
    final previousSources = ComicSource.sources;
    addTearDown(() => ComicSource.sources = previousSources);
    final requests = <Map<String, dynamic>>[];
    ComicSource.sources = [
      ComicSource.named(
        name: 'picacg',
        key: 'picacg',
        filePath: 'fixture',
        searchPageData: SearchPageData.named(
          searchOptions: [
            SearchOptions.named(
                label: '排序', options: LinkedHashMap.of({'dd': '新到旧'}))
          ],
          customOptionsBuilder: (context, initial, changed) =>
              PicacgSearchOptions(initialValues: initial, onChanged: changed),
          loadPage: (keyword, page, values) async {
            requests.add(
                PicacgSearchFilters.fromOptions(values).toRequest(keyword));
            return const Res<List<BaseComic>>([], subData: 1);
          },
        ),
      )
    ];
    appdata.settings[25] = '0';
    await tester.pumpWidget(MaterialApp(
      navigatorKey: App.navigatorKey,
      home: SearchResultPage(
          keyword: 'fixture title',
          sourceKey: 'picacg',
          options: options('ld', ['全彩'])),
    ));
    await tester.pumpAndSettle();
    expect(requests.single, {
      'keyword': 'fixture title',
      'sort': 'ld',
      'categories': ['全彩']
    });
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(category('全彩')).selected, isTrue);
    await tester.tap(category('短篇'));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(requests.length, 1);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(category('短篇')).selected, isFalse);
    await tester.tap(category('短篇'));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(requests.last, {
      'keyword': 'fixture title',
      'sort': 'ld',
      'categories': ['全彩', '短篇']
    });
    expect(requests.length, 2);
    expect(find.text('继续筛选下一页'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
