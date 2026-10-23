part of 'components.dart';

class ComicsPageLogic<T> extends StateController {
  ComicsPageLogic({this.preserveEmptyPages = false, int pageBatchSize = 1})
      : pageBatchSize = pageBatchSize.clamp(1, 8);

  final bool preserveEmptyPages;
  final int pageBatchSize;
  final _pendingPages = <int, Res<List<T>>>{};
  int? _retryBatchEnd;
  int _generation = 0;
  bool _disposed = false;

  bool get hasMore => maxPage == null || current < maxPage!;

  void cancelRequests() {
    _disposed = true;
    _generation++;
    _pendingPages.clear();
    _retryBatchEnd = null;
  }

  Future<Res<List<T>>> _request(
      Future<Res<List<T>>> Function(int) loader, int page) async {
    try {
      return await loader(page);
    } catch (error) {
      return Res.error(error.toString());
    }
  }

  bool loading = true;

  ///用于正常模式下的漫画数据储存
  List<T>? comics;

  ///用于分页模式下的漫画数据储存
  Map<int, List<T>>? dividedComics;

  ///错误信息, null表示没有错误
  String? message;

  /// 最大页数, 为null表示不知道或者无穷
  int? maxPage;

  ///当前的页面序号
  int current = 1;

  ///是否正在获取数据， 用于在顺序浏览模式下， 避免同时进行多个网络请求
  bool loadingData = false;

  bool showFloatingButton = true;

  Future<void> get(Future<Res<List<T>>> Function(int) getComics) async {
    if (_disposed || loadingData) return;
    final generation = _generation;
    loadingData = true;
    Future.microtask(() => update());
    if (comics == null) {
      var res = await _request(getComics, 1);
      if (_disposed || generation != _generation) return;
      if (res.error) {
        message = res.errorMessage;
      } else {
        comics = List.of(res.data);
        dividedComics = {};
        dividedComics![1] = res.data;
        if (res.subData is int) {
          maxPage = res.subData;
        }
        if (res.data.isEmpty && !preserveEmptyPages) {
          maxPage = 1;
        }
      }
      loading = false;
      loadingData = false;
      update();
    } else {
      final page = current;
      var res = await _request(getComics, page);
      if (_disposed || generation != _generation) return;
      if (res.error) {
        message = res.errorMessage;
      } else {
        dividedComics![page] = res.data;
      }
      loading = false;
      loadingData = false;
      update();
    }
  }

  int _emptyPageCount = 0;

  String? nextPageError;

  Future<void> loadNextPage(Future<Res<List<T>>> Function(int) getComics) async {
    if (_disposed || !hasMore || loadingData || comics == null) return;
    if (preserveEmptyPages && pageBatchSize > 1) {
      return _loadNextBatch(getComics);
    }
    final generation = _generation;
    loadingData = true;
    Future.microtask(() => update());
    nextPageError = null;
    var res = await _request(getComics, current + 1);
    if (_disposed || generation != _generation) return;
    if (res.error) {
      nextPageError = res.errorMessage ?? 'Network Error';
      showToast(message: nextPageError!);
    } else {
      _appendPage(current + 1, res);
      if (res.data.isEmpty) {
        // 等待一会儿再加载, 避免因为某些错误导致无限加载
        if (!preserveEmptyPages) {
          await Future.delayed(const Duration(seconds: 1));
          if (_disposed || generation != _generation) return;
        }
      }
    }
    loadingData = false;
    update();
  }

  void _appendPage(int page, Res<List<T>> res) {
    current = page;
    dividedComics![page] = res.data;
    if (res.subData is int) maxPage = res.subData;
    if (res.data.isEmpty) {
      _emptyPageCount++;
      // Sources without a total cannot distinguish filtering from exhaustion.
      if (_emptyPageCount > 3 && maxPage == null) maxPage = current;
    } else {
      _emptyPageCount = 0;
      comics!.addAll(res.data);
    }
  }

