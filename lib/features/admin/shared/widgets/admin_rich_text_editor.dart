import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class AdminRichTextEditor extends StatefulWidget {
  const AdminRichTextEditor({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;

  @override
  State<AdminRichTextEditor> createState() => _AdminRichTextEditorState();
}

class _AdminRichTextEditorState extends State<AdminRichTextEditor> {
  late QuillController _quillController;

  @override
  void initState() {
    super.initState();
    final document = Document.fromJson(_parseJsonFromText(widget.controller.text));
    _quillController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillController.document.changes.listen((_) {
      final delta = _quillController.document.toDelta();
      widget.controller.text = jsonEncode(delta.toJson());
    });
  }

  List<dynamic> _parseJsonFromText(String text) {
    if (text.isEmpty) return const [{"insert": "\n"}];
    try {
      final parsed = jsonDecode(text);
      if (parsed is List) return parsed;
    } catch (_) {}
    return [
      {"insert": text},
      {"insert": "\n"},
    ];
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: QuillSimpleToolbar(controller: _quillController),
              ),
              SizedBox(
                height: 260,
                child: QuillEditor.basic(
                  controller: _quillController,
                  config: QuillEditorConfig(
                    placeholder: widget.hintText ?? 'Write here...',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
