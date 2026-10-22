import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/network/base_comic.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/tools/translations.dart';

class FixturePage extends ComicsPage<BaseComic> {
  const FixturePage(this.loader, {super.key});
  final Future<Res<List<BaseComic>>> Function(int) loader;
  @override
  String? get title => null;
  @override
  String get sourceKey => 'picacg';
  @override
  String get tag => 'filtered-pagination-test';
  @override
  bool get manualPageLoading => true;
  @override
  Future<Res<List<BaseComic>>> getComics(int page) => loader(page);
  @override
  Widget buildItem(BuildContext context, BaseComic item) => Text(item.title);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    appdata.settings[50] = 'cn';
    await AppTranslation.init();
  });

  test('an empty first page retains the source page count', () async {
    final logic = ComicsPageLogic<String>(preserveEmptyPages: true);
    await logic.get((_) async => const Res([], subData: 3));
    expect(logic.maxPage, 3);
    await logic.loadNextPage((_) async => const Res([], subData: 3));
    await logic.loadNextPage((_) async => const Res(['match'], subData: 3));
    expect(logic.comics, ['match']);
    expect(logic.current, 3);
    expect(logic.dividedComics![1], isEmpty);
    expect(logic.dividedComics![2], isEmpty);
    logic.refresh();
    expect(logic.current, 1);
    expect(logic.maxPage, isNull);
    expect(logic.dividedComics, isNull);
  });

  test('ordinary empty search keeps the legacy stop behavior', () async {
    final logic = ComicsPageLogic<String>();
    await logic.get((_) async => const Res([], subData: 4));
    expect(logic.maxPage, 1);
  });

  testWidgets('a failed page is retried without skipping it', (tester) async {
    final requested = <int>[];
    final logic = ComicsPageLogic<String>(preserveEmptyPages: true);
    await logic.get((_) async => const Res([], subData: 3));
    await logic.loadNextPage((page) async {
      requested.add(page);
      return const Res.error('offline');
    });
    expect(logic.current, 1);
    await logic.loadNextPage((page) async {
      requested.add(page);
      return const Res(['match'], subData: 3);
    });
    expect(requested, [2, 2]);
    expect(logic.current, 2);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final mode in ['0', '1']) {
    testWidgets('empty pages remain navigable in list mode $mode', (
      tester,
    ) async {
      appdata.settings[25] = mode;
      appdata.settings[64] = '0';
      appdata.appSettings.fullyHideBlockedWorks = false;
      final requested = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixturePage((page) async {
              requested.add(page);
              return Res(
                page == 3
                    ? [
                        const CustomComic(
                          'Fixture match',
                          '',
                          '',
                          '1',
                          [],
                          '',
                          'picacg',
                        ),
                      ]
                    : <BaseComic>[],
                subData: 3,
              );
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, [1]);
      final next = find.text(mode == '0' ? '继续筛选下一页' : '下一页');
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(requested, [1, 2]);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(requested, [1, 2, 3]);
      expect(find.text('Fixture match'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
