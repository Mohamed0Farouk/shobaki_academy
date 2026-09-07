import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/books_controller.dart';
import 'package:shobaki_academy/controller/subscription_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';

/// A fake ApiClient that serves the tables given in tests and records inserts.
/// Any other ApiClient member is handled by [noSuchMethod].
class FakeApiClient implements ApiClient {
  final Map<String, List<Map<String, dynamic>>> tables = {};
  final List<Map<String, dynamic>> inserted = [];

  @override
  Future<List<dynamic>> fetchWithConditions(
    String table, {
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    String? select,
    int? from,
    int? to,
  }) async {
    var rows = List<Map<String, dynamic>>.from(tables[table] ?? const []);
    if (filters != null) {
      rows = rows.where((row) {
        return filters.entries.every((entry) {
          final key = entry.key;
          final value = entry.value;
          if (value is Map && value.containsKey('operator')) return true;
          final cell = row[key];
          return cell == value || '${cell ?? ''}' == '${value ?? ''}';
        });
      }).toList();
    }
    return rows;
  }

  @override
  Future<Map> insertData(String table, Map<String, dynamic> data) async {
    inserted.add(data);
    return data;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} is not stubbed in FakeApiClient',
      );
}

Map<String, dynamic> code({required String code, Object? allowedBooks}) => {
      'student_id': 'u1',
      'code': code,
      if (allowedBooks != null) 'allowed_books': allowedBooks,
    };

void main() {
  group('SubscriptionController.isBookAllowed', () {
    test('allows when allowed_books is missing/null', () {
      expect(SubscriptionController.isBookAllowed(null, 5), isTrue);
    });

    test('allows when allowed_books is an empty list', () {
      expect(SubscriptionController.isBookAllowed(<int>[], 5), isTrue);
    });

    test('allows when the book id is in the list', () {
      expect(SubscriptionController.isBookAllowed([1, 2, 5], 5), isTrue);
    });

    test('rejects when the book id is not in the list', () {
      expect(SubscriptionController.isBookAllowed([1, 2, 3], 9), isFalse);
    });

    test('matches allowed_books entries stored as strings', () {
      expect(SubscriptionController.isBookAllowed(['1', '5'], 5), isTrue);
      expect(SubscriptionController.isBookAllowed(['1', '5'], 6), isFalse);
    });
  });

  group('SubscriptionController.buildBookSubscriptionRow', () {
    test('builds a per-book subscription row', () {
      final row = SubscriptionController.buildBookSubscriptionRow('u1', 7);

      expect(row['student_id'], 'u1');
      expect(row['book_id'], 7);
      expect(row['topic_id'], isNull);
      expect(row['subscription_type'], 'books');
    });
  });

  group('SubscriptionController.validateBookCode', () {
    test('returns invalidCode for an unknown code', () async {
      final api = FakeApiClient();
      final controller = SubscriptionController(api: api);

      expect(
        await controller.validateBookCode('WRONG', 'u1', 5),
        BookCodeValidationStatus.invalidCode,
      );
    });

    test('returns bookNotAllowed when the code does not include the book',
        () async {
      final api = FakeApiClient()
        ..tables['student_codes'] = [
          code(code: 'CODE', allowedBooks: [1, 2, 3]),
        ];
      final controller = SubscriptionController(api: api);

      expect(
        await controller.validateBookCode('CODE', 'u1', 9),
        BookCodeValidationStatus.bookNotAllowed,
      );
    });

    test('returns ok when the code includes the book', () async {
      final api = FakeApiClient()
        ..tables['student_codes'] = [
          code(code: 'CODE', allowedBooks: [1, 5]),
        ];
      final controller = SubscriptionController(api: api);

      expect(
        await controller.validateBookCode('CODE', 'u1', 5),
        BookCodeValidationStatus.ok,
      );
    });

    test('returns ok when the code has no allowed_books', () async {
      final api = FakeApiClient()
        ..tables['student_codes'] = [code(code: 'CODE')];
      final controller = SubscriptionController(api: api);

      expect(
        await controller.validateBookCode('CODE', 'u1', 5),
        BookCodeValidationStatus.ok,
      );
    });

    test('returns ok when allowed_books is an empty list', () async {
      final api = FakeApiClient()
        ..tables['student_codes'] = [
          code(code: 'CODE', allowedBooks: <int>[]),
        ];
      final controller = SubscriptionController(api: api);

      expect(
        await controller.validateBookCode('CODE', 'u1', 5),
        BookCodeValidationStatus.ok,
      );
    });

    test('matches string allowed_books entries', () async {
      final api = FakeApiClient()
        ..tables['student_codes'] = [
          code(code: 'CODE', allowedBooks: ['1', '5']),
        ];
      final controller = SubscriptionController(api: api);

      expect(
        await controller.validateBookCode('CODE', 'u1', 5),
        BookCodeValidationStatus.ok,
      );
      expect(
        await controller.validateBookCode('CODE', 'u1', 6),
        BookCodeValidationStatus.bookNotAllowed,
      );
    });
  });

  group('BooksController.checkBookSubscription', () {
    setUp(() {
      Get.put(LocalDB(), permanent: true);
    });

    BooksController buildController(FakeApiClient api) {
      final controller = BooksController(api: api);
      controller.userId.value = 'u1';
      controller.isGuest.value = false;
      controller.isReviewer.value = false;
      return controller;
    }

    test('per-book check is true only when a matching book_id row exists',
        () async {
      final api = FakeApiClient()
        ..tables['students_subscriptions'] = [
          {'student_id': 'u1', 'subscription_type': 'books', 'book_id': 3},
        ];
      final controller = buildController(api);

      expect(await controller.checkBookSubscription(bookId: 3), isTrue);
      expect(await controller.checkBookSubscription(bookId: 4), isFalse);
    });

    test('global check is true when any books subscription exists', () async {
      final api = FakeApiClient()
        ..tables['students_subscriptions'] = [
          {'student_id': 'u1', 'subscription_type': 'books', 'book_id': 3},
        ];
      final controller = buildController(api);

      expect(await controller.checkBookSubscription(), isTrue);
    });

    test('global check is false when no books subscription exists', () async {
      final api = FakeApiClient();
      final controller = buildController(api);

      expect(await controller.checkBookSubscription(), isFalse);
    });

    test('returns false for guests, reviewers and empty user id', () async {
      final api = FakeApiClient()
        ..tables['students_subscriptions'] = [
          {'student_id': 'u1', 'subscription_type': 'books', 'book_id': 3},
        ];

      final guest = buildController(api)..isGuest.value = true;
      expect(await guest.checkBookSubscription(bookId: 3), isFalse);

      final reviewer = buildController(api)..isReviewer.value = true;
      expect(await reviewer.checkBookSubscription(bookId: 3), isFalse);

      final noUser = buildController(api)..userId.value = '';
      expect(await noUser.checkBookSubscription(bookId: 3), isFalse);
    });
  });
}