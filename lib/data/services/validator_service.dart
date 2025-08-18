// Validator service for managing task validation logic
// Handles parsing, validation, and state management for the new validator system
// Maintains backward compatibility with legacy validator format

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/logger.dart';
import 'storage/encryption_service.dart';

/// Service for managing validator logic
class ValidatorService {
  
  // Static instance of EncryptionService for key generation
  static final EncryptionService _encryptionService = EncryptionService();
  
  /// Parse validator JSON from task.flowitValidator field
  /// Returns list of validator lists (new format) or empty list
  static List<List<Map<String, dynamic>>> parseValidators(String validatorJson) {
    try {
      if (validatorJson.isEmpty || validatorJson == '[]') {
        return [];
      }
      
      final decoded = jsonDecode(validatorJson);
      if (decoded is List) {
        // New format: array of arrays
        return decoded.map<List<Map<String, dynamic>>>((validatorList) {
          if (validatorList is List) {
            return validatorList.map<Map<String, dynamic>>((validator) {
              return validator is Map<String, dynamic> ? validator : <String, dynamic>{};
            }).toList();
          }
          return <Map<String, dynamic>>[];
        }).toList();
      }
      
      AppLogger.warning('ValidatorService: Invalid validator format, returning empty');
      return [];
    } catch (e, stackTrace) {
      AppLogger.error('ValidatorService: Failed to parse validators', e, stackTrace);
      return [];
    }
  }
  
  /// Serialize validator lists to JSON string
  static String serializeValidators(List<List<Map<String, dynamic>>> validatorLists) {
    try {
      return jsonEncode(validatorLists);
    } catch (e, stackTrace) {
      AppLogger.error('ValidatorService: Failed to serialize validators', e, stackTrace);
      return '[]';
    }
  }
  
  /// Check if all required validators in all lists are completed
  static bool areValidatorsCompleted(List<List<Map<String, dynamic>>> validatorLists) {
    if (validatorLists.isEmpty) return true;
    
    for (final validatorList in validatorLists) {
      for (final validator in validatorList) {
        if (!_isValidatorCompleted(validator)) {
          return false;
        }
      }
    }
    
    return true;
  }
  
  /// Update validator state
  static List<List<Map<String, dynamic>>> updateValidatorState(
    List<List<Map<String, dynamic>>> validatorLists,
    String validatorId,
    Map<String, dynamic> newState,
  ) {
    AppLogger.debug('ValidatorService: updateValidatorState called with validatorId: $validatorId');
    AppLogger.debug('ValidatorService: newState: $newState');
    
    return validatorLists.map((validatorList) {
      return validatorList.map((validator) {
        if (validator['id'] == validatorId) {
          AppLogger.debug('ValidatorService: Found validator to update: ${validator['id']}');
          AppLogger.debug('ValidatorService: Current validator state: $validator');
          
          final type = newState['type'] as String;
          AppLogger.debug('ValidatorService: Update type: $type');
          
          Map<String, dynamic> updated = Map.from(validator);
          
          switch (type) {
            case 'toggle':
              updated['completed'] = newState['completed'];
              break;
            case 'update_text':
              updated['text'] = newState['text'];
              break;
            case 'add_file':
              final updatedValidator = _addFile(updated, newState);
              AppLogger.debug('ValidatorService: After add_file: $updatedValidator');
              return updatedValidator;
            case 'remove_file':
              final updatedValidator = _removeFile(updated, newState);
              AppLogger.debug('ValidatorService: After remove_file: $updatedValidator');
              return updatedValidator;
            case 'update_file_s3':
              final updatedValidator = _updateFileS3(updated, newState);
              AppLogger.debug('ValidatorService: After update_file_s3: $updatedValidator');
              return updatedValidator;
            case 'checklist_item':
              return _updateChecklistItem(updated, newState);
            case 'selection':
              updated['selected'] = newState['selected'];
              break;
            case 'free_field':
              updated['value'] = newState['value'];
              break;
            case 'add_checklist_item':
              return _addChecklistItem(updated);
            case 'remove_checklist_item':
              return _removeChecklistItem(updated, newState);
            case 'add_select_option':
              return _addSelectOption(updated);
            case 'remove_select_option':
              return _removeSelectOption(updated, newState);
            case 'edit_title':
              updated['title'] = newState['title'];
              break;
            case 'edit_checklist_item':
              return _editChecklistItem(updated, newState);
            case 'edit_select_option':
              return _editSelectOption(updated, newState);
          }
          
          AppLogger.debug('ValidatorService: Updated validator: $updated');
          return updated;
        }
        return validator;
      }).toList();
    }).toList();
  }
  
