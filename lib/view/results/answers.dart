import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shobaki_academy/model/widgets/zoomable_image.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/theme.dart';

class AnswersPage extends StatelessWidget {
  final Map<String, dynamic> answers; // questionId → studentAnswer
  final api = ApiClient();

  AnswersPage({super.key, required this.answers});

  Future<List<dynamic>> _fetchQuestions(context) async {
    if (answers.isEmpty) return [];
    final ids = answers.keys.toList();
    return await api.getQuestionsByIds(ids, context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إجاباتك'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _fetchQuestions(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: loading(context));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ: ${snapshot.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  'لا توجد إجابات',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              );
            }

            final questions = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index] as Map<String, dynamic>;
                final qId = question['id']?.toString() ?? '';
                final studentAnswer = answers[qId] ?? '';

                return questionCard(
                  id: qId,
                  content: question['content']?.toString() ?? '',
                  createdAt: question['created_at']?.toString() ?? '',
                  answers: question['answers'] is List
                      ? question['answers'] as List
                      : [],
                  correctAnswer: question['correct_answer']?.toString() ?? '',
                  studentAnswer: studentAnswer.toString(),
                  context: context,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget questionCard({
    required String id,
    required String content,
    required String createdAt,
    required List answers,
    required String correctAnswer,
    required String studentAnswer,
    required context,
  }) {
    final isCorrect = studentAnswer == correctAnswer;
    final statusColor = isCorrect ? AppTheme.primaryColor : Colors.red;
    final statusIcon = isCorrect ? Icons.check_circle : Icons.cancel;
    final statusText = isCorrect ? 'صحيح' : 'خاطئ';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 2),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Status + Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Content
            Text('السؤال', style: Theme.of(context).textTheme.titleSmall!),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ZoomableImage(imageUrl: content),
            ),
            const SizedBox(height: 16),

            // Answer Options
            if (answers.isNotEmpty) ...[
              Text('الخيارات', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...answers.asMap().entries.map((entry) {
                final index = entry.key;
                final answer = entry.value.toString();
                final isStudent = answer == studentAnswer;
                final isCorrectAnswer = answer == correctAnswer;

                Color bgColor = Colors.white;
                Color borderColor = Colors.grey.shade300;
                Color textColor = Colors.black;

                if (isCorrectAnswer) {
                  bgColor = AppTheme.primaryColor.withValues(alpha: 0.1);
                  borderColor = AppTheme.primaryColor;
                  textColor = AppTheme.primaryColor;
                } else if (isStudent && !isCorrect) {
                  bgColor = Colors.red.withValues(alpha: 0.1);
                  borderColor = Colors.red;
                  textColor = Colors.red;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        if (isCorrectAnswer)
                          Icon(
                            Icons.check,
                            color: AppTheme.primaryColor,
                            size: 20,
                          )
                        else if (isStudent && !isCorrect)
                          Icon(Icons.close, color: Colors.red, size: 20)
                        else
                          Text(
                            String.fromCharCode(65 + index), // A, B, C, D...
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            answer,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight:
                                  isCorrectAnswer || (isStudent && !isCorrect)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 16),

            // Student Answer Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجابتك:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? AppTheme.primaryColor : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    studentAnswer.isEmpty
                        ? 'لم تجب على هذا السؤال'
                        : studentAnswer,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (!isCorrect) ...[
                    const SizedBox(height: 10),
                    Text(
                      'الإجابة الصحيحة:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      correctAnswer,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return intl.DateFormat('yyyy/MM/dd-HH:mm').format(date);
    } catch (_) {
      return dateString;
    }
  }
}
