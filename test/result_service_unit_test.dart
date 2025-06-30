/**
 * Tests unitaires pour la gestion des erreurs avec Result objects
 * Teste les patterns de gestion d'erreur utilisés dans l'app
 */

import 'package:flutter_test/flutter_test.dart';

// Implémentation simple du pattern Result pour les tests
class Result<T> {
  final T? _value;
  final String? _error;
  
  const Result.success(T value) : _value = value, _error = null;
  const Result.failure(String error) : _value = null, _error = error;
  
  bool get isSuccess => _error == null;
  bool get isFailure => _error != null;
  
  T get value {
    if (_error != null) {
      throw Exception('Result is a failure: $_error');
    }
    return _value!;
  }
  
  String get error {
    if (_error == null) {
      throw Exception('Result is a success');
    }
    return _error!;
  }
  
  T? get valueOrNull => _value;
  String? get errorOrNull => _error;
  
  T getOrDefault(T defaultValue) => _value ?? defaultValue;
  
  Result<U> map<U>(U Function(T) transform) {
    if (isFailure) {
      return Result.failure(_error!);
    }
    try {
      return Result.success(transform(_value!));
    } catch (e) {
      return Result.failure(e.toString());
    }
  }
  
  Result<U> flatMap<U>(Result<U> Function(T) transform) {
    if (isFailure) {
      return Result.failure(_error!);
    }
    try {
      return transform(_value!);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }
}

void main() {
  group('Result Pattern Unit Tests', () {
    
    group('Basic Result Operations', () {
      test('should create success result correctly', () {
        final result = Result.success('test value');
        
        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.value, 'test value');
        expect(result.valueOrNull, 'test value');
        expect(result.errorOrNull, isNull);
      });

      test('should create failure result correctly', () {
        final result = Result<String>.failure('test error');
        
        expect(result.isSuccess, false);
        expect(result.isFailure, true);
        expect(result.error, 'test error');
        expect(result.valueOrNull, isNull);
        expect(result.errorOrNull, 'test error');
      });

      test('should throw when accessing value on failure', () {
        final result = Result<String>.failure('test error');
        
        expect(() => result.value, throwsA(isA<Exception>()));
      });

      test('should throw when accessing error on success', () {
        final result = Result.success('test value');
        
        expect(() => result.error, throwsA(isA<Exception>()));
      });

      test('should return default value correctly', () {
        final successResult = Result.success('actual value');
        final failureResult = Result<String>.failure('error');
        
        expect(successResult.getOrDefault('default'), 'actual value');
        expect(failureResult.getOrDefault('default'), 'default');
      });
    });

    group('Result Transformation', () {
      test('should map success values correctly', () {
        final result = Result.success(5);
        final mapped = result.map((value) => value * 2);
        
        expect(mapped.isSuccess, true);
        expect(mapped.value, 10);
      });

      test('should propagate failure in map', () {
        final result = Result<int>.failure('original error');
        final mapped = result.map((value) => value * 2);
        
        expect(mapped.isFailure, true);
        expect(mapped.error, 'original error');
      });

      test('should handle exceptions in map', () {
        final result = Result.success(0);
        final mapped = result.map((value) => 10 ~/ value); // Division par zéro
        
        expect(mapped.isFailure, true);
        expect(mapped.error, contains('IntegerDivisionByZeroException'));
      });

      test('should flatMap success values correctly', () {
        final result = Result.success(5);
        final flatMapped = result.flatMap((value) => 
          value > 0 ? Result.success(value * 2) : Result.failure('negative')
        );
        
        expect(flatMapped.isSuccess, true);
        expect(flatMapped.value, 10);
      });

      test('should propagate failure in flatMap', () {
        final result = Result<int>.failure('original error');
        final flatMapped = result.flatMap((value) => Result.success(value * 2));
        
        expect(flatMapped.isFailure, true);
        expect(flatMapped.error, 'original error');
      });

      test('should handle transformation failure in flatMap', () {
        final result = Result.success(-5);
        final flatMapped = result.flatMap((value) => 
          value > 0 ? Result.success(value * 2) : Result.failure('negative value')
        );
        
        expect(flatMapped.isFailure, true);
        expect(flatMapped.error, 'negative value');
      });
    });

    group('Service Integration Patterns', () {
      test('should handle CalDAV connection result', () {
        // Simule un résultat de connection CalDAV
        Result<Map<String, String>> simulateCalDAVConnection(String serverUrl) {
          if (serverUrl.isEmpty) {
            return Result.failure('Server URL cannot be empty');
          }
          
          if (!serverUrl.startsWith('http')) {
            return Result.failure('Invalid server URL format');
          }
          
          // Simule une connection réussie
          return Result.success({
            'server': serverUrl,
            'dav': '1, 2, calendar-access',
            'status': 'connected'
          });
        }

        // Test connection réussie
        final successResult = simulateCalDAVConnection('https://example.com/dav');
        expect(successResult.isSuccess, true);
        expect(successResult.value['status'], 'connected');

        // Test URL vide
        final emptyUrlResult = simulateCalDAVConnection('');
        expect(emptyUrlResult.isFailure, true);
        expect(emptyUrlResult.error, 'Server URL cannot be empty');

        // Test URL invalide
        final invalidUrlResult = simulateCalDAVConnection('invalid-url');
        expect(invalidUrlResult.isFailure, true);
        expect(invalidUrlResult.error, 'Invalid server URL format');
      });

      test('should chain multiple service calls', () {
        // Simule la chaîne: connexion → découverte → liste calendriers
        Result<String> connectToServer(String url) {
          if (url.isEmpty) return Result.failure('Empty URL');
          return Result.success('/principals/user/');
        }
        
        Result<String> discoverCalendarHome(String principal) {
          if (principal.isEmpty) return Result.failure('Empty principal');
          return Result.success('/calendars/user/');
        }
        
        Result<List<String>> listCalendars(String calendarHome) {
          if (calendarHome.isEmpty) return Result.failure('Empty calendar home');
          return Result.success(['DEV', 'Personal', 'Work']);
        }

        // Chaîne complète avec succès
        final result = connectToServer('https://example.com')
          .flatMap((principal) => discoverCalendarHome(principal))
          .flatMap((calendarHome) => listCalendars(calendarHome));
        
        expect(result.isSuccess, true);
        expect(result.value, ['DEV', 'Personal', 'Work']);

        // Chaîne avec échec au début
        final failureResult = connectToServer('')
          .flatMap((principal) => discoverCalendarHome(principal))
          .flatMap((calendarHome) => listCalendars(calendarHome));
        
        expect(failureResult.isFailure, true);
        expect(failureResult.error, 'Empty URL');
      });

      test('should handle VTodo parsing result', () {
        Result<Map<String, String>> parseVTodoResult(String vtodoString) {
          if (vtodoString.isEmpty) {
            return Result.failure('Empty VTodo string');
          }
          
          try {
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
            
            if (!properties.containsKey('UID') || !properties.containsKey('SUMMARY')) {
              return Result.failure('Missing required fields: UID or SUMMARY');
            }
            
            return Result.success(properties);
          } catch (e) {
            return Result.failure('Parse error: ${e.toString()}');
          }
        }

        // Test parsing réussi
        const validVTodo = '''BEGIN:VTODO
UID:test-001
SUMMARY:Test Task
END:VTODO''';
        
        final successResult = parseVTodoResult(validVTodo);
        expect(successResult.isSuccess, true);
        expect(successResult.value['UID'], 'test-001');
        expect(successResult.value['SUMMARY'], 'Test Task');

        // Test VTodo vide
        final emptyResult = parseVTodoResult('');
        expect(emptyResult.isFailure, true);
        expect(emptyResult.error, 'Empty VTodo string');

        // Test VTodo incomplet
        const incompleteVTodo = '''BEGIN:VTODO
SUMMARY:Task without UID
END:VTODO''';
        
        final incompleteResult = parseVTodoResult(incompleteVTodo);
        expect(incompleteResult.isFailure, true);
        expect(incompleteResult.error, contains('Missing required fields'));
      });
    });

    group('Error Handling Patterns', () {
      test('should categorize network errors', () {
        Result<String> categorizeNetworkError(String errorMessage) {
          if (errorMessage.contains('timeout')) {
            return Result.failure('NETWORK_TIMEOUT');
          } else if (errorMessage.contains('connection refused')) {
            return Result.failure('CONNECTION_REFUSED');
          } else if (errorMessage.contains('404')) {
            return Result.failure('RESOURCE_NOT_FOUND');
          } else if (errorMessage.contains('401') || errorMessage.contains('403')) {
            return Result.failure('AUTHENTICATION_FAILED');
          } else {
            return Result.failure('UNKNOWN_NETWORK_ERROR');
          }
        }

        expect(categorizeNetworkError('Connection timeout').error, 'NETWORK_TIMEOUT');
        expect(categorizeNetworkError('connection refused').error, 'CONNECTION_REFUSED');
        expect(categorizeNetworkError('HTTP 404 Not Found').error, 'RESOURCE_NOT_FOUND');
        expect(categorizeNetworkError('HTTP 401 Unauthorized').error, 'AUTHENTICATION_FAILED');
        expect(categorizeNetworkError('HTTP 403 Forbidden').error, 'AUTHENTICATION_FAILED');
        expect(categorizeNetworkError('Unknown error').error, 'UNKNOWN_NETWORK_ERROR');
      });

      test('should handle retry logic with Result', () {
        int attemptCount = 0;
        
        Result<String> flakyOperation() {
          attemptCount++;
          if (attemptCount < 3) {
            return Result.failure('Temporary failure');
          }
          return Result.success('Success on attempt $attemptCount');
        }
        
        Result<String> retryOperation(Result<String> Function() operation, int maxRetries) {
          for (int i = 0; i < maxRetries; i++) {
            final result = operation();
            if (result.isSuccess) {
              return result;
            }
            // En vrai, on aurait un délai ici
          }
          return Result.failure('Max retries exceeded');
        }

        final result = retryOperation(flakyOperation, 5);
        expect(result.isSuccess, true);
        expect(result.value, 'Success on attempt 3');
        expect(attemptCount, 3);
      });

      test('should accumulate multiple errors', () {
        List<Result<String>> validateFields(Map<String, String> data) {
          final results = <Result<String>>[];
          
          if (!data.containsKey('name') || data['name']!.isEmpty) {
            results.add(Result.failure('Name is required'));
          }
          
          if (!data.containsKey('email') || data['email']!.isEmpty) {
            results.add(Result.failure('Email is required'));
          } else if (!data['email']!.contains('@')) {
            results.add(Result.failure('Invalid email format'));
          }
          
          if (data.containsKey('age')) {
            final age = int.tryParse(data['age']!);
            if (age == null || age < 0) {
              results.add(Result.failure('Invalid age'));
            }
          }
          
          if (results.isEmpty) {
            results.add(Result.success('All fields valid'));
          }
          
          return results;
        }

        // Test avec données valides
        final validData = {'name': 'John', 'email': 'john@example.com', 'age': '30'};
        final validResults = validateFields(validData);
        expect(validResults.length, 1);
        expect(validResults[0].isSuccess, true);

        // Test avec données invalides
        final invalidData = {'name': '', 'email': 'invalid-email', 'age': '-5'};
        final invalidResults = validateFields(invalidData);
        expect(invalidResults.length, 3);
        expect(invalidResults.every((r) => r.isFailure), true);
        expect(invalidResults[0].error, 'Name is required');
        expect(invalidResults[1].error, 'Invalid email format');
        expect(invalidResults[2].error, 'Invalid age');
      });
    });
  });
} 