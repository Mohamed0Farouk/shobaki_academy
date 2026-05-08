import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  final SupabaseClient _client = Supabase.instance.client;

  // Authentication: Sign In
  Future<Map> signIn(String email, String password) async {
    try {
      final response = await fetchWithConditions(
        'students',
        filters: {'email': email, 'password': password},
      );
      return response[0];
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Authentication: Sign Out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  // Fetch Data
  Future<List<dynamic>> fetchData(String table) async {
    try {
      final response = await _client.from(table).select();
      return response;
    } catch (e) {
      throw Exception('Fetch data failed: $e');
    }
  }

  Future<List<dynamic>> fetchWithConditions(
    String table, {
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    String? select,
    int? from, // Start index for pagination
    int? to, // End index for pagination
  }) async {
    try {
      var query = _client.from(table).select(select ?? "*");

      if (filters != null) {
        for (var entry in filters.entries) {
          final key = entry.key;
          final value = entry.value;

          // support operator-based filters:
          // filters: { 'title': {'operator':'ilike','value':'%term%'} }
          if (value is Map && value.containsKey('operator')) {
            final op = value['operator'];
            final v = value['value'];
            switch (op) {
              case 'ilike':
                query = query.ilike(key, v);
                break;
              case 'like':
                query = query.like(key, v);
                break;
              case 'neq':
                query = query.neq(key, v);
                break;
              case 'gt':
                query = query.gt(key, v);
                break;
              case 'lt':
                query = query.lt(key, v);
                break;
              case 'gte':
                query = query.gte(key, v);
                break;
              case 'lte':
                query = query.lte(key, v);
                break;
              case 'eq':
              default:
                query = query.eq(key, v);
            }
          } else {
            query = query.eq(key, value);
          }
        }
      }

      // ordering
      if (orderBy != null) {
        query = query..order(orderBy, ascending: ascending);
      } else {
        // attempt to order by created_at if present
        try {
          query = query..order('created_at', ascending: ascending);
        } catch (_) {
          // ignore if column doesn't exist
        }
      }

      // range / pagination
      if (from != null && to != null) {
        query = query..range(from, to);
      }

      final response = await query;

      return response;
    } catch (e, stackTrace) {
      final logger = Logger();
      logger.e('Fetch error: $e\n$stackTrace');
      throw Exception('Fetch failed: $e');
    }
  }

  // Convenience search method using ilike for topics (title or description)
  Future<List<Map<String, dynamic>>> searchTopics(String queryText) async {
    try {
      if (queryText.trim().isEmpty) return [];

      final q = '%${queryText.trim()}%';

      final response = await _client
          .from('topics')
          .select()
          .ilike('title', q)
          .or('description.ilike.$q');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      showSnackbar(
        "خطأ في البحث",
        "حدث خطأ أثناء البحث: $e",
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return [];
    }
  }

  // Insert Data
  Future<Map> insertData(String table, Map<String, dynamic> data) async {
    try {
      final response = await _client.from(table).insert(data).select();
      return response[0];
    } catch (e) {
      throw Exception('Insert data failed: $e');
    }
  }

  // Update Data
  Future<void> updateData(
    String table,
    Map<String, dynamic> updates,
    Map<String, Object> condition,
  ) async {
    try {
      await _client.from(table).update(updates).match(condition);
    } catch (e) {
      throw Exception('Update data failed: $e');
    }
  }

  Future<void> updateUserStage(String userId, String newStage) async {
    try {
      // Delete user subscriptions
      await _client
          .from('students_subscriptions')
          .delete()
          .eq('student_id', userId);

      // Delete user's wrong answers
      await _client
          .from('students_wrong_answers')
          .delete()
          .eq('student_id', userId);

      // Update the stage
      await _client
          .from('students')
          .update({'stage': newStage})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Update user stage failed: $e');
    }
  }

  Future<void> updateUserPhoneNumber(String userId, String newNumber) async {
    try {
      // Update the stage
      await _client
          .from('students')
          .update({'phone_number': newNumber})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Update user phone number failed: $e');
    }
  }

  Future<void> updateUserParentPhoneNumber(
    String userId,
    String newNumber,
  ) async {
    try {
      // Update the stage
      await _client
          .from('students')
          .update({'parent_phone_number': newNumber})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Update user parent phone number failed: $e');
    }
  }

  Future<void> deleteAccount({required id}) async {
    try {
      await _client.from('students').delete().eq('id', id);
      await _client
          .from('students_subscriptions')
          .delete()
          .eq('student_id', id);

      // Delete user's wrong answers
      await _client
          .from('students_wrong_answers')
          .delete()
          .eq('student_id', id);
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Delete Account failed: $e');
    }
  }

  Future<List> getStudentSolvedHomeworkGrades({required studentId}) async {
    try {
      final response = await _client
          .from("students_solved_homeworks")
          .select(
            'grade, answers, created_at, homework_id, homeworks(*)',
          ) // join with homeworks table
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      showSnackbar(
        "خطأ في جلب درجات الواجبات",
        "حدث خطأ أثناء جلب درجات الواجبات: $e",
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return []; // You could also return null or handle it differently
    }
  }

  Future<List> getStudentSolvedExamsGrades({required studentId}) async {
    try {
      final response = await _client
          .from("students_solved_exams")
          .select(
            'grade, answers, created_at, exam_id, exams(*)',
          ) // join with homeworks table
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      showSnackbar(
        "خطأ في جلب درجات الامتحانات",
        "حدث خطأ أثناء جلب درجات الامتحانات: $e",
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return []; // You could also return null or handle it differently
    }
  }

  Future<List<Map<String, dynamic>>> getQuestionsByIds(
    List<String> questionIds,
    context,
  ) async {
    try {
      if (questionIds.isEmpty) {
        return [];
      }

      final response = await _client
          .from("questions_bank")
          .select()
          .inFilter("id", questionIds);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      showSnackbar(
        "خطأ في جلب الأسئلة",
        "حدث خطأ أثناء جلب الأسئلة: $e",
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return [];
    }
  }
}