  Future<void> _loadNextBatch(
      Future<Res<List<T>>> Function(int) getComics) async {
    final generation = _generation;
    final start = current + 1;
    // Read the first page before batching, so the server's last page is known.
    final end = math.min(_retryBatchEnd ?? current + pageBatchSize,
        maxPage ?? start);
    loadingData = true;
    nextPageError = null;
    Future.microtask(() => update());
    final responses = await Future.wait([
      for (var page = start; page <= end; page++)
        _pendingPages.containsKey(page)
            ? Future.value(_pendingPages[page]!)
            : _request(getComics, page),
    ]);
    if (_disposed || generation != _generation) return;

    for (var i = 0; i < responses.length; i++) {
      if (!responses[i].error) _pendingPages[start + i] = responses[i];
    }
    _retryBatchEnd = null;
    for (var page = start; page <= end && hasMore; page++) {
      final response = responses[page - start];
      if (response.error) {
        // Keep successful later pages, but never advance past a failed page.
        _retryBatchEnd = end;
        nextPageError = response.errorMessage ?? 'Network Error';
        showToast(message: nextPageError!);
        break;
      }
      _pendingPages.remove(page);
      _appendPage(page, response);
    }
    if (maxPage != null) {
      _pendingPages.removeWhere((page, _) => page > maxPage!);
    }
    loadingData = false;
    update();
  }

  @override
  void refresh() {
    _generation++;
    _pendingPages.clear();
    _retryBatchEnd = null;
    loadingData = false;
    loading = true;
    comics = null;
    dividedComics = null;
    current = 1;
    maxPage = null;
    _emptyPageCount = 0;
    nextPageError = null;
    message = null;
    update();
  }
}

/// 漫画列表页面
///
/// T为漫画信息模型
abstract class ComicsPage<T extends BaseComic> extends StatelessWidget {
  const ComicsPage({super.key});

  ///标题
  String? get title;

  /// 是否居中标题
  bool get centerTitle => true;

  /// 获取图片, 参数为页面序号, **从1开始**
  ///
  /// 返回值Res的subData为页面总数
  Future<Res<List<T>>> getComics(int i);

  /// 漫画源标识符
  String get sourceKey;

  /// 显示一个刷新按钮, 需要Scaffold启用
  bool get withRefreshFloatingButton => false;

  String? get tag;

  Widget? get tailing => null;

  Widget? get header => null;

  bool get showPageIndicator => true;

  /// Keep searching source pages that become empty after local filtering.
  bool get autoLoadFilteredPages => false;

  int get filteredPageBatchSize => 1;

  List<ComicTileMenuOption>? get addonMenuOptions => null;

  /// 刷新页面
  void refresh() {
    StateController.find<ComicsPageLogic<T>>(tag: tag).refresh();
  }

