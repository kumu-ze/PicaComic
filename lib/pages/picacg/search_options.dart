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

  void restore() {
    final initial = PicacgSearchFilters.fromOptions(widget.initialValues);
    sort = initial.sort;
    categories = initial.categories.toSet();
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
    widget.onChanged(
        PicacgSearchFilters(sort: sort, categories: categories).toOptions());
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
