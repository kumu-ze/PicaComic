/// Picacg filters are stored alongside the existing sort option.
/// Matching uses the tags/categories returned by Picacg, never title substrings.
class PicacgSearchFilters {
  static const sortLabels = {
    'dd': '新到旧',
    'da': '旧到新',
    'ld': '最多喜欢',
    'vd': '最多指名',
  };

  final String sort;
  final String includedText;
  final String excludedText;
  final List<String> included;
  final List<String> excluded;

  PicacgSearchFilters({
    String sort = 'dd',
    this.includedText = '',
    this.excludedText = '',
  })  : sort = sortLabels.containsKey(sort) ? sort : 'dd',
        included = parseTags(includedText),
        excluded = parseTags(excludedText);

  factory PicacgSearchFilters.fromOptions(List<String> options) {
    return PicacgSearchFilters(
      sort: options.isNotEmpty ? options[0] : 'dd',
      includedText: options.length > 1 ? options[1] : '',
      excludedText: options.length > 2 ? options[2] : '',
    );
  }

  static List<String> parseTags(String text) {
    final seen = <String>{};
    return text
        .split(RegExp(r'[,，、;；\r\n]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty && seen.add(tag.toLowerCase()))
        .toList(growable: false);
  }

  bool get isActive => included.isNotEmpty || excluded.isNotEmpty;

  bool get hasConflict {
    final excludedKeys = excluded.map((tag) => tag.toLowerCase()).toSet();
    return included.any((tag) => excludedKeys.contains(tag.toLowerCase()));
  }

  /// A single included tag narrows the candidate search when no keyword is set.
  /// Every included/excluded tag is still checked against returned metadata.
  String candidateKeyword(String keyword) => keyword.trim().isNotEmpty
      ? keyword
      : (included.isNotEmpty ? included.first : '');

  bool matches(Iterable<String> tags) {
    final keys = tags.map((tag) => tag.trim().toLowerCase()).toSet();
    return included.every((tag) => keys.contains(tag.toLowerCase())) &&
        !excluded.any((tag) => keys.contains(tag.toLowerCase()));
  }

  List<String> toOptions() => [sort, includedText, excludedText];
}
