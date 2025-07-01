// Domain Feature Test Suite
// Tests for domain organization functionality including model, service, and repository layers

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../lib/data/models/task_calendar.dart';
import '../lib/data/repositories/calendar_repository.dart';
import '../lib/data/repositories/account_repository.dart';
import '../lib/data/services/domain_service.dart';
import '../lib/data/services/local_storage_service.dart';
import '../lib/core/result.dart';

// Generate mocks
@GenerateMocks([CalendarRepository, LocalStorageService, AccountRepository])
import 'domain_feature_test.mocks.dart';

void main() {
  group('Domain Feature Tests', () {
    late MockCalendarRepository mockCalendarRepository;
    late MockLocalStorageService mockLocalStorageService;
    late MockAccountRepository mockAccountRepository;
    late DomainService domainService;
    late List<TaskCalendar> testCalendars;

    setUp(() {
      mockCalendarRepository = MockCalendarRepository();
      mockLocalStorageService = MockLocalStorageService();
      mockAccountRepository = MockAccountRepository();
      domainService = DomainService(mockCalendarRepository, mockLocalStorageService, mockAccountRepository);
      
      // Create test calendars with different domains
      testCalendars = [
        TaskCalendar(
          path: '/calendars/project1/',
          displayName: 'Marketing Campaign',
          uid: 'cal-1',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          summary: 'Marketing Campaign',
          status: 'NEEDS-ACTION',
          flowitDomain: 'Marketing',
        ),
        TaskCalendar(
          path: '/calendars/project2/',
          displayName: 'Website Redesign',
          uid: 'cal-2',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          summary: 'Website Redesign',
          status: 'NEEDS-ACTION',
          flowitDomain: 'Development',
        ),
        TaskCalendar(
          path: '/calendars/project3/',
          displayName: 'Budget Planning',
          uid: 'cal-3',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          summary: 'Budget Planning',
          status: 'NEEDS-ACTION',
          flowitDomain: null, // No domain
        ),
        TaskCalendar(
          path: '/calendars/project4/',
          displayName: 'Social Media Strategy',
          uid: 'cal-4',
          dtstamp: DateTime.now(),
          created: DateTime.now(),
          lastModified: DateTime.now(),
          summary: 'Social Media Strategy',
          status: 'NEEDS-ACTION',
          flowitDomain: 'Marketing',
        ),
      ];
    });

    group('TaskCalendar Domain Extensions', () {
      test('hasDomain returns correct values', () {
        expect(testCalendars[0].hasDomain, isTrue); // Has 'Marketing'
        expect(testCalendars[2].hasDomain, isFalse); // No domain
      });

      test('domainDisplayName returns correct values', () {
        expect(testCalendars[0].domainDisplayName, equals('Marketing'));
        expect(testCalendars[2].domainDisplayName, equals('No Domain'));
      });

      test('belongsToDomain works correctly', () {
        expect(testCalendars[0].belongsToDomain('Marketing'), isTrue);
        expect(testCalendars[0].belongsToDomain('marketing'), isTrue); // Case insensitive
        expect(testCalendars[0].belongsToDomain('Development'), isFalse);
        expect(testCalendars[2].belongsToDomain('No Domain'), isTrue);
        expect(testCalendars[2].belongsToDomain('no domain'), isTrue);
      });

      test('withDomain creates calendar with new domain', () {
        final updated = testCalendars[2].withDomain('Finance');
        expect(updated.flowitDomain, equals('Finance'));
        expect(updated.uid, equals(testCalendars[2].uid)); // Other fields preserved
        expect(updated.lastModified.isAfter(testCalendars[2].lastModified), isTrue);
      });

      test('withoutDomain removes domain', () {
        final updated = testCalendars[0].withoutDomain();
        expect(updated.flowitDomain, isNull);
        expect(updated.uid, equals(testCalendars[0].uid)); // Other fields preserved
      });
    });

    group('DomainService', () {
      test('getAvailableDomains returns unique domains', () async {
        when(mockCalendarRepository.getUniqueDomains())
            .thenAnswer((_) async => Result.success(['Marketing', 'Development']));

        final result = await domainService.getAvailableDomains();
        
        expect(result, isA<Success<List<String>>>());
        result.when(
          success: (domains) {
            expect(domains, contains('Marketing'));
            expect(domains, contains('Development'));
            expect(domains.length, equals(2));
          },
          failure: (_) => fail('Should not fail'),
        );
      });

      test('getCalendarsGroupedByDomain groups correctly', () async {
        when(mockCalendarRepository.getAll())
            .thenAnswer((_) async => Result.success(testCalendars));

        final result = await domainService.getCalendarsGroupedByDomain();
        
        expect(result, isA<Success<Map<String, List<TaskCalendar>>>>());
        result.when(
          success: (grouped) {
            expect(grouped.keys, contains('Marketing'));
            expect(grouped.keys, contains('Development'));
            expect(grouped.keys, contains('No Domain'));
            
            expect(grouped['Marketing']?.length, equals(2));
            expect(grouped['Development']?.length, equals(1));
            expect(grouped['No Domain']?.length, equals(1));
          },
          failure: (_) => fail('Should not fail'),
        );
      });

      test('assignDomainToCalendar updates calendar', () async {
        final calendar = testCalendars[2]; // Calendar without domain
        
        when(mockCalendarRepository.getById('cal-3'))
            .thenAnswer((_) async => Result.success(calendar));
        when(mockCalendarRepository.save(any))
            .thenAnswer((_) async => Result.success(null));

        final result = await domainService.assignDomainToCalendar('cal-3', 'Finance');
        
        expect(result, isA<Success<void>>());
        verify(mockCalendarRepository.save(any)).called(1);
      });

      test('renameDomain calls repository method', () async {
        when(mockCalendarRepository.renameDomain('Marketing', 'Brand Management'))
            .thenAnswer((_) async => Result.success(null));

        final result = await domainService.renameDomain('Marketing', 'Brand Management');
        
        expect(result, isA<Success<void>>());
        verify(mockCalendarRepository.renameDomain('Marketing', 'Brand Management')).called(1);
      });

      test('validateDomainName rejects invalid names', () {
        // Empty domain
        final emptyResult = domainService.validateDomainName('');
        expect(emptyResult, isA<Error<void>>());

        // Reserved name
        final reservedResult = domainService.validateDomainName('No Domain');
        expect(reservedResult, isA<Error<void>>());

        // Valid name
        final validResult = domainService.validateDomainName('Valid Domain');
        expect(validResult, isA<Success<void>>());
      });

      test('getDomainStatistics returns correct counts', () async {
        final stats = {'Marketing': 2, 'Development': 1, 'No Domain': 1};
        when(mockCalendarRepository.getDomainStatistics())
            .thenAnswer((_) async => Result.success(stats));

        final result = await domainService.getDomainStatistics();
        
        expect(result, isA<Success<Map<String, int>>>());
        result.when(
          success: (statistics) {
            expect(statistics['Marketing'], equals(2));
            expect(statistics['Development'], equals(1));
            expect(statistics['No Domain'], equals(1));
          },
          failure: (_) => fail('Should not fail'),
        );
      });
    });

    group('Calendar Repository Domain Methods', () {
      // These would test the actual LocalCalendarRepository implementation
      // For now, we're testing the service layer which uses the repository
      
      test('getCalendarsByDomain filters correctly', () async {
        when(mockCalendarRepository.getCalendarsByDomain('Marketing'))
            .thenAnswer((_) async => Result.success([testCalendars[0], testCalendars[3]]));

        final result = await domainService.getCalendarsByDomain('Marketing');
        
        expect(result, isA<Success<List<TaskCalendar>>>());
        result.when(
          success: (calendars) {
            expect(calendars.length, equals(2));
            expect(calendars.every((cal) => cal.flowitDomain == 'Marketing'), isTrue);
          },
          failure: (_) => fail('Should not fail'),
        );
      });

      test('getCalendarsWithoutDomain returns unassigned calendars', () async {
        when(mockCalendarRepository.getCalendarsWithoutDomain())
            .thenAnswer((_) async => Result.success([testCalendars[2]]));

        final result = await domainService.getCalendarsWithoutDomain();
        
        expect(result, isA<Success<List<TaskCalendar>>>());
        result.when(
          success: (calendars) {
            expect(calendars.length, equals(1));
            expect(calendars.first.flowitDomain, isNull);
          },
          failure: (_) => fail('Should not fail'),
        );
      });
    });

    group('Domain Integration Tests', () {
      test('full domain assignment workflow', () async {
        // Test complete workflow: get calendar -> assign domain -> verify assignment
        final calendar = testCalendars[2]; // No domain initially
        final updatedCalendar = calendar.withDomain('Finance');
        
        when(mockCalendarRepository.getById('cal-3'))
            .thenAnswer((_) async => Result.success(calendar));
        when(mockCalendarRepository.save(any))
            .thenAnswer((_) async => Result.success(null));

        // Assign domain
        final assignResult = await domainService.assignDomainToCalendar('cal-3', 'Finance');
        expect(assignResult, isA<Success<void>>());

        // Verify the save was called with updated calendar
        final captured = verify(mockCalendarRepository.save(captureAny)).captured;
        final savedCalendar = captured.first as TaskCalendar;
        expect(savedCalendar.flowitDomain, equals('Finance'));
      });

      test('domain rename workflow', () async {
        when(mockCalendarRepository.renameDomain('Old Domain', 'New Domain'))
            .thenAnswer((_) async => Result.success(null));

        final result = await domainService.renameDomain('Old Domain', 'New Domain');
        
        expect(result, isA<Success<void>>());
        verify(mockCalendarRepository.renameDomain('Old Domain', 'New Domain')).called(1);
      });

      test('bulk domain assignment', () async {
        final calendarIds = ['cal-1', 'cal-2'];
        
        // Mock individual assignments
        for (final id in calendarIds) {
          when(mockCalendarRepository.getById(id))
              .thenAnswer((_) async => Result.success(testCalendars.firstWhere((c) => c.uid == id)));
          when(mockCalendarRepository.save(any))
              .thenAnswer((_) async => Result.success(null));
        }

        final result = await domainService.bulkAssignDomain(calendarIds, 'Bulk Domain');
        
        expect(result, isA<Success<void>>());
        verify(mockCalendarRepository.save(any)).called(2);
      });
    });

    group('Error Handling', () {
      test('handles repository failures gracefully', () async {
        when(mockCalendarRepository.getUniqueDomains())
            .thenAnswer((_) async => Result.failure(const Failure(message: 'Database error')));

        final result = await domainService.getAvailableDomains();
        
        expect(result, isA<Error<List<String>>>());
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (failure) => expect(failure.message, equals('Database error')),
        );
      });

      test('validates domain names before operations', () async {
        // Test rename with invalid domain name
        final result = await domainService.renameDomain('Old Domain', '');
        
        expect(result, isA<Error<void>>());
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (failure) => expect(failure.message, contains('empty')),
        );
      });
    });
  });
} 