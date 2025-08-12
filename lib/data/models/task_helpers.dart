// Typed JSON accessors for FlowIt fields on Task
// Encapsulates JSON strings and exposes typed getters/setters.

import 'dart:convert';
import 'task.dart';

extension TaskJsonAccessors on Task {
  Map<String, dynamic> get flowitValidatorJson {
    try {
      final decoded = jsonDecode(flowitValidator);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {'type': 'default'};
  }

  Task withFlowitValidatorJson(Map<String, dynamic> validator) {
    return copyWith(flowitValidator: jsonEncode(validator));
  }

  Map<String, dynamic> get flowitRequirementJson {
    try {
      final decoded = jsonDecode(flowitRequirement);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {};
  }

  Task withFlowitRequirementJson(Map<String, dynamic> requirement) {
    return copyWith(flowitRequirement: jsonEncode(requirement));
  }

  List<dynamic> get flowitKanbanList {
    try {
      final decoded = jsonDecode(flowitKanbanColumn);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const [];
  }

  Task withFlowitKanbanList(List<dynamic> kanban) {
    return copyWith(flowitKanbanColumn: jsonEncode(kanban));
  }

  List<dynamic> get attachmentList {
    try {
      final decoded = jsonDecode(attachments);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const [];
  }

  Task withAttachmentList(List<dynamic> list) {
    return copyWith(attachments: jsonEncode(list));
  }

  List<dynamic> get mediaAttachmentList {
    try {
      final decoded = jsonDecode(mediaAttachments);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const [];
  }

  Task withMediaAttachmentList(List<dynamic> list) {
    return copyWith(mediaAttachments: jsonEncode(list));
  }
}



