/// Native search options with optional client-side tag filtering.
class PicacgSearchFilters {
  static const sortLabels = {
    'dd': '新到旧',
    'da': '旧到新',
    'ld': '最多喜欢',
    'vd': '最多指名',
  };

  static const _optionsVersion = 'native-categories-v1';
  static const _compatOptionsVersion = 'picacg-search-v2';

  // Use the exact server category names already used by the category browser.
  static const availableCategories = <String>[
    "嗶咔漢化",
    "全彩",
    "長篇",
    "同人",
    "短篇",
    "圓神領域",
    "碧藍幻想",
    "CG雜圖",
    "英語 ENG",
    "生肉",
    "純愛",
    "百合花園",
    "耽美花園",
    "偽娘哲學",
    "後宮閃光",
    "扶他樂園",
    "單行本",
    "姐姐系",
    "妹妹系",
    "SM",
    "性轉換",
    "足の恋",
    "人妻",
    "NTR",
    "強暴",
    "非人類",
    "艦隊收藏",
    "Love Live",
    "SAO 刀劍神域",
    "Fate",
    "東方",
    "WEBTOON",
    "禁書目錄",
    "歐美",
    "Cosplay",
    "重口地帶",
  ];

  final String sort;
  final List<String> categories;
  final bool compatibilityMode;
  final List<String> includedTags;
  final List<String> excludedTags;

  PicacgSearchFilters(
      {String sort = 'dd',
      Iterable<String> categories = const [],
      this.compatibilityMode = false,
      String includeTags = '',
      String excludeTags = ''})
      : sort = sortLabels.containsKey(sort) ? sort : 'dd',
        includedTags = List.unmodifiable(parseTags(includeTags)),
        excludedTags = List.unmodifiable(parseTags(excludeTags)),
        categories = List.unmodifiable(
            categories.where(availableCategories.contains).toSet());

  factory PicacgSearchFilters.fromOptions(List<String> options) {
    if (options.length >= 5 && options[1] == _compatOptionsVersion) {
      return PicacgSearchFilters(
        sort: options.first,
        compatibilityMode: options[2] == 'compat',
        includeTags: options[3],
        excludeTags: options[4],
        categories: options.skip(5),
      );
    }
    return PicacgSearchFilters(
      sort: options.isEmpty ? 'dd' : options.first,
      // Never reinterpret legacy include/exclude tags as native categories.
      categories: options.length > 1 && options[1] == _optionsVersion
          ? options.skip(2)
          : const [],
    );
  }

  Map<String, dynamic> toRequest(String keyword) => {
        'keyword': compatibilityMode &&
                keyword.trim().isEmpty &&
                includedTags.isNotEmpty
            ? includedTags.first
            : keyword,
        'sort': sort,
        if (categories.isNotEmpty) 'categories': categories,
      };

  List<String> toOptions() => [
        sort,
        _compatOptionsVersion,
        compatibilityMode ? 'compat' : 'native',
        includedTags.join(', '),
        excludedTags.join(', '),
        ...categories,
      ];

  static List<String> parseTags(String text) {
    final seen = <String>{};
    return text
        .split(RegExp(r'[,，、;；\r\n]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty && seen.add(tag.toLowerCase()))
        .toList();
  }

  bool get hasLocalFilters =>
      compatibilityMode && (includedTags.isNotEmpty || excludedTags.isNotEmpty);

  bool get hasConflict =>
      compatibilityMode &&
      includedTags.any((tag) => excludedTags
          .any((excluded) => excluded.toLowerCase() == tag.toLowerCase()));

  /// Exact tag/category matches, ignoring case and surrounding whitespace.
  bool matches(Iterable<String> tags) {
    if (!hasLocalFilters) return true;
    final values = tags.map((tag) => tag.trim().toLowerCase()).toSet();
    return includedTags.every((tag) => values.contains(tag.toLowerCase())) &&
        !excludedTags.any((tag) => values.contains(tag.toLowerCase()));
  }
}
