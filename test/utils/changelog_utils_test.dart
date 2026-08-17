import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/utils/changelog_utils.dart';

const _sampleChangelog = '''
# Changelog

## 3.5.0

### Added
- Remember a senseBox and auto-connect to it.
- Tablet-friendly layout.

### Fixed
- Restored compatibility with newer senseBox configurations.

## 3.4.0

### Added
- Choose from predefined openSenseMap API URLs.

## 3.3.9
- Uncategorized bullet one.
- Uncategorized bullet two.
''';

void main() {
  group('parseChangelogVersionSection', () {
    test('returns categorized sections for the matching version', () {
      final sections =
          parseChangelogVersionSection(_sampleChangelog, '3.5.0');

      expect(sections, hasLength(2));
      expect(sections[0].category, 'Added');
      expect(sections[0].items, [
        'Remember a senseBox and auto-connect to it.',
        'Tablet-friendly layout.',
      ]);
      expect(sections[1].category, 'Fixed');
      expect(sections[1].items, [
        'Restored compatibility with newer senseBox configurations.',
      ]);
    });

    test('stops at the next version heading', () {
      final sections =
          parseChangelogVersionSection(_sampleChangelog, '3.4.0');

      expect(sections, hasLength(1));
      expect(sections[0].category, 'Added');
      expect(sections[0].items, [
        'Choose from predefined openSenseMap API URLs.',
      ]);
    });

    test('supports bullets with no ### subheading', () {
      final sections =
          parseChangelogVersionSection(_sampleChangelog, '3.3.9');

      expect(sections, hasLength(1));
      expect(sections[0].category, '');
      expect(sections[0].items, [
        'Uncategorized bullet one.',
        'Uncategorized bullet two.',
      ]);
    });

    test('returns an empty list when the version is not present', () {
      final sections =
          parseChangelogVersionSection(_sampleChangelog, '9.9.9');

      expect(sections, isEmpty);
    });

    test('returns an empty list for a version heading with no bullets', () {
      const changelog = '''
## 1.0.0

Just prose, no bullet items.

## 0.9.0
- Something.
''';
      final sections = parseChangelogVersionSection(changelog, '1.0.0');

      expect(sections, isEmpty);
    });
  });
}
