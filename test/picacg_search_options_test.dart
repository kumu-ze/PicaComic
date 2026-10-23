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

  testWidgets('compatibility toggle retains tags and native categories',
      (tester) async {
    var selected = options('ld', ['全彩']);
    await tester.pumpWidget(page(selected, (value) => selected = value));
    final toggle = find.byKey(const ValueKey('picacg-compatibility-mode'));
    final include = find.byKey(const ValueKey('picacg-include-tags'));
    final exclude = find.byKey(const ValueKey('picacg-exclude-tags'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(include, 'Space Opera, Robots');
    await tester.enterText(exclude, 'Draft');
    await tester.pump();
    var filters = PicacgSearchFilters.fromOptions(selected);
    expect(filters.compatibilityMode, isTrue);
    expect(filters.includedTags, ['Space Opera', 'Robots']);
    expect(filters.excludedTags, ['Draft']);
    expect(filters.categories, ['全彩']);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    filters = PicacgSearchFilters.fromOptions(selected);
    expect(filters.hasLocalFilters, isFalse);
    expect(filters.includedTags, ['Space Opera', 'Robots']);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(include).controller!.text,
        'Space Opera, Robots');
    await tester.enterText(exclude, 'robots');
    await tester.pump();
    expect(find.text('同一标签不能同时包含和排除'), findsOneWidget);
    await tester.ensureVisible(find.text('清除标签'));
    await tester.tap(find.text('清除标签'));
    await tester.pump();
    filters = PicacgSearchFilters.fromOptions(selected);
    expect(filters.hasLocalFilters, isFalse);
    expect(filters.categories, ['全彩']);
    expect(filters.sort, 'ld');
  });

  testWidgets('batch selection survives mode toggling and external restore',
      (tester) async {
    var selected =
        PicacgSearchFilters(compatibilityMode: true, includeTags: 'Robots')
            .toOptions();
    await tester.pumpWidget(page(selected, (value) => selected = value));
    Finder batch(int pages) =>
        find.byKey(ValueKey('picacg-concurrent-pages-$pages'));
    expect(tester.widget<ChoiceChip>(batch(5)).selected, isTrue);
    await tester.ensureVisible(batch(8));
    await tester.tap(batch(8));
    await tester.pump();
    expect(PicacgSearchFilters.fromOptions(selected).concurrentPages, 8);
    final toggle = find.byKey(const ValueKey('picacg-compatibility-mode'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(batch(8), findsNothing);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(batch(8)).selected, isTrue);
    await tester.pumpWidget(page(
        PicacgSearchFilters(compatibilityMode: true, concurrentPages: 3)
            .toOptions(),
        (_) {}));
    expect(tester.widget<ChoiceChip>(batch(3)).selected, isTrue);
  });

  testWidgets(
      'compatibility controls fit a narrow screen and restore external changes',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(page(
        PicacgSearchFilters(
          compatibilityMode: true,
          includeTags: 'Robots',
          excludeTags: 'Draft',
        ).toOptions(),
        (_) {}));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('picacg-exclude-tags')));
    await tester
        .ensureVisible(category(PicacgSearchFilters.availableCategories.last));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(page(['dd'], (_) {}));
    expect(find.byType(TextField), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('picacg-compatibility-mode')));
    await tester.tap(find.byKey(const ValueKey('picacg-compatibility-mode')));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('picacg-include-tags')))
            .controller!
            .text,
        '');
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
    final optionRequests = <PicacgSearchFilters>[];
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
            optionRequests.add(PicacgSearchFilters.fromOptions(values));
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
    final toggle = find.byKey(const ValueKey('picacg-compatibility-mode'));
    final include = find.byKey(const ValueKey('picacg-include-tags'));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(include, 'Robots, Space Opera');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(include, 'Robots, Space Opera');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(requests.length, 3);
    expect(requests.last['keyword'], 'fixture title');
    expect(optionRequests.last.compatibilityMode, isTrue);
    expect(optionRequests.last.includedTags, ['Robots', 'Space Opera']);
    expect(optionRequests.last.categories, ['全彩', '短篇']);
    expect(find.text('继续筛选下一页'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
