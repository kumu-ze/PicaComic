import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/state_controller.dart';
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
  String get tag => 'native-pagination-test';
  @override
  Future<Res<List<BaseComic>>> getComics(int page) => loader(page);
  @override
  Widget buildItem(BuildContext context, BaseComic item) => Text(item.title);
}

List<BaseComic> comics(int page) => List.generate(20,
    (i) => CustomComic('Book $page-$i', '', '', '$page-$i', [], '', 'picacg'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    appdata.settings[50] = 'cn';
    await AppTranslation.init();
  });
  setUp(() {
    appdata.settings[25] = '0';
    appdata.settings[44] = '0,1.0';
    appdata.settings[64] = '0';
    appdata.appSettings.fullyHideBlockedWorks = false;
  });
  Future<void> mount(WidgetTester tester,
      Future<Res<List<BaseComic>>> Function(int) loader) async {
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: FixturePage(loader))));
    await tester.pumpAndSettle();
    // The test host is Windows: switch its smooth scroller to touch input.
    await tester.tap(find.byType(CustomScrollView));
    await tester.pump();
  }

  testWidgets('scrolling to the end automatically appends the next native page',
      (tester) async {
    final requested = <int>[];
    await mount(tester, (page) async {
      requested.add(page);
      return Res(comics(page), subData: 2);
    });
    expect(requested, [1]);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(requested, [1, 2]);
    final logic = StateController.find<ComicsPageLogic<BaseComic>>(
        tag: 'native-pagination-test');
    expect(logic.comics!.length, 40);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(requested, [1, 2]);
    expect(find.text('继续筛选下一页'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed auto loading pauses and retry requests the same page',
      (tester) async {
    final requested = <int>[];
    var fail = true;
    await mount(tester, (page) async {
      requested.add(page);
      if (page == 2 && fail) return const Res.error('offline');
      return Res(comics(page), subData: 2);
    });
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(requested, [1, 2]);
    fail = false;
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(requested, [1, 2, 2]);
    expect(
        StateController.find<ComicsPageLogic<BaseComic>>(
                tag: 'native-pagination-test')
            .comics!
            .length,
        40);
    await tester.pumpWidget(const SizedBox());
  });

  test('only one next-page request can be in flight and refresh resets paging',
      () async {
    final logic = ComicsPageLogic<String>();
    await logic.get((_) async => const Res(['first'], subData: 3));
    final response = Completer<Res<List<String>>>();
    var calls = 0;
    Future<Res<List<String>>> loader(int page) {
      calls++;
      return response.future;
    }

    final loading = logic.loadNextPage(loader);
    await logic.loadNextPage(loader);
    expect(calls, 1);
    response.complete(const Res(['second'], subData: 3));
    await loading;
    expect(logic.current, 2);
    expect(logic.comics, ['first', 'second']);
    logic.refresh();
    expect(logic.current, 1);
    expect(logic.comics, isNull);
    expect(logic.maxPage, isNull);
    expect(logic.dividedComics, isNull);
  });
}