  /// Add validator to first list (or create first list if needed)
  static List<List<Map<String, dynamic>>> addValidator(
    List<List<Map<String, dynamic>>> validatorLists,
    Map<String, dynamic> validator,
  ) {
    final updatedLists = List<List<Map<String, dynamic>>>.from(validatorLists);
    
    if (updatedLists.isEmpty) {
      updatedLists.add([]);
    }
    
    updatedLists[0] = List<Map<String, dynamic>>.from(updatedLists[0])..add(validator);
    
    return updatedLists;
  }
  
  /// Remove validator by ID
  static List<List<Map<String, dynamic>>> removeValidator(
    List<List<Map<String, dynamic>>> validatorLists,
    String validatorId,
  ) {
    final updatedLists = <List<Map<String, dynamic>>>[];
    
    for (final validatorList in validatorLists) {
      final updatedList = validatorList
          .where((validator) => validator['id'] != validatorId)
          .map((validator) => Map<String, dynamic>.from(validator))
          .toList();
      updatedLists.add(updatedList);
    }
    
    return updatedLists;
  }
  
  /// Check if user can edit validators (is organizer)
  static bool canEditValidators(String? taskOrganizer, String? currentUserEmail) {
    if (currentUserEmail == null || taskOrganizer == null) return false;
    
    // Extract email from organizer field (might be "mailto:user@domain.com")
    final organizerEmail = taskOrganizer.replaceFirst('mailto:', '');
    return organizerEmail.toLowerCase() == currentUserEmail.toLowerCase();
  }
  
  /// Check if user can interact with validators (organizer or attendee)
  static bool canInteractWithValidators(
    String? taskOrganizer,
    List<Map<String, dynamic>> attendees,
    String? currentUserEmail,
  ) {
    if (currentUserEmail == null) return false;
    
    // Can edit means can interact
    if (canEditValidators(taskOrganizer, currentUserEmail)) return true;
    
    // Check if user is an attendee
    return attendees.any((attendee) {
      final email = attendee['email'] as String?;
      return email?.toLowerCase() == currentUserEmail.toLowerCase();
    });
  }
  
  /// Create validator templates
  static Map<String, dynamic> createChecklistValidator({
    required String title,
    required List<String> itemTexts,
    bool required = true,
  }) {
    const uuid = Uuid();
    return {
      'id': uuid.v4(),
      'type': 'checklist',
      'required': required,
      'title': title,
      'items': itemTexts.map((text) => {
        'id': uuid.v4(),
        'text': text,
        'checked': false,
      }).toList(),
    };
  }
  
  static Map<String, dynamic> createSingleSelectValidator({
    required String title,
    required List<String> optionTexts,
    bool required = true,
  }) {
    const uuid = Uuid();
    return {
      'id': uuid.v4(),
      'type': 'single_select',
      'required': required,
      'title': title,
      'options': optionTexts.map((text) => {
        'id': uuid.v4(),
        'text': text,
      }).toList(),
      'selected': '',
    };
  }
  
  static Map<String, dynamic> createFreeFieldValidator({
    required String title,
    String? helper,
    bool required = true,
  }) {
    const uuid = Uuid();
    return {
      'id': uuid.v4(),
      'type': 'free_field',
      'required': required,
      'title': title,
      'value': '',
      if (helper != null) 'helper': helper,
    };
  }

  static Map<String, dynamic> createFileValidator({
    required String title,
    String? helper,
    bool required = true,
  }) {
    const uuid = Uuid();
    // Generate encryption key using EncryptionService for secure file encryption
    final encryptionKey = _encryptionService.generateEncryptionKey();
    return {
      'id': uuid.v4(),
      'type': 'file',
      'required': required,
      'title': title,
      'files': <Map<String, dynamic>>[], // Array of file attachments
      'encryptionKey': encryptionKey, // Automatically generated encryption key
      if (helper != null) 'helper': helper,
    };
  }

  static Map<String, dynamic> createMediaValidator({
    required String title,
    String? helper,
    bool required = true,
  }) {
    const uuid = Uuid();
    // Generate encryption key using EncryptionService for secure media encryption
    final encryptionKey = _encryptionService.generateEncryptionKey();
    return {
      'id': uuid.v4(),
      'type': 'media',
      'required': required,
      'title': title,
      'files': <Map<String, dynamic>>[], // Array of media file attachments
      'encryptionKey': encryptionKey, // Automatically generated encryption key
      if (helper != null) 'helper': helper,
    };
  }

