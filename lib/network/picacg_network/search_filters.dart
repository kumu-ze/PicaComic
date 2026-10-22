/// Options for Picacg's native keyword/category search.
/// Categories are sent to the server; returned results are not filtered locally.
class PicacgSearchFilters {
  static const sortLabels = {
    'dd': '新到旧',
    'da': '旧到新',
    'ld': '最多喜欢',
    'vd': '最多指名',
  };

  static const _optionsVersion = 'native-categories-v1';

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

  PicacgSearchFilters(
      {String sort = 'dd', Iterable<String> categories = const []})
      : sort = sortLabels.containsKey(sort) ? sort : 'dd',
        categories = List.unmodifiable(
            categories.where(availableCategories.contains).toSet());

  factory PicacgSearchFilters.fromOptions(List<String> options) {
    return PicacgSearchFilters(
      sort: options.isEmpty ? 'dd' : options.first,
      // Never reinterpret legacy include/exclude tags as native categories.
      categories: options.length > 1 && options[1] == _optionsVersion
          ? options.skip(2)
          : const [],
    );
  }

  Map<String, dynamic> toRequest(String keyword) => {
        'keyword': keyword,
        'sort': sort,
        if (categories.isNotEmpty) 'categories': categories,
      };

  List<String> toOptions() => [sort, _optionsVersion, ...categories];
}
