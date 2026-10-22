import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/network/picacg_network/search_filters.dart';

void main() {
  test('legacy sort-only and empty options retain ordinary search', () {
    final empty = PicacgSearchFilters.fromOptions([]);
    expect(empty.sort, 'dd');
    expect(empty.isActive, isFalse);
    expect(empty.matches([]), isTrue);
    expect(empty.candidateKeyword('a title'), 'a title');
    expect(PicacgSearchFilters.fromOptions(['ld']).sort, 'ld');
    expect(PicacgSearchFilters.fromOptions(['invalid']).sort, 'dd');
  });

  test('Chinese separators, newlines, whitespace and duplicates', () {
    expect(
      PicacgSearchFilters.parseTags(' 冒险，彩色、冒险; Science Fiction\nscience fiction；校园\r\n ,'),
      ['冒险', '彩色', 'Science Fiction', '校园'],
    );
  });

  test('requires ALL included tags and rejects ANY excluded tag', () {
    final filters = PicacgSearchFilters(
      includedText: 'Adventure, Full Color',
      excludedText: 'Draft, Incomplete',
    );
    expect(filters.matches(['adventure', 'full color', 'Complete']), isTrue);
    expect(filters.matches(['Adventure']), isFalse);
    expect(filters.matches(['Adventure', 'Full Color', 'Draft']), isFalse);
    expect(filters.matches(['Adventure', 'Full Color', 'Incomplete']), isFalse);
    expect(filters.matches([]), isFalse);
  });

  test('matches full tag values, never substrings', () {
    final filters = PicacgSearchFilters(includedText: 'Color');
    expect(filters.matches(['Full Color']), isFalse);
    expect(filters.matches([' COLOR ']), isTrue);
  });

  test('exclusion-only search keeps items without excluded metadata', () {
    final filters = PicacgSearchFilters(excludedText: 'Draft');
    expect(filters.isActive, isTrue);
    expect(filters.matches([]), isTrue);
    expect(filters.matches(['Complete']), isTrue);
    expect(filters.matches(['draft']), isFalse);
    expect(filters.candidateKeyword(''), '');
  });

  test('keyword takes precedence; tag-only search uses its first tag', () {
    final filters = PicacgSearchFilters(includedText: 'Adventure, Full Color');
    expect(filters.candidateKeyword('My Comic'), 'My Comic');
    expect(filters.candidateKeyword('  '), 'Adventure');
  });

  test('conflicts cannot match and are detected case-insensitively', () {
    final filters = PicacgSearchFilters(
      includedText: 'Adventure', excludedText: 'adventure',
    );
    expect(filters.hasConflict, isTrue);
    expect(filters.matches(['Adventure']), isFalse);
  });

  test('options round-trip without losing multi-word tags or sorting', () {
    final original = PicacgSearchFilters(
      sort: 'vd', includedText: 'Science Fiction, Full Color', excludedText: 'Draft',
    );
    final restored = PicacgSearchFilters.fromOptions(original.toOptions());
    expect(restored.toOptions(), original.toOptions());
    expect(restored.included, ['Science Fiction', 'Full Color']);
    expect(restored.excluded, ['Draft']);
  });
}
