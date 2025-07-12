import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 36)
class StorageConfig extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String accountId; // Foreign key to CaldavAccount.id

  @HiveField(1)
  final String s3Endpoint;

  StorageConfig({required this.accountId, required this.s3Endpoint});

  @override
  List<Object?> get props => [accountId, s3Endpoint];
} 