  @override
  Widget build(context) {
    Widget? removeSliver(Widget? widget) {
      if (widget == null) return null;

      if (widget is SliverToBoxAdapter) {
        return widget.child;
      }

      if (widget is SliverPersistentHeader) {
        return SizedBox(
          height: widget.delegate.minExtent,
          child: widget.delegate.build(
            context,
            widget.delegate.minExtent,
            false,
          ),
        );
      }

      return widget;
    }

    Widget body = StateBuilder<ComicsPageLogic<T>>(
        init: ComicsPageLogic<T>(
          preserveEmptyPages: autoLoadFilteredPages,
          pageBatchSize: autoLoadFilteredPages && appdata.settings[25] == '0'
              ? filteredPageBatchSize : 1,
        ),
        dispose: (logic) => logic.cancelRequests(),
        tag: tag,
        builder: (logic) {
          if (logic.dividedComics?[logic.current] == null &&
              logic.message == null &&
              appdata.settings[25] != "0") {
            logic.loading = true;
          }
          if (logic.loading) {
            logic.get(getComics);
            return Column(
              children: [
                if (title != null) const Appbar(title: Text("")),
                removeSliver(header) ?? const SizedBox(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              ],
            );
          } else if (logic.message != null) {
            return Column(
              children: [
                removeSliver(header) ?? const SizedBox(),
                Expanded(
                    child: NetworkError(
                  message: logic.message ?? "Network Error",
                  retry: logic.refresh,
                  withAppbar: title != null,
                ))
              ],
            );
          } else {
            if (appdata.settings[25] == "0") {
              List<T> comics = [];
              if (appdata.appSettings.fullyHideBlockedWorks) {
                for (var comic in logic.comics!) {
                  if (isBlocked(comic) == null) {
                    comics.add(comic);
                  }
                }
              } else {
                comics = logic.comics!;
              }
              if (autoLoadFilteredPages) {
                return _FilteredComicsScrollView(
                  logic: logic,
                  loadNextPage: () => logic.loadNextPage(getComics),
                  slivers: [
                    if (title != null)
                      SliverAppbar(
                        title: Text(title!),
                        actions: tailing != null ? [tailing!] : null,
                      ),
                    if (header != null) header!,
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('兼容筛选：已检查 @pages 页，找到 @count 部作品'.tlParams({
                          'pages': logic.current.toString(),
                          'count': comics.length.toString(),
                        })),
                      ),
                    ),
                    if (comics.isNotEmpty)
                      SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => buildItem(context, comics[i]),
                          childCount: comics.length,
                        ),
                        gridDelegate: SliverGridDelegateWithComics(),
                      )
                    else if (!logic.hasMore)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: buildEmptyView(context),
                      ),
                    if (logic.nextPageError != null)
                      SliverToBoxAdapter(
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => logic.loadNextPage(getComics),
                            icon: const Icon(Icons.refresh),
                            label: Text('重试'.tl),
                          ),
                        ),
                      )
                    else if (logic.hasMore)
                      const SliverToBoxAdapter(child: ListLoadingIndicator())
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                );
              }
              if (comics.isEmpty) {
                return SmoothCustomScrollView(
                  slivers: [
                    if (title != null)
                      SliverAppbar(
                        title: Text(title!),
                        actions: tailing != null ? [tailing!] : null,
                      ),
                    if (header != null) header!,
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: buildEmptyView(context),
                    ),
                  ],
                );
              }
              return SmoothCustomScrollView(
                slivers: [
                  if (title != null)
                    SliverAppbar(
                      title: Text(title!),
                      actions: tailing != null ? [tailing!] : null,
                    ),
                  if (header != null) header!,
                  SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                        childCount: comics.length, (context, i) {
                      if (i == comics.length - 1 && logic.nextPageError == null) {
                        logic.loadNextPage(getComics);
                      }
                      return buildItem(context, comics[i]);
                    }),
                    gridDelegate: SliverGridDelegateWithComics(),
                  ),
                  if (logic.nextPageError != null)
                    SliverToBoxAdapter(
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => logic.loadNextPage(getComics),
                          icon: const Icon(Icons.refresh),
                          label: Text('重试'.tl),
                        ),
                      ),
                    ),
                  if (logic.current < (logic.maxPage ?? 114514) &&
                      logic.loadingData)
                    const SliverToBoxAdapter(
                      child: ListLoadingIndicator(),
                    )
                  else
                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 80,
                      ),
                    )
                ],
              );
            } else {
              List<T> comics = [];
              if (appdata.appSettings.fullyHideBlockedWorks) {
                for (var comic in logic.dividedComics![logic.current]!) {
                  if (isBlocked(comic) == null) {
                    comics.add(comic);
                  }
                }
              } else {
                comics = logic.dividedComics![logic.current]!;
              }
              if (comics.isEmpty) {
                return SmoothCustomScrollView(
                  slivers: [
                    if (title != null)
                      SliverAppbar(
                        title: Text(title!),
                        actions: tailing != null ? [tailing!] : null,
                      ),
                    if (header != null) header!,
                    if (autoLoadFilteredPages && showPageIndicator && logic.maxPage != 1)
                      buildPageSelector(context, logic),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: buildEmptyView(context),
                    ),
                  ],
                );
              }
              Widget body = SmoothCustomScrollView(
                slivers: [
                  if (title != null)
                    SliverAppbar(
                      title: Text(title!),
                      actions: tailing != null ? [tailing!] : null,
                    ),
                  if (header != null) header!,
                  if (showPageIndicator &&
                      appdata.settings[64] == "0" &&
                      logic.maxPage != 1)
                    buildPageSelector(context, logic),
                  SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                        childCount: comics.length, (context, i) {
                      return buildItem(context, comics[i]);
                    }),
                    gridDelegate: SliverGridDelegateWithComics(),
                  ),
                  if (showPageIndicator &&
                      appdata.settings[64] == "0" &&
                      logic.maxPage != 1)
                    buildPageSelector(context, logic),
                  SliverPadding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom))
                ],
              );

              body = NotificationListener<ScrollUpdateNotification>(
                onNotification: (notifications) {
                  if (notifications.scrollDelta != null) {
                    if (notifications.scrollDelta! > 0 &&
                        logic.showFloatingButton) {
                      logic.showFloatingButton = false;
                      logic.update();
                    } else if ((notifications.scrollDelta! < 0 ||
                            notifications.metrics.pixels ==
                                notifications.metrics.minScrollExtent ||
                            notifications.metrics.pixels ==
                                notifications.metrics.maxScrollExtent) &&
                        !logic.showFloatingButton) {
                      logic.showFloatingButton = true;
                      logic.update();
                    }
                  }
                  return false;
                },
                child: body,
              );

              if (showPageIndicator && appdata.settings[64] == "1") {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: body,
                    ),
                    Positioned(
                      left: 0,
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: buildPageSelectorRight(context, logic),
                    )
                  ],
                );
              } else {
                return body;
              }
            }
          }
        });

    if (header != null && UiMode.m1(context)) {
      body = SafeArea(
        bottom: false,
        child: body,
      );
    }

    if (withRefreshFloatingButton) {
      return Scaffold(
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.refresh),
          onPressed: () {
            refresh();
          },
        ),
        body: body,
      );
    } else {
      return Material(
        child: body,
      );
    }
  }

  Widget buildPageSelector(BuildContext context, ComicsPageLogic logic) {
    return SliverToBoxAdapter(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: SizedBox(
            width: 300,
            height: 42,
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                ),
                FilledButton.tonal(
                    onPressed: () => prevPage(logic), child: Text("上一页".tl)),
                const Spacer(),
                ActionChip(
                  label: Text(
                      "${"页面".tl}: ${logic.current}/${logic.maxPage?.toString() ?? "?"}"),
                  onPressed: () async {
                    selectPage(logic);
                  },
                  elevation: 1,
                  side: BorderSide.none,
                ),
                const Spacer(),
                FilledButton.tonal(
                    onPressed: () => nextPage(logic), child: Text("下一页".tl)),
                const SizedBox(
                  width: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPageSelectorRight(BuildContext context, ComicsPageLogic logic) {
    return Align(
        alignment: Alignment.centerRight,
        child: AnimatedSlide(
          offset: logic.showFloatingButton
              ? const Offset(0, 0)
              : const Offset(1.5, 0),
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
            elevation: 3,
            child: SizedBox(
              height: 156,
              width: 58,
              child: Column(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16)),
                      onTap: () {
                        prevPage(logic);
                      },
                      child: const SizedBox.expand(
                        child: Center(
                          child: Icon(Icons.keyboard_arrow_left),
                        ),
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  Expanded(
                      child: InkWell(
                    onTap: () {
                      selectPage(logic);
                    },
                    child: SizedBox.expand(
                      child: Center(
                        child: Text(
                            "${logic.current}/${logic.maxPage?.toString() ?? "?"}"),
                      ),
                    ),
                  )),
                  const Divider(
                    height: 1,
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16)),
                      onTap: () {
                        nextPage(logic);
                      },
                      child: const SizedBox.expand(
                        child: Center(
                          child: Icon(Icons.keyboard_arrow_right),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  void nextPage(ComicsPageLogic logic) {
    if (logic.current == logic.maxPage || logic.current == 0) {
      showToast(message: "已经是最后一页了".tl);
    } else {
      logic.current++;
      logic.update();
    }
  }

  void prevPage(ComicsPageLogic logic) {
    if (logic.current == 1 || logic.current == 0) {
      showToast(message: "已经是第一页了".tl);
    } else {
      logic.current--;
      logic.update();
    }
  }

  void selectPage(ComicsPageLogic logic) async {
    String res = "";
    await showDialog(
        context: App.globalContext!,
        builder: (dialogContext) {
          var controller = TextEditingController();
          return SimpleDialog(
            title: const Text("切换页面"),
            children: [
              const SizedBox(
                width: 300,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: TextField(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: "页码".tl,
                    suffixText:
                        "${"输入范围: ".tl}1-${logic.maxPage?.toString() ?? "?"}",
                  ),
                  controller: controller,
                  onSubmitted: (s) {
                    res = s;
                    App.globalBack();
                  },
                ),
              ),
              Center(
                child: FilledButton(
                  child: Text("提交".tl),
                  onPressed: () {
                    res = controller.text;
                    App.globalBack();
                  },
                ),
              )
            ],
          );
        });
    if (res.isNum) {
      int i = int.parse(res);
      if (logic.maxPage == null || (i > 0 && i <= logic.maxPage!)) {
        logic.current = i;
        logic.update();
        return;
      }
    }
    if (res != "") {
      showToast(message: "输入的数字不正确".tl);
    }
  }

  Widget buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 56),
          const SizedBox(height: 12),
          Text("无匹配结果".tl,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget buildItem(BuildContext context, T item) {
    return buildComicTile(context, item, sourceKey, addonMenuOptions: addonMenuOptions);
  }
}

/// Request another filtered source page only when the viewport needs more.
/// Empty pages do not end the search, and hidden routes never keep scanning.
class _FilteredComicsScrollView extends StatefulWidget {
  const _FilteredComicsScrollView({
    required this.logic,
    required this.loadNextPage,
    required this.slivers,
  });

  final ComicsPageLogic logic;
  final Future<void> Function() loadNextPage;
  final List<Widget> slivers;

  @override
  State<_FilteredComicsScrollView> createState() => _FilteredComicsScrollViewState();
}

class _FilteredComicsScrollViewState extends State<_FilteredComicsScrollView>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  Timer? _timer;
  bool _postFramePending = false;
  bool _visible = true;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _resumed = state == null || state == AppLifecycleState.resumed;
    _scrollController.addListener(_scheduleCheck);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) {
      _scheduleCheck();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  bool get _needsMore => mounted && _visible && _resumed &&
      !widget.logic.loadingData && widget.logic.nextPageError == null &&
      widget.logic.hasMore && _scrollController.hasClients &&
      _scrollController.position.extentAfter < 400;

  void _scheduleCheck() {
    if (_postFramePending || !mounted) return;
    _postFramePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFramePending = false;
      if (!_needsMore) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      // Bound the request rate when many consecutive pages have no matches.
      _timer ??= Timer(const Duration(milliseconds: 200), () {
        _timer = null;
        if (_needsMore) unawaited(widget.loadNextPage());
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    _visible = TickerMode.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    _scheduleCheck();
    return SmoothCustomScrollView(
      controller: _scrollController,
      slivers: widget.slivers,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }
}

class SliverGridComicsController extends StateController {}

class SliverGridComics extends StatelessWidget {
  const SliverGridComics({
    super.key,
    required this.comics,
    required this.sourceKey,
    this.onLastItemBuild,
  });

  final List<BaseComic> comics;

  final String sourceKey;

  final void Function()? onLastItemBuild;

  @override
  Widget build(BuildContext context) {
    return StateBuilder<SliverGridComicsController>(
      init: SliverGridComicsController(),
      builder: (controller) {
        List<BaseComic> comics = [];
        if (appdata.appSettings.fullyHideBlockedWorks) {
          for (var comic in this.comics) {
            if (isBlocked(comic) == null) {
              comics.add(comic);
            }
          }
        } else {
          comics = this.comics;
        }
        return _SliverGridComics(
          comics: comics,
          sourceKey: sourceKey,
          onLastItemBuild: onLastItemBuild,
        );
      },
    );
  }
}

class _SliverGridComics extends StatelessWidget {
  const _SliverGridComics({
    required this.comics,
    required this.sourceKey,
    this.onLastItemBuild,
  });

  final List<BaseComic> comics;

  final String sourceKey;

  final void Function()? onLastItemBuild;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == comics.length - 1) {
            onLastItemBuild?.call();
          }
          return buildComicTile(context, comics[index], sourceKey);
        },
        childCount: comics.length,
      ),
      gridDelegate: SliverGridDelegateWithComics(),
    );
  }
}
