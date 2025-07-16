import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/presentation/viewmodels/enhanced_text_viewmodel.dart';

void main() {
  group('EnhancedTextViewModel', () {
    late EnhancedTextViewModel viewModel;

    setUp(() {
      viewModel = EnhancedTextViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('should detect and format URLs correctly', () {
      const text = 'Check out https://example.com and http://test.org for more info';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans: text before URL, URL, text after URL
      expect(spans.length, greaterThan(1));

      // Find the URL span
      final urlSpan = spans.firstWhere(
        (span) => span.text?.contains('https://example.com') == true,
        orElse: () => spans.first,
      );

      // URL should be styled with blue color and underline
      expect(urlSpan.style?.color, Colors.blue);
      expect(urlSpan.style?.decoration, TextDecoration.underline);
      expect(urlSpan.recognizer, isNotNull);
    });

    test('should detect and format URLs with different protocols', () {
      const text = 'Download from ftp://files.example.com or visit file:///local/path';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans
      expect(spans.length, greaterThan(1));

      // Find the FTP URL span
      final ftpSpan = spans.firstWhere(
        (span) => span.text?.contains('ftp://files.example.com') == true,
        orElse: () => spans.first,
      );
      expect(ftpSpan.style?.color, Colors.blue);
      expect(ftpSpan.style?.decoration, TextDecoration.underline);
      expect(ftpSpan.recognizer, isNotNull);

      // Find the FILE URL span
      final fileSpan = spans.firstWhere(
        (span) => span.text?.contains('file:///local/path') == true,
        orElse: () => spans.first,
      );
      expect(fileSpan.style?.color, Colors.blue);
      expect(fileSpan.style?.decoration, TextDecoration.underline);
      expect(fileSpan.recognizer, isNotNull);
    });

    test('should handle mixed markdown and URLs', () {
      const text = '**Bold text** with https://example.com and more **bold**';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans for bold text and URL
      expect(spans.length, greaterThan(1));

      // Check for bold text
      final boldSpan = spans.firstWhere(
        (span) => span.style?.fontWeight == FontWeight.bold,
        orElse: () => spans.first,
      );
      expect(boldSpan.style?.fontWeight, FontWeight.bold);

      // Check for URL
      final urlSpan = spans.firstWhere(
        (span) => span.text?.contains('https://example.com') == true,
        orElse: () => spans.first,
      );
      expect(urlSpan.style?.color, Colors.blue);
      expect(urlSpan.style?.decoration, TextDecoration.underline);
    });

    test('should handle empty text', () {
      const text = '';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      expect(spans.length, 1);
      expect(spans.first.text, '');
      expect(spans.first.style, baseStyle);
    });

    test('should handle text without URLs or markdown', () {
      const text = 'Plain text without any formatting';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      expect(spans.length, 1);
      expect(spans.first.text, text);
      expect(spans.first.style, baseStyle);
    });

    test('should handle multiple URLs in same text', () {
      const text = 'First https://example1.com then https://example2.com';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans
      expect(spans.length, greaterThan(1));

      // Count URL spans
      final urlSpans = spans.where((span) => 
        span.text?.contains('https://') == true
      ).toList();
      
      expect(urlSpans.length, 2);
      
      // All URL spans should be styled
      for (final span in urlSpans) {
        expect(span.style?.color, Colors.blue);
        expect(span.style?.decoration, TextDecoration.underline);
        expect(span.recognizer, isNotNull);
      }
    });

    test('should detect and format email addresses correctly', () {
      const text = 'Contact us at test@example.com or support@company.org';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans: text before email, email, text after email
      expect(spans.length, greaterThan(1));

      // Find the email span
      final emailSpan = spans.firstWhere(
        (span) => span.text?.contains('test@example.com') == true,
        orElse: () => spans.first,
      );

      // Email should be styled with blue color and underline
      expect(emailSpan.style?.color, Colors.blue);
      expect(emailSpan.style?.decoration, TextDecoration.underline);
      expect(emailSpan.recognizer, isNotNull);
    });

    test('should handle mixed URLs, emails, and markdown', () {
      const text = 'Visit https://example.com or email **support@company.org** for help';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans for URL, email, and bold text
      expect(spans.length, greaterThan(1));

      // Check for URL
      final urlSpan = spans.firstWhere(
        (span) => span.text?.contains('https://example.com') == true,
        orElse: () => spans.first,
      );
      expect(urlSpan.style?.color, Colors.blue);
      expect(urlSpan.style?.decoration, TextDecoration.underline);

      // Check for email
      final emailSpan = spans.firstWhere(
        (span) => span.text?.contains('support@company.org') == true,
        orElse: () => spans.first,
      );
      expect(emailSpan.style?.color, Colors.blue);
      expect(emailSpan.style?.decoration, TextDecoration.underline);

      // Check for bold text
      final boldSpan = spans.firstWhere(
        (span) => span.style?.fontWeight == FontWeight.bold,
        orElse: () => spans.first,
      );
      expect(boldSpan.style?.fontWeight, FontWeight.bold);
    });

    test('should detect and format phone numbers correctly', () {
      const text = 'Call us at +1 (555) 123-4567 or 555-987-6543';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans: text before phone, phone, text after phone
      expect(spans.length, greaterThan(1));

      // Find the phone span
      final phoneSpan = spans.firstWhere(
        (span) => span.text?.contains('+1 (555) 123-4567') == true,
        orElse: () => spans.first,
      );

      // Phone should be styled with blue color and underline
      expect(phoneSpan.style?.color, Colors.blue);
      expect(phoneSpan.style?.decoration, TextDecoration.underline);
      expect(phoneSpan.recognizer, isNotNull);
    });

    test('should handle mixed URLs, emails, phone numbers, and markdown', () {
      const text = 'Visit https://example.com, email support@company.org, or call **+1-555-123-4567**';
      const baseStyle = TextStyle(fontSize: 14);

      final spans = viewModel.decode(text, baseStyle);

      // Should have multiple spans for URL, email, phone, and bold text
      expect(spans.length, greaterThan(1));

      // Check for URL
      final urlSpan = spans.firstWhere(
        (span) => span.text?.contains('https://example.com') == true,
        orElse: () => spans.first,
      );
      expect(urlSpan.style?.color, Colors.blue);
      expect(urlSpan.style?.decoration, TextDecoration.underline);

      // Check for email
      final emailSpan = spans.firstWhere(
        (span) => span.text?.contains('support@company.org') == true,
        orElse: () => spans.first,
      );
      expect(emailSpan.style?.color, Colors.blue);
      expect(emailSpan.style?.decoration, TextDecoration.underline);

      // Check for phone number
      final phoneSpan = spans.firstWhere(
        (span) => span.text?.contains('+1-555-123-4567') == true,
        orElse: () => spans.first,
      );
      expect(phoneSpan.style?.color, Colors.blue);
      expect(phoneSpan.style?.decoration, TextDecoration.underline);

      // Check for bold text
      final boldSpan = spans.firstWhere(
        (span) => span.style?.fontWeight == FontWeight.bold,
        orElse: () => spans.first,
      );
      expect(boldSpan.style?.fontWeight, FontWeight.bold);
    });
  });
} 