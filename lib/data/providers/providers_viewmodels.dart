// ViewModel providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/viewmodels/task_viewmodel.dart';
import '../../presentation/viewmodels/caldav_settings_viewmodel.dart';
import '../../presentation/viewmodels/project_list_viewmodel.dart';
import '../../presentation/viewmodels/external_calendar_viewmodel.dart';
import '../../presentation/viewmodels/validator_viewmodel.dart';
import '../../presentation/viewmodels/attachment_viewmodel.dart';
import '../../presentation/viewmodels/category_viewmodel.dart';
import '../services/storage/file_upload_queue_service.dart';
import '../../core/logger.dart';
import '../../presentation/viewmodels/project_kanban_viewmodel.dart';
import '../../presentation/viewmodels/project_sharing_viewmodel.dart';
import '../../presentation/viewmodels/step_viewmodel.dart';
import '../../presentation/viewmodels/project_notes_viewmodel.dart';
import '../../presentation/viewmodels/note_viewmodel.dart';
import '../../presentation/viewmodels/journal_file_attachment_viewmodel.dart';
import '../../presentation/viewmodels/journal_media_attachment_viewmodel.dart';
import '../../data/models/journal.dart';
import 'providers_repositories.dart';
import 'providers_services_core.dart';
// import '../../presentation/viewmodels/caldav_management_viewmodel.dart';

final taskViewModelProvider = StateNotifierProvider<TaskViewModel, TaskViewModelState>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return TaskViewModel(taskRepository, accountRepository);
});

final caldavSettingsViewModelProvider = StateNotifierProvider<CaldavSettingsViewModel, CaldavSettingsState>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return CaldavSettingsViewModel(accountRepository, calendarRepository);
});

final validatorViewModelProvider = StateNotifierProvider.family<ValidatorViewModel, ValidatorViewModelState, String>((ref, taskUid) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return ValidatorViewModel(taskRepository, accountRepository);
});

final unifiedAttachmentViewModelProvider = StateNotifierProvider<UnifiedAttachmentViewModel, UnifiedAttachmentState>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final journalRepository = ref.watch(journalRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final offlineFileService = ref.watch(offlineFileServiceProvider);
  
  // Try to get FileUploadQueueService, but don't fail if it's not available
  FileUploadQueueService? fileUploadQueueService;
  try {
    fileUploadQueueService = ref.watch(fileUploadQueueServiceProvider);
  } catch (e) {
    AppLogger.warning('UnifiedAttachmentViewModel: FileUploadQueueService not available: $e');
  }
  
  return UnifiedAttachmentViewModel(
    taskRepository: taskRepository,
    journalRepository: journalRepository,
    accountRepository: accountRepository,
    offlineFileService: offlineFileService,
    fileUploadQueueService: fileUploadQueueService,
  );
});

final categoryViewModelProvider = StateNotifierProvider<CategoryViewModel, CategoryViewModelState>((ref) {
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  return CategoryViewModel(categoryRepository);
});

final projectCategoryViewModelProvider = StateNotifierProvider.family<CategoryViewModel, CategoryViewModelState, String>((ref, projectPath) {
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final viewModel = CategoryViewModel(categoryRepository);
  viewModel.initialize(projectPath);
  return viewModel;
});

final projectStepViewModelProvider = StateNotifierProvider.family<StepViewModel, StepViewModelState, String>((ref, projectPath) {
  final stepRepository = ref.watch(stepRepositoryProvider);
  final viewModel = StepViewModel(stepRepository);
  viewModel.initialize(projectPath);
  return viewModel;
});

final projectKanbanViewModelProvider = StateNotifierProvider.family<ProjectKanbanViewModel, ProjectKanbanState, String>((ref, projectPath) {
  final kanbanRepository = ref.watch(kanbanRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final viewModel = ProjectKanbanViewModel(
    kanbanRepository,
    categoryRepository,
  );
  viewModel.initialize(projectPath);
  return viewModel;
});

final projectSharingViewModelProvider = StateNotifierProvider<ProjectSharingViewModel, ProjectSharingState>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return ProjectSharingViewModel(accountRepository, calendarRepository);
});

final projectListViewModelProvider = StateNotifierProvider<ProjectListViewModel, ProjectListState>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return ProjectListViewModel(calendarRepository, taskRepository, accountRepository, userRepository, workflowsMode: false);
});

final workflowListViewModelProvider = StateNotifierProvider<ProjectListViewModel, ProjectListState>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return ProjectListViewModel(calendarRepository, taskRepository, accountRepository, userRepository, workflowsMode: true);
});

final externalCalendarViewModelProvider = StateNotifierProvider<ExternalCalendarViewModel, ExternalCalendarState>((ref) {
  return ExternalCalendarViewModel(
    ref.watch(externalAccountRepositoryProvider),
    ref.watch(externalCalendarRepositoryProvider),
    ref.watch(externalEventRepositoryProvider),
    ref.watch(externalCalendarSyncServiceProvider),
  );
});

// Notes (journals)
final projectNotesViewModelProvider = StateNotifierProvider.family<ProjectNotesViewModel, ProjectNotesState, String>((ref, projectPath) {
  final repo = ref.watch(journalRepositoryProvider);
  return ProjectNotesViewModel(projectPath: projectPath, journalRepository: repo);
});

// Reactive journal provider that watches the repository for changes
final journalProvider = StreamProvider.family<Journal?, String>((ref, journalUid) {
  final journalRepository = ref.watch(journalRepositoryProvider);
  return journalRepository.watchJournals().map((journals) {
    try {
      return journals.firstWhere((journal) => journal.uid == journalUid);
    } catch (e) {
      return null;
    }
  });
});

final noteViewModelProvider = StateNotifierProvider.family<NoteViewModel, NoteState, String>((ref, journalUid) {
  final journalRepository = ref.watch(journalRepositoryProvider);
  final journalAsync = ref.watch(journalProvider(journalUid));
  
  // Get the current journal or create a placeholder
  final journal = journalAsync.value ?? Journal(
    uid: journalUid,
    summary: '',
    description: '',
    lastModified: DateTime.now(),
    created: DateTime.now(),
    dtstamp: DateTime.now(),
    projectPath: '',
  );
  
  return NoteViewModel(journal, journalRepository);
});

// Journal attachment ViewModels
final journalFileAttachmentViewModelProvider = StateNotifierProvider.family<JournalFileAttachmentViewModel, JournalFileAttachmentState, String>((ref, journalUid) {
  return JournalFileAttachmentViewModel(
    journalRepository: ref.watch(journalRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    offlineFileService: ref.watch(offlineFileServiceProvider),
    fileUploadQueueService: ref.watch(fileUploadQueueServiceProvider),
  );
});

final journalMediaAttachmentViewModelProvider = StateNotifierProvider.family<JournalMediaAttachmentViewModel, JournalMediaAttachmentState, String>((ref, journalUid) {
  return JournalMediaAttachmentViewModel(
    journalRepository: ref.watch(journalRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    offlineFileService: ref.watch(offlineFileServiceProvider),
    fileUploadQueueService: ref.watch(fileUploadQueueServiceProvider),
  );
});


