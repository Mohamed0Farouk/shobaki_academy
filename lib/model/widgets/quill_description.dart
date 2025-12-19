import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:shobaki_academy/model/discription_model.dart';

class QuillDescription extends StatelessWidget {
  final QuillDescriptionModel model;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;
  final TextStyle? textStyle;

  const QuillDescription({
    super.key,
    required this.model,
    this.padding,
    this.decoration,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Create a properly initialized QuillController
    late final QuillController controller;
    try {
      // Parse the content and create a document
      final doc = Document.fromJson(jsonDecode(model.content));
      controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      debugPrint('Error parsing quill content: $e');
      // Create empty document if parsing fails
      controller = QuillController.basic();
    }

    // Create a basic QuillEditor for display only
    return Container(
      decoration: decoration,
      padding: padding,
      constraints: model.maxLines != null
          ? BoxConstraints(maxHeight: model.maxLines! * 24.0)
          : null,
      child: AbsorbPointer(
        absorbing: true,
        child: QuillEditor(
          controller: controller,
          focusNode: FocusNode(),
          scrollController: model.scrollController ?? ScrollController(),
          config: QuillEditorConfig(
            checkBoxReadOnly: true,
            scrollable: model.enableScroll,
            showCursor: false,
            autoFocus: false,
            expands: false,
          ),
        ),
      ),
    );
  }

  /// Static helper instead of factory constructor
  static Widget fromContent(
    String content, {
    Key? key,
    int? maxLines,
    bool enableScroll = true,
    ScrollController? scrollController,
    EdgeInsetsGeometry? padding,
    BoxDecoration? decoration,
    TextStyle? textStyle,
  }) {
    try {
      if (content.startsWith('[') && content.endsWith(']')) {
        // Looks like valid Quill Delta → return QuillDescription
        return QuillDescription(
          key: key,
          model: QuillDescriptionModel(
            content: content,
            maxLines: maxLines,
            enableScroll: enableScroll,
            scrollController: scrollController,
          ),
          padding: padding,
          decoration: decoration,

          textStyle: textStyle,
        );
      } else {
        // Not a valid Quill JSON → fallback to Text
        return Text(
          content,
          style: textStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      }
    } catch (e) {
      // If parsing fails → return Text fallback
      return Text(
        content,
        style: textStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
  }
}
