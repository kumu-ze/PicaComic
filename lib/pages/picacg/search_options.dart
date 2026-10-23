import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pica_comic/network/picacg_network/search_filters.dart';
import 'package:pica_comic/tools/translations.dart';

class PicacgSearchOptions extends StatefulWidget {
  const PicacgSearchOptions({
    super.key,
    required this.initialValues,
    required this.onChanged,
  });

  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;

  @override
  State<PicacgSearchOptions> createState() => _PicacgSearchOptionsState();
}

class _PicacgSearchOptionsState extends State<PicacgSearchOptions> {
  late String sort;
  late Set<String> categories;
  bool compatibilityMode = false;
  final includeController = TextEditingController();
  final excludeController = TextEditingController();

  void restore() {
    final initial = PicacgSearchFilters.fromOptions(widget.initialValues);
    sort = initial.sort;
    categories = initial.categories.toSet();
    compatibilityMode = initial.compatibilityMode;
    includeController.text = initial.includedTags.join(', ');
    excludeController.text = initial.excludedTags.join(', ');
  }

  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void didUpdateWidget(covariant PicacgSearchOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.initialValues, oldWidget.initialValues)) restore();
  }

  void update() {
    setState(() {});
    widget.onChanged(filters.toOptions());
  }

  PicacgSearchFilters get filters => PicacgSearchFilters(
        sort: sort,
        categories: categories,
        compatibilityMode: compatibilityMode,
        includeTags: includeController.text,
        excludeTags: excludeController.text,
      );

  @override
  void dispose() {
    includeController.dispose();
    excludeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('排序'.tl, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in PicacgSearchFilters.sortLabels.entries)
                ChoiceChip(
                  label: Text(entry.value.tl),
                  selected: sort == entry.key,
                  onSelected: (_) {
                    sort = entry.key;
                    update();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            key: const ValueKey('picacg-compatibility-mode'),
            contentPadding: EdgeInsets.zero,
            title: Text('兼容模式（多标签筛选）'.tl),
            value: compatibilityMode,
            onChanged: (enabled) {
              compatibilityMode = enabled;
              update();
            },
          ),
          if (compatibilityMode) ...[
            Text('在搜索结果中筛选标签，向下滚动自动继续加载。关键词留空时，使用第一个包含标签搜索。'.tl),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('picacg-include-tags'),
              controller: includeController,
              decoration: InputDecoration(
                labelText: '必须包含全部标签'.tl,
                helperText: '多个标签用逗号分隔，标签内可含空格'.tl,
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => update(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('picacg-exclude-tags'),
              controller: excludeController,
              decoration: InputDecoration(
                labelText: '排除任一标签'.tl,
                border: const OutlineInputBorder(),
                errorText: filters.hasConflict ? '同一标签不能同时包含和排除'.tl : null,
                errorMaxLines: 2,
              ),
              onChanged: (_) => update(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  includeController.clear();
                  excludeController.clear();
                  update();
                },
                child: Text('清除标签'.tl),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: Text('分类（可多选）'.tl,
                      style: Theme.of(context).textTheme.titleMedium)),
              TextButton(
                onPressed: categories.isEmpty
                    ? null
                    : () {
                        categories.clear();
                        update();
                      },
                child: Text('清除分类'.tl),
              ),
            ],
          ),
          Text('选择分类后，与上方关键词一起搜索；未选择时搜索全部分类。'.tl),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final category in PicacgSearchFilters.availableCategories)
                FilterChip(
                  key: ValueKey('picacg-category-$category'),
                  label: Text(category),
                  selected: categories.contains(category),
                  onSelected: (selected) {
                    if (selected) {
                      categories.add(category);
                    } else {
                      categories.remove(category);
                    }
                    update();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
