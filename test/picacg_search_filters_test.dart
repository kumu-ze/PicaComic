import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/network/picacg_network/search_filters.dart';

void main() {
  test(
      'batch setting round trips and v2 options upgrade without losing filters',
      () {
    final old = PicacgSearchFilters.fromOptions([
      'ld',
      'picacg-search-v2',
      'compat',
      'Robots, Space Opera',
      'Draft',
      '全彩',
    ]);
    expect(old.concurrentPages, 5);
    expect(old.compatibilityMode, isTrue);
    expect(old.categories, ['全彩']);
    expect(old.includedTags, ['Robots', 'Space Opera']);
    expect(old.excludedTags, ['Draft']);
    final options = PicacgSearchFilters(
      compatibilityMode: true,
      concurrentPages: 8,
      includeTags: 'Robots',
      categories: ['短篇'],
    );
    final restored = PicacgSearchFilters.fromOptions(options.toOptions());
    expect(restored.concurrentPages, 8);
    expect(restored.categories, ['短篇']);
    expect(restored.toRequest('title'), {
      'keyword': 'title',
      'sort': 'dd',
      'categories': ['短篇']
    });
    for (final invalid in ['0', '-3', '1000', 'invalid']) {
      final values = options.toOptions()..[5] = invalid;
      expect(PicacgSearchFilters.fromOptions(values).concurrentPages, 5);
    }
  });

  test('compatibility mode matches every include and rejects any exclude', () {
    final filters = PicacgSearchFilters(
      compatibilityMode: true,
      includeTags: ' Space Opera，Robots; space opera\nRobots ',
      excludeTags: 'Unfinished、Draft',
    );
    expect(filters.includedTags, ['Space Opera', 'Robots']);
    expect(filters.excludedTags, ['Unfinished', 'Draft']);
    expect(filters.matches([' space opera ', 'ROBOTS', 'full color']), isTrue);
    expect(filters.matches(['Space Opera', 'Tiny Robots']), isFalse);
    expect(filters.matches(['Robots']), isFalse);
    expect(filters.matches(['Space Opera', 'Robots', 'draft']), isFalse);
    expect(filters.matches([]), isFalse);
    expect(filters.toRequest('')['keyword'], 'Space Opera');
    expect(filters.toRequest('my title')['keyword'], 'my title');
  });

  test(
      'disabled compatibility retains tag choices without changing native search',
      () {
    final filters = PicacgSearchFilters(
      categories: ['全彩'],
      includeTags: 'Robots',
      excludeTags: 'Robots',
    );
    final restored = PicacgSearchFilters.fromOptions(filters.toOptions());
    expect(restored.compatibilityMode, isFalse);
    expect(restored.hasLocalFilters, isFalse);
    expect(restored.hasConflict, isFalse);
    expect(restored.includedTags, ['Robots']);
    expect(restored.excludedTags, ['Robots']);
    expect(restored.matches([]), isTrue);
    expect(restored.toRequest(''), {
      'keyword': '',
      'sort': 'dd',
      'categories': ['全彩']
    });
  });

  test('compatibility options round trip and detect conflicting tags', () {
    final filters = PicacgSearchFilters(
      sort: 'vd',
      categories: ['短篇'],
      compatibilityMode: true,
      includeTags: 'Robots, Space Opera',
      excludeTags: 'robots',
    );
    final restored = PicacgSearchFilters.fromOptions(filters.toOptions());
    expect(restored.hasConflict, isTrue);
    expect(restored.hasLocalFilters, isTrue);
    expect(restored.toOptions(), filters.toOptions());
    expect(restored.matches(['Robots', 'Space Opera']), isFalse);
  });

  test('exclude-only compatibility and native v1 options remain usable', () {
    final filters =
        PicacgSearchFilters(compatibilityMode: true, excludeTags: 'Draft');
    expect(filters.matches([]), isTrue);
    expect(filters.matches(['Draft']), isFalse);
    expect(filters.toRequest('')['keyword'], '');
    final old = PicacgSearchFilters.fromOptions(
        ['ld', 'native-categories-v1', '全彩', '短篇']);
    expect(old.categories, ['全彩', '短篇']);
    expect(old.compatibilityMode, isFalse);
  });

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
