import 'package:hive/hive.dart';

import 'cached_file.dart';
import 'storage_config.dart';

class CachedFileStatusAdapter extends TypeAdapter<CachedFileStatus> {
  @override
  final int typeId = 34;

  @override
  CachedFileStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CachedFileStatus.queued;
      case 1:
        return CachedFileStatus.synced;
      case 2:
        return CachedFileStatus.deleted;
      default:
        return CachedFileStatus.queued;
    }
  }

  @override
  void write(BinaryWriter writer, CachedFileStatus obj) {
    switch (obj) {
      case CachedFileStatus.queued:
        writer.writeByte(0);
        break;
      case CachedFileStatus.synced:
        writer.writeByte(1);
        break;
      case CachedFileStatus.deleted:
        writer.writeByte(2);
        break;
    }
  }
}

class CachedFileAdapter extends TypeAdapter<CachedFile> {
  @override
  final int typeId = 35;

  @override
  CachedFile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CachedFile(
      key: fields[0] as String,
      localPath: fields[1] as String,
      size: fields[2] as int,
      etag: fields[3] as String?,
      status: fields[4] as CachedFileStatus,
      lastModified: fields[5] as DateTime?,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedFile obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.localPath)
      ..writeByte(2)
      ..write(obj.size)
      ..writeByte(3)
      ..write(obj.etag)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.lastModified)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}

class StorageConfigAdapter extends TypeAdapter<StorageConfig> {
  @override
  final int typeId = 36;

  @override
  StorageConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return StorageConfig(
      accountId: fields[0] as String,
      s3Endpoint: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, StorageConfig obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.accountId)
      ..writeByte(1)
      ..write(obj.s3Endpoint);
  }
} 