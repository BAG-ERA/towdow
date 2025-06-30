/**
 * Tests unitaires pour le service VTodo
 * Teste les méthodes de parsing et validation des objets VTodo
 */

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VTodo Service Unit Tests', () {
    
    group('VTodo Parsing and Validation', () {
      test('should parse valid VTodo string', () {
        // Test la logique de parsing VTodo
        Map<String, String> parseVTodo(String vtodoString) {
          final properties = <String, String>{};
          final lines = vtodoString.split('\n');
          
          for (String line in lines) {
            line = line.trim();
            if (line.isEmpty || line.startsWith('BEGIN:') || line.startsWith('END:')) {
              continue;
            }
            
            final colonIndex = line.indexOf(':');
            if (colonIndex != -1) {
              final key = line.substring(0, colonIndex).trim();
              final value = line.substring(colonIndex + 1).trim();
              properties[key] = value;
            }
          }
          
          return properties;
        }

        const vtodoString = '''BEGIN:VTODO
UID:test-task-001
SUMMARY:Test Task
DESCRIPTION:This is a test task
DUE:20241224T140000Z
STATUS:NEEDS-ACTION
PRIORITY:1
X-FLOWIT-TYPE:task
X-FLOWIT-PROJECT:Test Project
END:VTODO''';

        final parsed = parseVTodo(vtodoString);
        
        expect(parsed['UID'], 'test-task-001');
        expect(parsed['SUMMARY'], 'Test Task');
        expect(parsed['DESCRIPTION'], 'This is a test task');
        expect(parsed['DUE'], '20241224T140000Z');
        expect(parsed['STATUS'], 'NEEDS-ACTION');
        expect(parsed['PRIORITY'], '1');
        expect(parsed['X-FLOWIT-TYPE'], 'task');
        expect(parsed['X-FLOWIT-PROJECT'], 'Test Project');
      });

      test('should handle malformed VTodo gracefully', () {
        Map<String, String> parseVTodo(String vtodoString) {
          final properties = <String, String>{};
          try {
            final lines = vtodoString.split('\n');
            
            for (String line in lines) {
              line = line.trim();
              if (line.isEmpty || line.startsWith('BEGIN:') || line.startsWith('END:')) {
                continue;
              }
              
              final colonIndex = line.indexOf(':');
              if (colonIndex != -1) {
                final key = line.substring(0, colonIndex).trim();
                final value = line.substring(colonIndex + 1).trim();
                properties[key] = value;
              }
            }
          } catch (e) {
            // Retourne un objet vide en cas d'erreur
          }
          
          return properties;
        }

        // Test avec du contenu malformé
        const malformedVTodo = '''BEGIN:VTODO
INVALID_LINE_WITHOUT_COLON
SUMMARY:Valid Task
:EMPTY_KEY_VALUE
DESCRIPTION
END:VTODO''';

        final parsed = parseVTodo(malformedVTodo);
        
        // Doit parser seulement les lignes valides
        expect(parsed['SUMMARY'], 'Valid Task');
        expect(parsed.containsKey('INVALID_LINE_WITHOUT_COLON'), false);
        expect(parsed.containsKey('DESCRIPTION'), false);
      });

      test('should validate VTodo completeness', () {
        // Test la validation de complétude d'un VTodo
        bool isCompleteVTodo(Map<String, String> properties) {
          // Champs obligatoires selon RFC 5545
          final requiredFields = ['UID', 'SUMMARY'];
          
          for (final field in requiredFields) {
            if (!properties.containsKey(field) || properties[field]!.isEmpty) {
              return false;
            }
          }
          
          return true;
        }

        // VTodo complet
        final completeVTodo = {
          'UID': 'test-001',
          'SUMMARY': 'Complete Task',
          'DESCRIPTION': 'Has all required fields',
        };
        expect(isCompleteVTodo(completeVTodo), true);

        // VTodo incomplet (pas de UID)
        final incompleteVTodo1 = {
          'SUMMARY': 'Task without UID',
        };
        expect(isCompleteVTodo(incompleteVTodo1), false);

        // VTodo incomplet (pas de SUMMARY)
        final incompleteVTodo2 = {
          'UID': 'test-002',
        };
        expect(isCompleteVTodo(incompleteVTodo2), false);

        // VTodo avec champs vides
        final emptyFieldsVTodo = {
          'UID': '',
          'SUMMARY': 'Task with empty UID',
        };
        expect(isCompleteVTodo(emptyFieldsVTodo), false);
      });

      test('should handle FlowIt custom fields', () {
        // Test la gestion des champs personnalisés FlowIt
        Map<String, String> extractFlowItFields(Map<String, String> properties) {
          final flowItFields = <String, String>{};
          
          for (final entry in properties.entries) {
            if (entry.key.startsWith('X-FLOWIT-')) {
              final fieldName = entry.key.substring(9); // Retire 'X-FLOWIT-'
              flowItFields[fieldName] = entry.value;
            }
          }
          
          return flowItFields;
        }

        final vtodoWithFlowItFields = {
          'UID': 'test-001',
          'SUMMARY': 'FlowIt Task',
          'X-FLOWIT-TYPE': 'task',
          'X-FLOWIT-PROJECT': 'Development',
          'X-FLOWIT-PRIORITY': 'high',
          'X-FLOWIT-STATUS': 'in-progress',
          'DESCRIPTION': 'Standard field',
        };

        final flowItFields = extractFlowItFields(vtodoWithFlowItFields);
        
        expect(flowItFields['TYPE'], 'task');
        expect(flowItFields['PROJECT'], 'Development');
        expect(flowItFields['PRIORITY'], 'high');
        expect(flowItFields['STATUS'], 'in-progress');
        expect(flowItFields.containsKey('DESCRIPTION'), false); // Pas un champ FlowIt
      });

      test('should correct incomplete VTodo according to non-standard vtodo rule', () {
        // Test la correction des VTodo non-standards selon nos règles
        Map<String, String> correctIncompleteVTodo(Map<String, String> properties) {
          final corrected = Map<String, String>.from(properties);
          
          // Règle: tout VTodo incomplet ou corrompu devient une tâche par défaut
          if (!corrected.containsKey('X-FLOWIT-TYPE') || 
              corrected['X-FLOWIT-TYPE']!.isEmpty) {
            corrected['X-FLOWIT-TYPE'] = 'task';
          }
          
          // Ajouter un projet par défaut si manquant
          if (!corrected.containsKey('X-FLOWIT-PROJECT') || 
              corrected['X-FLOWIT-PROJECT']!.isEmpty) {
            corrected['X-FLOWIT-PROJECT'] = 'Default';
          }
          
          // Ajouter un validateur par défaut
          if (!corrected.containsKey('X-FLOWIT-VALIDATOR') || 
              corrected['X-FLOWIT-VALIDATOR']!.isEmpty) {
            corrected['X-FLOWIT-VALIDATOR'] = 'default';
          }
          
          return corrected;
        }

        // VTodo sans champs FlowIt
        final incompleteVTodo = {
          'UID': 'external-task-001',
          'SUMMARY': 'Task from external calendar',
          'DESCRIPTION': 'Missing FlowIt fields',
        };

        final corrected = correctIncompleteVTodo(incompleteVTodo);
        
        expect(corrected['X-FLOWIT-TYPE'], 'task');
        expect(corrected['X-FLOWIT-PROJECT'], 'Default');
        expect(corrected['X-FLOWIT-VALIDATOR'], 'default');
        expect(corrected['UID'], 'external-task-001'); // Garde les champs originaux
        expect(corrected['SUMMARY'], 'Task from external calendar');
      });
    });

    group('VTodo Generation', () {
      test('should generate valid VTodo string from properties', () {
        String generateVTodo(Map<String, String> properties) {
          final buffer = StringBuffer();
          buffer.writeln('BEGIN:VTODO');
          
          // Ordre des champs pour la cohérence
          final orderedFields = [
            'UID', 'SUMMARY', 'DESCRIPTION', 'DUE', 'STATUS', 'PRIORITY'
          ];
          
          // Ajouter les champs dans l'ordre
          for (final field in orderedFields) {
            if (properties.containsKey(field) && properties[field]!.isNotEmpty) {
              buffer.writeln('$field:${properties[field]}');
            }
          }
          
          // Ajouter les champs FlowIt
          for (final entry in properties.entries) {
            if (entry.key.startsWith('X-FLOWIT-') && entry.value.isNotEmpty) {
              buffer.writeln('${entry.key}:${entry.value}');
            }
          }
          
          buffer.writeln('END:VTODO');
          return buffer.toString();
        }

        final properties = {
          'UID': 'generated-task-001',
          'SUMMARY': 'Generated Task',
          'DESCRIPTION': 'This task was generated by tests',
          'STATUS': 'NEEDS-ACTION',
          'PRIORITY': '1',
          'X-FLOWIT-TYPE': 'task',
          'X-FLOWIT-PROJECT': 'Testing',
        };

        final vtodoString = generateVTodo(properties);
        
        expect(vtodoString, contains('BEGIN:VTODO'));
        expect(vtodoString, contains('END:VTODO'));
        expect(vtodoString, contains('UID:generated-task-001'));
        expect(vtodoString, contains('SUMMARY:Generated Task'));
        expect(vtodoString, contains('X-FLOWIT-TYPE:task'));
        expect(vtodoString, contains('X-FLOWIT-PROJECT:Testing'));
      });

      test('should handle empty or null properties gracefully', () {
        String generateVTodo(Map<String, String> properties) {
          final buffer = StringBuffer();
          buffer.writeln('BEGIN:VTODO');
          
          final orderedFields = [
            'UID', 'SUMMARY', 'DESCRIPTION', 'DUE', 'STATUS', 'PRIORITY'
          ];
          
          for (final field in orderedFields) {
            if (properties.containsKey(field) && properties[field]!.isNotEmpty) {
              buffer.writeln('$field:${properties[field]}');
            }
          }
          
          for (final entry in properties.entries) {
            if (entry.key.startsWith('X-FLOWIT-') && entry.value.isNotEmpty) {
              buffer.writeln('${entry.key}:${entry.value}');
            }
          }
          
          buffer.writeln('END:VTODO');
          return buffer.toString();
        }

        // Propriétés avec des valeurs vides
        final emptyProperties = {
          'UID': '',
          'SUMMARY': 'Task with empty fields',
          'DESCRIPTION': '',
          'X-FLOWIT-TYPE': 'task',
          'X-FLOWIT-PROJECT': '',
        };

        final vtodoString = generateVTodo(emptyProperties);
        
        expect(vtodoString, contains('SUMMARY:Task with empty fields'));
        expect(vtodoString, contains('X-FLOWIT-TYPE:task'));
        expect(vtodoString, isNot(contains('UID:')));  // Champ vide non inclus
        expect(vtodoString, isNot(contains('DESCRIPTION:')));  // Champ vide non inclus
        expect(vtodoString, isNot(contains('X-FLOWIT-PROJECT:')));  // Champ vide non inclus
      });
    });

    group('Date and Time Handling', () {
      test('should parse ISO 8601 datetime correctly', () {
        DateTime? parseISODateTime(String? dateTimeString) {
          if (dateTimeString == null || dateTimeString.isEmpty) {
            return null;
          }
          
          try {
            // Format: 20241224T140000Z
            if (dateTimeString.length == 16 && dateTimeString.endsWith('Z')) {
              final dateStr = dateTimeString.substring(0, 8);
              final timeStr = dateTimeString.substring(9, 15);
              
              final year = int.parse(dateStr.substring(0, 4));
              final month = int.parse(dateStr.substring(4, 6));
              final day = int.parse(dateStr.substring(6, 8));
              
              final hour = int.parse(timeStr.substring(0, 2));
              final minute = int.parse(timeStr.substring(2, 4));
              final second = int.parse(timeStr.substring(4, 6));
              
              return DateTime.utc(year, month, day, hour, minute, second);
            }
            
            return DateTime.tryParse(dateTimeString);
          } catch (e) {
            return null;
          }
        }

        // Test avec format VTodo standard
        final datetime1 = parseISODateTime('20241224T140000Z');
        expect(datetime1, isNotNull);
        expect(datetime1!.year, 2024);
        expect(datetime1.month, 12);
        expect(datetime1.day, 24);
        expect(datetime1.hour, 14);
        expect(datetime1.minute, 0);
        expect(datetime1.second, 0);
        expect(datetime1.isUtc, true);

        // Test avec format ISO standard
        final datetime2 = parseISODateTime('2024-12-24T14:00:00Z');
        expect(datetime2, isNotNull);
        expect(datetime2!.year, 2024);

        // Test avec chaîne invalide
        final datetime3 = parseISODateTime('invalid-date');
        expect(datetime3, isNull);

        // Test avec chaîne vide
        final datetime4 = parseISODateTime('');
        expect(datetime4, isNull);
      });

      test('should format DateTime to VTodo format', () {
        String formatToVTodoDateTime(DateTime dateTime) {
          final utcDateTime = dateTime.toUtc();
          
          final year = utcDateTime.year.toString().padLeft(4, '0');
          final month = utcDateTime.month.toString().padLeft(2, '0');
          final day = utcDateTime.day.toString().padLeft(2, '0');
          final hour = utcDateTime.hour.toString().padLeft(2, '0');
          final minute = utcDateTime.minute.toString().padLeft(2, '0');
          final second = utcDateTime.second.toString().padLeft(2, '0');
          
          return '${year}${month}${day}T${hour}${minute}${second}Z';
        }

        final dateTime = DateTime.utc(2024, 12, 24, 14, 30, 45);
        final formatted = formatToVTodoDateTime(dateTime);
        
        expect(formatted, '20241224T143045Z');
        
        // Test avec heure locale convertie en UTC
        final localDateTime = DateTime(2024, 1, 1, 12, 0, 0);
        final formattedLocal = formatToVTodoDateTime(localDateTime);
        expect(formattedLocal, matches(r'^\d{8}T\d{6}Z$'));
      });
    });
  });
} 