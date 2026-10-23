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
  const FixturePage(this.loader, {super.key, this.filtered = false});
  final bool filtered;
  @override
  bool get autoLoadFilteredPages => filtered;
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

  Future<void> mountFiltered(WidgetTester tester,
      Future<Res<List<BaseComic>>> Function(int) loader) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FixturePage(loader, filtered: true))));
    await tester.pump();
    await tester.pump();
  }

  Future<void> tick(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
    }
  }

  testWidgets(
      'compatibility skips empty pages, fills viewport then waits for scrolling',
      (tester) async {
    final requested = <int>[];
    await mountFiltered(tester, (page) async {
      requested.add(page);
      return Res(page <= 2 || page == 4 ? <BaseComic>[] : comics(page),
          subData: 5);
    });
    await tick(tester, 5);
    expect(requested, [1, 2, 3]);
    expect(find.text('无匹配结果'), findsNothing);
    await tester.tap(find.byType(CustomScrollView));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tick(tester, 6);
    expect(requested, [1, 2, 3, 4, 5]);
    expect(
        StateController.find<ComicsPageLogic<BaseComic>>(
                tag: 'native-pagination-test')
            .comics!
            .length,
        40);
    expect(find.text('继续筛选下一页'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'compatibility only declares no matches after exhausting source pages',
      (tester) async {
    final requested = <int>[];
    await mountFiltered(tester, (page) async {
      requested.add(page);
      return const Res<List<BaseComic>>([], subData: 6);
    });
    expect(find.text('无匹配结果'), findsNothing);
    await tick(tester, 9);
    expect(requested, [1, 2, 3, 4, 5, 6]);
    expect(find.text('无匹配结果'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'empty compatibility pages pause on error and retry without skipping',
      (tester) async {
    final requested = <int>[];
    var fail = true;
    await mountFiltered(tester, (page) async {
      requested.add(page);
      if (page == 2 && fail) return const Res.error('offline');
      return Res(page < 3 ? <BaseComic>[] : comics(page), subData: 3);
    });
    await tick(tester, 4);
    expect(requested, [1, 2]);
    fail = false;
    await tester.tap(find.text('重试'));
    await tick(tester, 4);
    expect(requested, [1, 2, 2, 3]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'hidden routes and background apps pause scanning; disposal stops it',
      (tester) async {
    final requested = <int>[];
    await mountFiltered(tester, (page) async {
      requested.add(page);
      return const Res<List<BaseComic>>([], subData: 100);
    });
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')))));
    await tester.pump();
    await tick(tester, 4);
    expect(requested, [1]);
    navigator.pop();
    await tester.pump();
    await tick(tester, 3);
    expect(requested.length, greaterThan(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final pausedCount = requested.length;
    await tick(tester, 3);
    expect(requested.length, pausedCount);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tick(tester, 3);
    expect(requested.length, greaterThan(pausedCount));
    await tester.pumpWidget(const SizedBox());
    final disposedCount = requested.length;
    await tick(tester, 3);
    expect(requested.length, disposedCount);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit paginated browsing can leave an empty filtered page',
      (tester) async {
    appdata.settings[25] = '1';
    final requested = <int>[];
    await mountFiltered(tester, (page) async {
      requested.add(page);
      return Res(page == 1 ? <BaseComic>[] : comics(page), subData: 2);
    });
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(requested, [1, 2]);
    expect(find.text('Book 2-0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('refresh and cancellation ignore stale in-flight responses', () async {
    final logic = ComicsPageLogic<String>(preserveEmptyPages: true);
    await logic.get((_) async => const Res([], subData: 3));
    final stale = Completer<Res<List<String>>>();
    final oldRequest = logic.loadNextPage((_) => stale.future);
    logic.refresh();
    await logic.get((_) async => const Res(['new'], subData: 2));
    stale.complete(const Res(['stale'], subData: 3));
    await oldRequest;
    expect(logic.current, 1);
    expect(logic.comics, ['new']);
    expect(logic.loadingData, isFalse);
    final afterDispose = Completer<Res<List<String>>>();
    final pending = logic.loadNextPage((_) => afterDispose.future);
    logic.cancelRequests();
    afterDispose.complete(const Res(['too late'], subData: 2));
    await pending;
    expect(logic.comics, ['new']);
  });

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
