/// Metadata for a file/object stored in S3.
///
/// This is intentionally lightweight. If/when we adopt `freezed`, we can
/// migrate this class; for now we keep the dependency surface minimal.

import 'package:equatable/equatable.dart';

class StoredFileMetadata extends Equatable {
  final String key;
  final int size;
  final DateTime? lastModified;

  const StoredFileMetadata({
    required this.key,
    required this.size,
    this.lastModified,
  });

  @override
  List<Object?> get props => [key, size, lastModified?.millisecondsSinceEpoch];
} 