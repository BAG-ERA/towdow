// Deep link data models
// Defines kinds and target structure used across parser/service/commands

import 'package:equatable/equatable.dart';

/// Supported deep link types
enum DeepLinkKind {
  projects,
  project,
  workflows,
  workflow,
  today,
  soon,
  anytime,
  nextWeek,
  later,
  settings,
  connect,
}

/// Parsed deep link target used by the app
class DeepLinkTarget extends Equatable {
  final DeepLinkKind kind;
  final String? path; // encoded or decoded project/workflow path
  final Map<String, String> query;

  const DeepLinkTarget({
    required this.kind,
    this.path,
    this.query = const {},
  });

  @override
  List<Object?> get props => [kind, path, query];
}


