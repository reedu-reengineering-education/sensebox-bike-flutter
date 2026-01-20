import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/utils/json_validation.dart';

void main() {
  group('requireString', () {
    test('returns string value when field exists and is correct type', () {
      final json = {'name': 'test'};
      expect(requireString(json, 'name', 'TestClass'), 'test');
    });

    test('throws FormatException when field is missing', () {
      final json = <String, dynamic>{};
      expect(
        () => requireString(json, 'name', 'TestClass'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "name"'),
        )),
      );
    });

    test('throws FormatException when field has wrong type', () {
      final json = {'name': 123};
      expect(
        () => requireString(json, 'name', 'TestClass'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must be a String'),
        )),
      );
    });

    test('error message includes className', () {
      final json = <String, dynamic>{};
      expect(
        () => requireString(json, 'field', 'MyClass'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('MyClass.fromJson'),
        )),
      );
    });
  });

  group('requireList', () {
    test('returns list when field exists and is correct type', () {
      final json = {'items': [1, 2, 3]};
      final result = requireList<int>(
        json,
        'items',
        'TestClass',
        (item) => item as int,
      );
      expect(result, [1, 2, 3]);
    });

    test('applies mapper function to each item', () {
      final json = {'items': ['a', 'b']};
      final result = requireList<String>(
        json,
        'items',
        'TestClass',
        (item) => item.toString(),
      );
      expect(result, ['a', 'b']);
    });

    test('throws FormatException when field is missing', () {
      final json = <String, dynamic>{};
      expect(
        () => requireList<String>(
          json,
          'items',
          'TestClass',
          (item) => item.toString(),
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "items"'),
        )),
      );
    });

    test('throws FormatException when field has wrong type', () {
      final json = {'items': 'not a list'};
      expect(
        () => requireList<String>(
          json,
          'items',
          'TestClass',
          (item) => item.toString(),
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must be a List'),
        )),
      );
    });

    test('error message includes className', () {
      final json = <String, dynamic>{};
      expect(
        () => requireList<String>(
          json,
          'items',
          'MyClass',
          (item) => item.toString(),
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('MyClass.fromJson'),
        )),
      );
    });
  });
}

