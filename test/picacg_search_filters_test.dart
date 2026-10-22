import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/network/picacg_network/search_filters.dart';

void main() {
  test('all selected categories are sent with the original keyword', () {
    final options = PicacgSearchFilters(sort: 'ld', categories: ['全彩', '單行本']);
    expect(jsonDecode(jsonEncode(options.toRequest('Science Fiction'))), {
      'keyword': 'Science Fiction',
      'sort': 'ld',
      'categories': ['全彩', '單行本'],
    });
  });

  test(
      'category-only search does not replace the keyword with the first category',
      () {
    final options = PicacgSearchFilters(categories: ['全彩', '短篇']);
    expect(options.toRequest('')['keyword'], '');
    expect(options.toRequest('')['categories'], ['全彩', '短篇']);
  });

  test('cleared categories use the ordinary native search payload', () {
    expect(PicacgSearchFilters(sort: 'vd').toRequest('title'), {
      'keyword': 'title',
      'sort': 'vd',
    });
  });

  test('sort and selected categories round trip without changing names', () {
    final options =
        PicacgSearchFilters(sort: 'da', categories: ['長篇', '英語 ENG']);
    final restored = PicacgSearchFilters.fromOptions(options.toOptions());
    expect(restored.sort, 'da');
    expect(restored.categories, ['長篇', '英語 ENG']);
  });

  test('legacy local include/exclude options are not sent as native categories',
      () {
    expect(
        PicacgSearchFilters.fromOptions(['ld', '全彩, 短篇', '長篇']).toRequest('x'),
        {
          'keyword': 'x',
          'sort': 'ld',
        });
    expect(PicacgSearchFilters.fromOptions([]).sort, 'dd');
    expect(PicacgSearchFilters.fromOptions(['bad']).sort, 'dd');
  });

  test('duplicates and unknown values cannot become native category filters',
      () {
    expect(
        PicacgSearchFilters(categories: ['全彩', '全彩', 'arbitrary tag', '大家都在看'])
            .categories,
        ['全彩']);
  });
}
