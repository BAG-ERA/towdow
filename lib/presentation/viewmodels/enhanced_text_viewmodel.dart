// EnhancedTextViewModel handles real-time markdown parsing for text fields
// Supports GitHub Flavored Markdown patterns like **bold**

import 'package:flutter/material.dart';

class EnhancedTextViewModel extends ChangeNotifier {
  String _rawText = '';
  List<TextSpan> _spans = [];

  String get rawText => _rawText;
  List<TextSpan> get spans => _spans;

  /// Decode markdown text and return formatted TextSpan list
  List<TextSpan> decode(String text, TextStyle baseStyle) {
    _rawText = text;
    _spans = _parseMarkdown(text, baseStyle);
    return _spans;
  }

  /// Parse markdown patterns and return TextSpan list
  List<TextSpan> _parseMarkdown(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: '', style: baseStyle)];

    final spans = <TextSpan>[];
    final lines = text.split('\n');

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      
      // Handle unordered lists
      if (line.trim().startsWith(RegExp(r'^[-\*\+]\s+'))) {
        final listContent = line.trim().substring(2);
        spans.addAll(_parseInlineMarkdown('• $listContent', baseStyle));
      } else {
        spans.addAll(_parseInlineMarkdown(line, baseStyle));
      }

      // Add line break if not the last line
      if (lineIndex < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return spans;
  }

  /// Parse inline markdown patterns (bold, etc.)
  List<TextSpan> _parseInlineMarkdown(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*'); // Bold pattern: **text**
    
    int lastEnd = 0;
    
    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1) ?? '',
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }
    
    return spans;
  }

  /// Convert formatted text back to markdown for storage
  String encodeToMarkdown() {
    return _rawText; // For now, return raw text as markdown is preserved
  }
} 