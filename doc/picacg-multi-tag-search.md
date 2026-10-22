# 哔咔原生分类搜索

在原来的搜索页选择 **picacg**，输入关键词，在搜索选项中选择排序和一个或多个分类，再执行搜索。也可以不输入关键词，只选择分类。

- 分类与关键词一起提交给哔咔的 `comics/advanced-search` 接口：`keyword`、`sort`、`categories`。
- 服务端决定匹配结果及页数；客户端不再根据标签删掉返回的作品，也不会拿第一个分类替代关键词。
- 连续浏览沿用原生滚动自动加载。网络失败暂停加载，点“重试”仍请求同一页。分页浏览沿用原有页码入口。
- 分类使用现有分类页的原始名称。未选分类即普通搜索；“清除分类”保留排序。
- 搜索结果页的选项支持重新打开、取消和确认；修改后从第一页重新搜索。
- 上一版的任意标签包含/排除条件不会被解释成原生分类；旧的“继续筛选下一页”流程已移除。

这不是任意详情标签的精确 AND/NOT 搜索。多选分类的匹配语义由哔咔服务端决定，本客户端不声称“必须同时命中全部分类”。

## 接口依据

以下现有客户端均直接向高级搜索提交关键词和分类数组：

- https://github.com/lanyeeee/picacomic-downloader/blob/main/src-tauri/src/pica_client.rs
- https://github.com/raoxwup/haka_comic/blob/main/lib/network/models.dart
- https://github.com/tonquer/picacg-qt/blob/main/src/server/req.py

## 验证

```sh
flutter test test/picacg_search_filters_test.dart test/picacg_search_options_test.dart test/picacg_filtered_pagination_test.dart
```

测试覆盖请求参数、关键词不被替换、分类多选与清除、旧条件迁移、选项取消与应用、窄屏布局、原生滚动自动加载、失败重试和分页重置。不使用真实账号；实时服务端匹配和真机行为仍需实际登录后验收。

本次使用 Flutter 3.35.7 验证：13 项测试通过；改动相关静态分析无错误或警告，21 条既有信息级提示。
