/// Cached file record stored in Hive to support offline uploads/downloads.
///
/// This model deliberately avoids Freezed/code-generation to keep compilation
/// simple for now. Once the schema stabilises we can convert to Freezed.

import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 34)
enum CachedFileStatus {
  @HiveField(0)
  queued,
  @HiveField(1)
  synced,
  @HiveField(2)
  deleted,
}

@HiveType(typeId: 35)
class CachedFile extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String key;

  @HiveField(1)
  final String localPath;

  @HiveField(2)
  final int size;

  @HiveField(3)
  final String? etag;

  @HiveField(4)
  CachedFileStatus status;

  @HiveField(5)
  DateTime? lastModified;

  @HiveField(6)
  final DateTime createdAt;

  CachedFile({
    required this.key,
    required this.localPath,
    required this.size,
    this.etag,
    this.status = CachedFileStatus.queued,
    this.lastModified,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  @override
  List<Object?> get props => [key, localPath, size, etag, status, lastModified?.millisecondsSinceEpoch];
} 