  /// Private helper methods
  static Map<String, dynamic> _migrateFormQuestion(Map<String, dynamic> question) {
    final type = question['questiontype'] as String?;
    final id = question['questionid'] as String? ?? const Uuid().v4();
    final title = question['questiontext'] as String? ?? 'Migrated Question';
    final required = question['mandatory'] as bool? ?? true;
    final options = question['questionoption'] as List? ?? [];
    
    switch (type) {
      case 'select':
        const uuid = Uuid();
        return {
          'id': id,
          'type': 'single_select',
          'required': required,
          'title': title,
          'options': options.map((option) => {
            'id': uuid.v4(),
            'text': option.toString(),
          }).toList(),
          'selected': '',
        };
        
      case 'freefield':
        return {
          'id': id,
          'type': 'free_field',
          'required': required,
          'title': title,
          'value': '',
        };
        
      case 'multiselect':
        // Convert to checklist
        const uuid = Uuid();
        return {
          'id': id,
          'type': 'checklist',
          'required': required,
          'title': title,
          'items': options.map((option) => {
            'id': uuid.v4(),
            'text': option.toString(),
            'checked': false,
          }).toList(),
        };
        
      default:
        return createFreeFieldValidator(title: title, required: required);
    }
  }
  
  static bool _isValidatorCompleted(Map<String, dynamic> validator) {
    final type = validator['type'] as String?;
    final required = validator['required'] as bool? ?? true;
    
    if (!required) return true;
    
    switch (type) {
      case 'checklist':
        final items = validator['items'] as List? ?? [];
        return items.isNotEmpty && items.every((item) => item['checked'] == true);
        
      case 'single_select':
        final selected = validator['selected'] as String? ?? '';
        final options = validator['options'] as List? ?? [];
        return selected.isNotEmpty && options.any((option) => option['id'] == selected);
        
      case 'free_field':
        final value = validator['value'] as String? ?? '';
        return value.trim().isNotEmpty;
        
      case 'file':
        final files = validator['files'] as List? ?? [];
        return files.isNotEmpty;
        
      case 'media':
        final files = validator['files'] as List? ?? [];
        return files.isNotEmpty;
        
      default:
        return false;
    }
  }
  
  static Map<String, dynamic> _updateValidatorData(
    Map<String, dynamic> validator,
    dynamic newState,
  ) {
    final type = validator['type'] as String?;
    final updated = Map<String, dynamic>.from(validator);
    
    // Handle complex update operations with structured commands
    if (newState is Map<String, dynamic> && newState.containsKey('type')) {
      final updateType = newState['type'] as String;
      
      switch (updateType) {
        case 'checklist_item':
          return _updateChecklistItem(updated, newState);
        case 'selection':
          return _updateSelection(updated, newState);
        case 'free_field':
          return _updateFreeField(updated, newState);
        case 'edit_title':
          return _updateTitle(updated, newState);
        case 'add_checklist_item':
          return _addChecklistItem(updated);
        case 'remove_checklist_item':
          return _removeChecklistItem(updated, newState);
        case 'edit_checklist_item':
          return _editChecklistItem(updated, newState);
        case 'add_select_option':
          return _addSelectOption(updated);
        case 'remove_select_option':
          return _removeSelectOption(updated, newState);
        case 'edit_select_option':
          return _editSelectOption(updated, newState);
        case 'add_file':
          return _addFile(updated, newState);
        case 'remove_file':
          return _removeFile(updated, newState);
        case 'update_file_s3':
          return _updateFileS3(updated, newState);
      }
    }
    
    // Legacy simple updates for backward compatibility
    switch (type) {
      case 'checklist':
        if (newState is Map<String, dynamic> && newState.containsKey('itemId')) {
          final itemId = newState['itemId'] as String;
          final checked = newState['checked'] as bool;
          final items = (validator['items'] as List? ?? []).map((item) {
            if (item['id'] == itemId) {
              return {...item, 'checked': checked};
            }
            return item;
          }).toList();
          updated['items'] = items;
        }
        break;
        
      case 'single_select':
        if (newState is String) {
          updated['selected'] = newState;
        }
        break;
        
      case 'free_field':
        if (newState is String) {
          updated['value'] = newState;
        }
        break;
    }
    
    return updated;
  }
  
  // Helper methods for specific validator update operations
  
  static Map<String, dynamic> _updateChecklistItem(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final itemId = newState['itemId'] as String;
    final checked = newState['checked'] as bool;
    final items = (validator['items'] as List? ?? []).map((item) {
      if (item['id'] == itemId) {
        return {...item, 'checked': checked};
      }
      return item;
    }).toList();
    return {...validator, 'items': items};
  }
  
