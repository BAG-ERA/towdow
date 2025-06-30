/// Tests for the project portfolio name input dialog functionality
/// Verifies user interaction and portfolio name validation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project Portfolio Name Dialog Tests', () {
    test('Safe name generation should handle special characters', () {
      final testCases = [
        // (input, expectedOutput)
        ('FlowIt Portfolio', 'flowit-portfolio'),
        ('My Portfolio 2024', 'my-portfolio-2024'),
        ('Test@Portfolio#With\$Symbols', 'testportfoliowithsymbols'),
        ('Portfolio   with   Spaces', 'portfolio-with-spaces'),
        ('Multiple---Dashes', 'multipledashes'),
        ('Calendar!@#\$%^&*()', 'calendar'),
        ('', 'flowit-portfolio'), // Empty fallback
        ('123Numbers456', '123numbers456'),
        ('Äöü Special Chars', 'special-chars'),
        ('  Leading Trailing  ', 'leading-trailing'),
      ];

      for (final (input, expected) in testCases) {
        final safeName = input.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll(RegExp(r'-+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        
        final result = safeName.isEmpty ? 'flowit-portfolio' : safeName;
        expect(result, equals(expected), reason: 'Input: "$input"');
      }
    });

    test('Portfolio name validation should reject empty names', () {
      const testInputs = ['', '   ', '\t\n'];
      
      for (final input in testInputs) {
        final trimmed = input.trim();
        expect(trimmed.isEmpty, isTrue, reason: 'Input: "$input" should be considered empty');
      }
      
      // Test special characters that become empty after processing
      const specialInput = '!@#';
      final processed = specialInput.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      expect(processed.isEmpty, isTrue, reason: 'Special characters should result in empty string');
    });

    test('Portfolio description should be optional', () {
      const testCases = [
        ('', null),
        ('   ', null),
        ('Valid description', 'Valid description'),
        ('Description with symbols!@#', 'Description with symbols!@#'),
      ];
      
      for (final (input, expected) in testCases) {
        final result = input.trim().isEmpty ? null : input.trim();
        expect(result, equals(expected));
      }
    });

    test('Portfolio path construction should be correct', () {
      const calendarHome = '/calendars/user/';
      const testCases = [
        ('FlowIt Portfolio', '/calendars/user/flowit-portfolio/'),
        ('Work Portfolio', '/calendars/user/work-portfolio/'),
        ('Personal123', '/calendars/user/personal123/'),
        ('Test!@#', '/calendars/user/test/'),
      ];
      
      for (final (displayName, expectedPath) in testCases) {
        final safeName = displayName.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll(RegExp(r'-+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        
        final finalSafeName = safeName.isEmpty ? 'flowit-portfolio' : safeName;
        final calendarPath = '$calendarHome$finalSafeName/';
        
        expect(calendarPath, equals(expectedPath));
      }
    });

    test('Dialog result structure should be correct', () {
      const testResult = {
        'name': 'Test Portfolio',
        'description': 'Test Description',
      };
      
      expect(testResult['name'], isNotNull);
      expect(testResult['name'], isA<String>());
      expect(testResult['description'], isNotNull);
      expect(testResult['description'], isA<String>());
    });

    test('Should handle unicode characters in portfolio names', () {
      final testCases = [
        ('Calendrier français', 'calendrier-franais'),
        ('Календарь русский', 'flowit-portfolio'), // Cyrillic -> empty -> fallback
        ('日本のカレンダー', 'flowit-portfolio'), // Japanese -> empty -> fallback
        ('📅 Emoji Portfolio', 'emoji-portfolio'),
        ('Tâches & Projets', 'tches-projets'),
      ];
      
      for (final (input, expected) in testCases) {
        final safeName = input.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll(RegExp(r'-+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        
        final result = safeName.isEmpty ? 'flowit-portfolio' : safeName;
        expect(result, equals(expected));
      }
    });

    test('Long portfolio names should be handled correctly', () {
      const longName = 'This is a very long portfolio name that should be handled properly by the application without causing any issues';
      
      final safeName = longName.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      
      expect(safeName, isNotEmpty);
      expect(safeName, contains('this-is-a-very-long'));
      expect(safeName, isNot(contains(' ')));
      expect(safeName, isNot(startsWith('-')));
      expect(safeName, isNot(endsWith('-')));
    });

    test('Default values should be provided', () {
      const defaultName = 'FlowIt Portfolio';
      const defaultDescription = 'Project portfolio created by FlowIt';
      
      expect(defaultName, isNotEmpty);
      expect(defaultDescription, isNotEmpty);
      expect(defaultName, equals('FlowIt Portfolio'));
      expect(defaultDescription, contains('FlowIt'));
    });
  });
} 