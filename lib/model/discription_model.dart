import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';


class QuillDescriptionModel {
  final String content; // Raw quill delta content from DB
  final int? maxLines;
  final bool enableScroll;
  final ScrollController? scrollController;

  QuillDescriptionModel({
    required this.content,
    this.maxLines,
    this.enableScroll = true,
    this.scrollController,
  });

  // Create QuillController from the stored content
  QuillController get controller {
    try {
      return QuillController(
        document: Document.fromJson(jsonDecode(content)),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      // Fallback to empty document if parsing fails
      debugPrint('Error parsing quill content: $e');
      return QuillController.basic();
    }
  }

  // Factory constructor from JSON (for DB operations)
  factory QuillDescriptionModel.fromJson(Map<String, dynamic> json) {
    return QuillDescriptionModel(
      content: json['content'] as String,
      maxLines: json['maxLines'] as int?,
      enableScroll: json['enableScroll'] as bool? ?? true,
    );
  }

  // Convert model to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'maxLines': maxLines,
      'enableScroll': enableScroll,
    };
  }

  // Create a copy of the model with modified properties
  QuillDescriptionModel copyWith({
    String? content,
    int? maxLines,
    bool? enableScroll,
    ScrollController? scrollController,
  }) {
    return QuillDescriptionModel(
      content: content ?? this.content,
      maxLines: maxLines ?? this.maxLines,
      enableScroll: enableScroll ?? this.enableScroll,
      scrollController: scrollController ?? this.scrollController,
    );
  }
}