  static Map<String, dynamic> _updateSelection(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final selected = newState['selected'] as String;
    return {...validator, 'selected': selected};
  }
  
  static Map<String, dynamic> _updateFreeField(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final value = newState['value'] as String;
    return {...validator, 'value': value};
  }
  
  static Map<String, dynamic> _updateTitle(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final title = newState['title'] as String;
    return {...validator, 'title': title};
  }
  
  static Map<String, dynamic> _addChecklistItem(Map<String, dynamic> validator) {
    const uuid = Uuid();
    final items = List<Map<String, dynamic>>.from(validator['items'] as List? ?? []);
    items.add({
      'id': uuid.v4(),
      'text': 'New item',
      'checked': false,
    });
    return {...validator, 'items': items};
  }
  
  static Map<String, dynamic> _removeChecklistItem(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final itemId = newState['itemId'] as String;
    final items = (validator['items'] as List? ?? [])
        .where((item) => item['id'] != itemId)
        .toList();
    return {...validator, 'items': items};
  }
  
  static Map<String, dynamic> _editChecklistItem(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final itemId = newState['itemId'] as String;
    final text = newState['text'] as String;
    final items = (validator['items'] as List? ?? []).map((item) {
      if (item['id'] == itemId) {
        return {...item, 'text': text};
      }
      return item;
    }).toList();
    return {...validator, 'items': items};
  }
  
  static Map<String, dynamic> _addSelectOption(Map<String, dynamic> validator) {
    const uuid = Uuid();
    final options = List<Map<String, dynamic>>.from(validator['options'] as List? ?? []);
    options.add({
      'id': uuid.v4(),
      'text': 'New option',
    });
    return {...validator, 'options': options};
  }
  
  static Map<String, dynamic> _removeSelectOption(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final optionId = newState['optionId'] as String;
    final options = (validator['options'] as List? ?? [])
        .where((option) => option['id'] != optionId)
        .toList();
    
    // Clear selection if removed option was selected
    String selected = validator['selected'] as String? ?? '';
    if (selected == optionId) {
      selected = '';
    }
    
    return {...validator, 'options': options, 'selected': selected};
  }
  
  static Map<String, dynamic> _editSelectOption(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final optionId = newState['optionId'] as String;
    final text = newState['text'] as String;
    final options = (validator['options'] as List? ?? []).map((option) {
      if (option['id'] == optionId) {
        return {...option, 'text': text};
      }
      return option;
    }).toList();
    return {...validator, 'options': options};
  }
  
  static Map<String, dynamic> _addFile(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final fileInfo = newState['fileInfo'] as Map<String, dynamic>;
    final files = List<Map<String, dynamic>>.from(validator['files'] as List? ?? []);
    files.add(fileInfo);
    return {...validator, 'files': files};
  }
  
  static Map<String, dynamic> _removeFile(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    final fileId = newState['fileId'] as String;
    final files = (validator['files'] as List? ?? [])
        .where((file) => file['id'] != fileId)
        .toList();
    return {...validator, 'files': files};
  }

  static Map<String, dynamic> _updateFileS3(Map<String, dynamic> validator, Map<String, dynamic> newState) {
    AppLogger.debug('ValidatorService: _updateFileS3 called');
    AppLogger.debug('ValidatorService: validator: $validator');
    AppLogger.debug('ValidatorService: newState: $newState');
    
    final offlineFileId = newState['offlineFileId'] as String;
    final s3Key = newState['s3Key'] as String;
    final s3Url = newState['s3Url'] as String;
    final status = newState['status'] as String;
    
    AppLogger.debug('ValidatorService: Looking for offlineFileId: $offlineFileId');
    
    final files = (validator['files'] as List? ?? []).map((file) {
      AppLogger.debug('ValidatorService: Checking file: $file');
      if (file['offlineFileId'] == offlineFileId) {
        AppLogger.debug('ValidatorService: Found matching file, updating with S3 info');
        final updatedFile = {
          ...file,
          's3Key': s3Key,
          's3Url': s3Url,
          'status': status,
        };
        if (newState['removeOfflineRef'] == true) {
          updatedFile.remove('offlineFileId');
          updatedFile.remove('uploadedAt');
        }
        AppLogger.debug('ValidatorService: Updated file: $updatedFile');
        return updatedFile;
      }
      return file;
    }).toList();
    
    final result = {...validator, 'files': files};
    AppLogger.debug('ValidatorService: _updateFileS3 result: $result');
    return result;
  }
} 