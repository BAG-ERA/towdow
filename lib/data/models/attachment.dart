// Unified Attachment model for all attachment types
// Replaces Map<String, dynamic> approach with type-safe model
// Supports both file attachments and media attachments

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'attachment.freezed.dart';
part 'attachment.g.dart';

/// Attachment type enumeration
@HiveType(typeId: 30)
enum AttachmentType {
  @HiveField(0)
  file,    // Regular file attachment
  @HiveField(1)
  media,   // Media attachment (images, videos, etc.)
}

/// Media type enumeration for media attachments
@HiveType(typeId: 31)
enum MediaType {
  @HiveField(0)
  image,
  @HiveField(1)
  video,
  @HiveField(2)
  audio,
  @HiveField(3)
  document,
  @HiveField(4)
  unknown,
}

/// Unified Attachment model
@HiveType(typeId: 32)
@freezed
class Attachment with _$Attachment {
  const factory Attachment({
    @HiveField(0) required String uri,
    @HiveField(1) required String filename,
    @HiveField(2) required int size,
    @HiveField(3) required String contentType,
    @HiveField(4) required AttachmentType type,
    @HiveField(5) required String aesKey,
    @HiveField(6) required DateTime createdAt,
    @HiveField(7) @Default('local') String status,
    @HiveField(8) String? s3Key,
    @HiveField(9) String? s3Url,
    @HiveField(10) DateTime? uploadedAt,
    @HiveField(11) MediaType? mediaType,
    @HiveField(12) String? offlineFileId,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) => _$AttachmentFromJson(json);

  /// Create a file attachment
  factory Attachment.createFile({
    required String uri,
    required String filename,
    required int size,
    required String contentType,
    required String aesKey,
    String? s3Key,
    String? s3Url,
    String? offlineFileId,
  }) {
    return Attachment(
      uri: uri,
      filename: filename,
      size: size,
      contentType: contentType,
      type: AttachmentType.file,
      aesKey: aesKey,
      createdAt: DateTime.now(),
      s3Key: s3Key,
      s3Url: s3Url,
      offlineFileId: offlineFileId,
    );
  }

  /// Create a media attachment
  factory Attachment.createMedia({
    required String uri,
    required String filename,
    required int size,
    required String contentType,
    required String aesKey,
    required MediaType mediaType,
    String? s3Key,
    String? s3Url,
    String? offlineFileId,
  }) {
    return Attachment(
      uri: uri,
      filename: filename,
      size: size,
      contentType: contentType,
      type: AttachmentType.media,
      aesKey: aesKey,
      createdAt: DateTime.now(),
      mediaType: mediaType,
      s3Key: s3Key,
      s3Url: s3Url,
      offlineFileId: offlineFileId,
    );
  }

  /// Convert from legacy Map<String, dynamic> format
  factory Attachment.fromLegacyMap(Map<String, dynamic> map) {
    final attachType = map['attachType'] as String?;
    final type = attachType == 'media' ? AttachmentType.media : AttachmentType.file;
    
    MediaType? mediaType;
    if (type == AttachmentType.media) {
      final mediaTypeStr = map['mediaType'] as String?;
      mediaType = AttachmentHelper._parseMediaType(mediaTypeStr);
    }

    return Attachment(
      uri: map['uri'] as String? ?? '',
      filename: map['filename'] as String? ?? '',
      size: map['size'] as int? ?? 0,
      contentType: map['fmttype'] as String? ?? map['contentType'] as String? ?? 'application/octet-stream',
      type: type,
      aesKey: map['aesKey'] as String? ?? '',
      createdAt: AttachmentHelper._parseDateTime(map['createdAt'] as String?) ?? DateTime.now(),
      status: map['status'] as String? ?? 'local',
      s3Key: map['s3Key'] as String?,
      s3Url: map['s3Url'] as String?,
      uploadedAt: AttachmentHelper._parseDateTime(map['uploadedAt'] as String?),
      mediaType: mediaType,
      offlineFileId: map['offlineFileId'] as String?,
    );
  }



}

/// Extension for Attachment utility methods
extension AttachmentExtension on Attachment {
  /// Check if attachment is a media file
  bool get isMedia => type == AttachmentType.media;

  /// Check if attachment is a file
  bool get isFile => type == AttachmentType.file;

  /// Check if attachment is uploaded
  bool get isUploaded => status == 'uploaded' || s3Key != null;

  /// Check if attachment is stored locally
  bool get isLocal => status == 'local';

  /// Convert to legacy Map<String, dynamic> format for backward compatibility
  Map<String, dynamic> toLegacyMap() {
    final map = <String, dynamic>{
      'uri': uri,
      'filename': filename,
      'size': size,
      'fmttype': contentType,
      'attachType': type == AttachmentType.media ? 'media' : 'file',
      'aesKey': aesKey,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };

    if (s3Key != null) map['s3Key'] = s3Key;
    if (s3Url != null) map['s3Url'] = s3Url;
    if (uploadedAt != null) map['uploadedAt'] = uploadedAt!.toIso8601String();
    if (offlineFileId != null) map['offlineFileId'] = offlineFileId;
    if (mediaType != null) map['mediaType'] = mediaType!.name;

    return map;
  }
}

/// Helper functions for Attachment
class AttachmentHelper {
  static MediaType _parseMediaType(String? mediaTypeStr) {
    if (mediaTypeStr == null) return MediaType.unknown;
    
    switch (mediaTypeStr.toLowerCase()) {
      case 'image':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      case 'audio':
        return MediaType.audio;
      case 'document':
        return MediaType.document;
      default:
        return MediaType.unknown;
    }
  }

  static DateTime? _parseDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return null;
    return DateTime.tryParse(dateTimeStr);
  }
}

/// Extension for media type detection from filename
extension MediaTypeDetection on String {
  MediaType get mediaTypeFromExtension {
    final extension = split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
      case 'tiff':
      case 'tif':
        return MediaType.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
      case 'mkv':
      case '3gp':
      case 'm4v':
        return MediaType.video;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
        return MediaType.audio;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return MediaType.document;
      default:
        return MediaType.unknown;
    }
  }
}
