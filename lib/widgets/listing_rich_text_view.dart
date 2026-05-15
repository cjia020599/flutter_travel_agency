import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Read-only renderer for Quill delta JSON or plain text descriptions.
class ListingRichTextView extends StatefulWidget {
  const ListingRichTextView({
    super.key,
    required this.raw,
    this.maxHeight,
  });

  final String? raw;
  final double? maxHeight;

  @override
  State<ListingRichTextView> createState() => _ListingRichTextViewState();
}

class _ListingRichTextViewState extends State<ListingRichTextView> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: _documentFromRaw(widget.raw),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void didUpdateWidget(ListingRichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raw != widget.raw) {
      _controller.dispose();
      _controller = QuillController(
        document: _documentFromRaw(widget.raw),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Document _documentFromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return Document.fromJson(const [
        {'insert': '\n'},
      ]);
    }
    final trimmed = raw.trim();
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is List) {
        return Document.fromJson(parsed);
      }
      if (parsed is Map && parsed['ops'] is List) {
        return Document.fromJson(parsed['ops'] as List);
      }
    } catch (_) {}

    // Plain text or light HTML — show as readable paragraphs.
    final plain = _plainTextFromMaybeHtml(trimmed);
    return Document.fromJson([
      {'insert': plain},
      {'insert': '\n'},
    ]);
  }

  String _plainTextFromMaybeHtml(String input) {
    var s = input;
    if (s.contains('<') && s.contains('>')) {
      s = s
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '');
    }
    return s.replaceAll(RegExp(r'\s+\n'), '\n').trim();
  }

  bool get _hasVisibleText {
    final plain = _controller.document.toPlainText().trim();
    return plain.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasVisibleText) return const SizedBox.shrink();

    final editor = QuillEditor.basic(
      controller: _controller,
      config: QuillEditorConfig(
        showCursor: false,
        enableInteractiveSelection: false,
        padding: EdgeInsets.zero,
        autoFocus: false,
        expands: false,
        scrollable: false,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            Theme.of(context).textTheme.bodyMedium!.copyWith(
              height: 1.55,
              color: Colors.grey.shade800,
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(6, 0),
            VerticalSpacing.zero,
            null,
          ),
          h1: DefaultTextBlockStyle(
            Theme.of(context).textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A5F),
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(12, 8),
            VerticalSpacing.zero,
            null,
          ),
          h2: DefaultTextBlockStyle(
            Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E3A5F),
            ),
            HorizontalSpacing.zero,
            VerticalSpacing(10, 6),
            VerticalSpacing.zero,
            null,
          ),
          lists: DefaultListBlockStyle(
            Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.45),
            HorizontalSpacing.zero,
            VerticalSpacing(4, 0),
            VerticalSpacing(2, 0),
            null,
            null,
          ),
        ),
      ),
    );

    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: widget.maxHeight != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight!),
              child: SingleChildScrollView(child: editor),
            )
          : editor,
    );

    return child;
  }
}
