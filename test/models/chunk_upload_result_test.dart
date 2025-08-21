import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/chunk_upload_result.dart';

void main() {
  group('ChunkUploadResult', () {
    test('should create instance with all properties', () {
      const result = ChunkUploadResult(
        success: true,
        errorMessage: null,
        isRetryable: false,
        chunkIndex: 5,
      );

      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.isRetryable, isFalse);
      expect(result.chunkIndex, equals(5));
      expect(result.failed, isFalse);
    });

    test('should create instance with error message', () {
      const result = ChunkUploadResult(
        success: false,
        errorMessage: 'Network timeout',
        isRetryable: true,
        chunkIndex: 3,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, equals('Network timeout'));
      expect(result.isRetryable, isTrue);
      expect(result.chunkIndex, equals(3));
      expect(result.failed, isTrue);
    });

    group('factory constructors', () {
      test('success should create successful result', () {
        final result = ChunkUploadResult.success(7);

        expect(result.success, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.isRetryable, isFalse);
        expect(result.chunkIndex, equals(7));
        expect(result.failed, isFalse);
      });

      test('retryableFailure should create retryable failure result', () {
        final result = ChunkUploadResult.retryableFailure(
          2,
          'Connection timeout',
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('Connection timeout'));
        expect(result.isRetryable, isTrue);
        expect(result.chunkIndex, equals(2));
        expect(result.failed, isTrue);
      });

      test('permanentFailure should create permanent failure result', () {
        final result = ChunkUploadResult.permanentFailure(
          4,
          'Authentication failed',
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('Authentication failed'));
        expect(result.isRetryable, isFalse);
        expect(result.chunkIndex, equals(4));
        expect(result.failed, isTrue);
      });
    });

    group('failed getter', () {
      test('should return true when success is false', () {
        const result = ChunkUploadResult(
          success: false,
          errorMessage: 'Error',
          isRetryable: true,
          chunkIndex: 0,
        );

        expect(result.failed, isTrue);
      });

      test('should return false when success is true', () {
        const result = ChunkUploadResult(
          success: true,
          errorMessage: null,
          isRetryable: false,
          chunkIndex: 0,
        );

        expect(result.failed, isFalse);
      });
    });

    group('equality and hashCode', () {
      test('should be equal when all properties match', () {
        const result1 = ChunkUploadResult(
          success: true,
          errorMessage: 'test error',
          isRetryable: false,
          chunkIndex: 5,
        );

        const result2 = ChunkUploadResult(
          success: true,
          errorMessage: 'test error',
          isRetryable: false,
          chunkIndex: 5,
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('should not be equal when properties differ', () {
        const result1 = ChunkUploadResult(
          success: true,
          errorMessage: null,
          isRetryable: false,
          chunkIndex: 5,
        );

        const result2 = ChunkUploadResult(
          success: false, // different
          errorMessage: null,
          isRetryable: false,
          chunkIndex: 5,
        );

        expect(result1, isNot(equals(result2)));
      });

      test('should not be equal when error messages differ', () {
        const result1 = ChunkUploadResult(
          success: false,
          errorMessage: 'error 1',
          isRetryable: true,
          chunkIndex: 0,
        );

        const result2 = ChunkUploadResult(
          success: false,
          errorMessage: 'error 2', // different
          isRetryable: true,
          chunkIndex: 0,
        );

        expect(result1, isNot(equals(result2)));
      });

      test('should not be equal when chunk indices differ', () {
        const result1 = ChunkUploadResult(
          success: true,
          errorMessage: null,
          isRetryable: false,
          chunkIndex: 1,
        );

        const result2 = ChunkUploadResult(
          success: true,
          errorMessage: null,
          isRetryable: false,
          chunkIndex: 2, // different
        );

        expect(result1, isNot(equals(result2)));
      });

      test('should not be equal when isRetryable differs', () {
        const result1 = ChunkUploadResult(
          success: false,
          errorMessage: 'error',
          isRetryable: true,
          chunkIndex: 0,
        );

        const result2 = ChunkUploadResult(
          success: false,
          errorMessage: 'error',
          isRetryable: false, // different
          chunkIndex: 0,
        );

        expect(result1, isNot(equals(result2)));
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        const result = ChunkUploadResult(
          success: false,
          errorMessage: 'Network error',
          isRetryable: true,
          chunkIndex: 3,
        );

        final string = result.toString();
        expect(string, contains('ChunkUploadResult('));
        expect(string, contains('success: false'));
        expect(string, contains('errorMessage: Network error'));
        expect(string, contains('isRetryable: true'));
        expect(string, contains('chunkIndex: 3'));
      });

      test('should handle null error message in toString', () {
        const result = ChunkUploadResult(
          success: true,
          errorMessage: null,
          isRetryable: false,
          chunkIndex: 1,
        );

        final string = result.toString();
        expect(string, contains('errorMessage: null'));
      });
    });

    group('edge cases', () {
      test('should handle zero chunk index', () {
        final result = ChunkUploadResult.success(0);
        expect(result.chunkIndex, equals(0));
      });

      test('should handle large chunk index', () {
        final result = ChunkUploadResult.success(999999);
        expect(result.chunkIndex, equals(999999));
      });

      test('should handle empty error message', () {
        const result = ChunkUploadResult(
          success: false,
          errorMessage: '',
          isRetryable: true,
          chunkIndex: 0,
        );

        expect(result.errorMessage, equals(''));
      });

      test('should handle very long error message', () {
        final longError = 'A' * 1000;
        final result = ChunkUploadResult.retryableFailure(0, longError);
        
        expect(result.errorMessage, equals(longError));
        expect(result.errorMessage!.length, equals(1000));
      });
    });
  });
}