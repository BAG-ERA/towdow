// Validator service for managing task validation logic
// Handles parsing, validation, and state management for the new validator system
// Maintains backward compatibility with legacy validator format

import 'dart:convert';
import '../../core/logger.dart';

/// Service for managing validator logic
class ValidatorService {
  
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
  
  /// Update validator state by ID
  static List<List<Map<String, dynamic>>> updateValidatorState(
    List<List<Map<String, dynamic>>> validatorLists,
    String validatorId,
    dynamic newState,
  ) {
    final updatedLists = <List<Map<String, dynamic>>>[];
    
    for (final validatorList in validatorLists) {
      final updatedList = <Map<String, dynamic>>[];
      
      for (final validator in validatorList) {
        if (validator['id'] == validatorId) {
          updatedList.add(_updateValidatorData(validator, newState));
        } else {
          updatedList.add(Map<String, dynamic>.from(validator));
        }
      }
      
      updatedLists.add(updatedList);
    }
    
    return updatedLists;
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
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': 'checklist-$now',
      'type': 'checklist',
      'required': required,
      'title': title,
      'items': itemTexts.asMap().entries.map((entry) => {
        'id': 'item-$now-${entry.key}',
        'text': entry.value,
        'checked': false,
      }).toList(),
    };
  }
  
  static Map<String, dynamic> createSingleSelectValidator({
    required String title,
    required List<String> optionTexts,
    bool required = true,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': 'select-$now',
      'type': 'single_select',
      'required': required,
      'title': title,
      'options': optionTexts.asMap().entries.map((entry) => {
        'id': 'option-$now-${entry.key}',
        'text': entry.value,
      }).toList(),
      'selected': '',
    };
  }
  
  static Map<String, dynamic> createFreeFieldValidator({
    required String title,
    String? helper,
    bool required = true,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': 'field-$now',
      'type': 'free_field',
      'required': required,
      'title': title,
      'value': '',
      if (helper != null) 'helper': helper,
    };
  }
  
  /// Private helper methods
  
  static List<List<Map<String, dynamic>>> _migrateLegacyValidator(String legacyJson) {
    try {
      final legacy = jsonDecode(legacyJson);
      
      if (legacy['type'] == 'default') {
        return []; // No validators for default type
      }
      
      if (legacy['type'] == 'form' && legacy['form'] is List) {
        final validators = <Map<String, dynamic>>[];
        
        for (final question in legacy['form']) {
          if (question is Map<String, dynamic>) {
            validators.add(_migrateFormQuestion(question));
          }
        }
        
        return validators.isNotEmpty ? [validators] : [];
      }
      
      return [];
    } catch (e, stackTrace) {
      AppLogger.error('ValidatorService: Failed to migrate legacy validator', e, stackTrace);
      return [];
    }
  }
  
  static Map<String, dynamic> _migrateFormQuestion(Map<String, dynamic> question) {
    final type = question['questiontype'] as String?;
    final id = question['questionid'] as String? ?? 'migrated-${DateTime.now().millisecondsSinceEpoch}';
    final title = question['questiontext'] as String? ?? 'Migrated Question';
    final required = question['mandatory'] as bool? ?? true;
    final options = question['questionoption'] as List? ?? [];
    
    switch (type) {
      case 'select':
        return {
          'id': id,
          'type': 'single_select',
          'required': required,
          'title': title,
          'options': options.asMap().entries.map((entry) => {
            'id': 'option-$id-${entry.key}',
            'text': entry.value.toString(),
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
        return {
          'id': id,
          'type': 'checklist',
          'required': required,
          'title': title,
          'items': options.asMap().entries.map((entry) => {
            'id': 'item-$id-${entry.key}',
            'text': entry.value.toString(),
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
} 