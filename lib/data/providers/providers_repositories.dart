// Repository providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/task_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/external_account_repository.dart';
import '../repositories/external_calendar_repository.dart';
import '../repositories/external_event_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/kanban_repository.dart';
import '../repositories/requirement_repository.dart';
import '../repositories/step_repository.dart';
// no-op
import 'providers_storage.dart';
import 'providers_services_core.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalTaskRepository(storageService);
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return LocalCalendarRepository(storageService, accountRepository, userRepository);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalAccountRepository(storageService);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalUserRepository(storageService);
});

final externalAccountRepositoryProvider = Provider<ExternalAccountRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalExternalAccountRepository(storageService);
});

final externalCalendarRepositoryProvider = Provider<ExternalCalendarRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalExternalCalendarRepository(storageService);
});

final externalEventRepositoryProvider = Provider<ExternalEventRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalExternalEventRepository(storageService);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return CategoryRepository(calendarRepository, accountRepository);
});

final requirementRepositoryProvider = Provider<RequirementRepository>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return RequirementRepository(calendarRepository);
});

final stepRepositoryProvider = Provider<StepRepository>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  return StepRepository(calendarRepository, taskRepository);
});

final kanbanRepositoryProvider = Provider<KanbanRepository>((ref) {
  final kanbanService = ref.watch(kanbanServiceProvider);
  return LocalKanbanRepository(kanbanService);
});


