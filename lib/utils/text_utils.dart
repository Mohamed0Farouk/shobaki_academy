import 'dart:convert';

String plainTextFromContent(String content) {
  if (!content.startsWith('[') || !content.endsWith(']')) return content;
  try {
    final dynamic jsonData = jsonDecode(content);
    if (jsonData is List && jsonData.isNotEmpty) {
      final extractedTexts = <String>[];
      for (final op in jsonData) {
        if (op is Map &&
            op.containsKey('insert') &&
            op['insert'] is String) {
          extractedTexts.add(op['insert'] as String);
        }
      }
      if (extractedTexts.isNotEmpty) {
        return extractedTexts.join('').trim();
      }
    }
  } catch (_) {
    // fall through to original content
  }
  return content;
}
