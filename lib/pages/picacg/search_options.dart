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
  late final TextEditingController included;
  late final TextEditingController excluded;

  PicacgSearchFilters get filters => PicacgSearchFilters(
        sort: sort,
        includedText: included.text,
        excludedText: excluded.text,
      );

  @override
  void initState() {
    super.initState();
    final initial = PicacgSearchFilters.fromOptions(widget.initialValues);
    sort = initial.sort;
    included = TextEditingController(text: initial.includedText);
    excluded = TextEditingController(text: initial.excludedText);
  }

  @override
  void didUpdateWidget(covariant PicacgSearchOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.initialValues, oldWidget.initialValues)) {
      final initial = PicacgSearchFilters.fromOptions(widget.initialValues);
      sort = initial.sort;
      if (included.text != initial.includedText) {
        included.text = initial.includedText;
      }
      if (excluded.text != initial.excludedText) {
        excluded.text = initial.excludedText;
      }
    }
  }

  @override
  void dispose() {
    included.dispose();
    excluded.dispose();
    super.dispose();
  }

  void update() {
    setState(() {});
    widget.onChanged(filters.toOptions());
  }

  Widget tagField(String label, TextEditingController controller) {
    final tags = PicacgSearchFilters.parseTags(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: ValueKey(label),
          controller: controller,
          minLines: 1,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: label.tl,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => update(),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: () {
                      controller.text = tags.where((t) => t != tag).join(', ');
                      update();
                    },
                  ),
              ],
            ),
          ),
      ],
    );
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
                child: Text('多标签搜索'.tl,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: filters.isActive
                    ? () {
                        included.clear();
                        excluded.clear();
                        update();
                      }
                    : null,
                child: Text('清除标签'.tl),
              ),
            ],
          ),
          Text('用逗号或换行分隔标签，标签内的空格会保留'.tl),
          const SizedBox(height: 12),
          tagField('包含所有标签', included),
          const SizedBox(height: 12),
          tagField('排除任一标签', excluded),
          const SizedBox(height: 8),
          Text('标签和分类精确匹配；可搭配上方关键词。筛选逐页进行，可继续加载后续页。'.tl),
          if (filters.hasConflict)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '同一标签同时被包含和排除，不会有匹配结果'.tl,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
