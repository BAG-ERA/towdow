// EnhancedTextViewModel handles real-time markdown parsing for text fields
// Supports GitHub Flavored Markdown patterns like **bold** and URL detection

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Parse inline markdown patterns (bold, URLs, etc.)
  List<TextSpan> _parseInlineMarkdown(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    // Combined regex: match URLs, email addresses, phone numbers, or **bold**
    final combinedRegex = RegExp(r'([a-zA-Z]+://[^\s]+)|([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})|(\+?[\d\s\-\(\)]{7,})|(\*\*(.*?)\*\*)');
    int lastEnd = 0;
    for (final match in combinedRegex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      if (match.group(1) != null) {
        // URL match
        final url = match.group(1)!;
        spans.add(TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl(url),
        ));
      } else if (match.group(2) != null) {
        // Email match
        final email = match.group(2)!;
        spans.add(TextSpan(
          text: email,
          style: baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl('mailto:$email'),
        ));
      } else if (match.group(3) != null) {
        // Phone number match
        final phone = match.group(3)!;
        spans.add(TextSpan(
          text: phone,
          style: baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl('tel:${phone.replaceAll(RegExp(r'[\s\-\(\)]'), '')}'),
        ));
      } else if (match.group(4) != null) {
        // Bold match - check if the content inside has URLs or emails
        final boldText = match.group(5) ?? '';
        final nestedSpans = _parseInlineMarkdown(boldText, baseStyle.copyWith(fontWeight: FontWeight.bold));
        spans.addAll(nestedSpans);
      }
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

  /// Launch URL using url_launcher package
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Convert formatted text back to markdown for storage
  String encodeToMarkdown() {
    return _rawText; // For now, return raw text as markdown is preserved
  }
} 