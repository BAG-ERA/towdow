// Unified Attachment Parser for CalDAV operations
// Consolidates attachment serialization and parsing logic from VTODO and VJOURNAL parsers
// Eliminates code duplication and provides consistent attachment handling

import 'dart:convert';
import '../../../core/logger.dart';
import '../../models/attachment.dart';

class AttachmentParser {
  /// Serialize an attachment to RFC 5545 ATTACH line with FlowIt extensions
  /// Unified method that handles both file and media attachments
  static String serializeAttachment(Attachment attachment) {
    final parameters = <String>[];
    final uri = attachment.uri;
    
    // Add FlowIt-specific parameters
    final attachType = attachment.type == AttachmentType.media ? 'media' : 'file';
    parameters.add('X-FLOWIT-ATTACHTYPE=$attachType');
    
    final aesKey = attachment.aesKey;
    if (aesKey.isNotEmpty) {
      parameters.add('X-FLOWIT-AESKEY=$aesKey');
    }
    
    // Add media type for media attachments
    if (attachment.type == AttachmentType.media && attachment.mediaType != null) {
      parameters.add('X-FLOWIT-MEDIATYPE=${attachment.mediaType!.name}');
    }
    
    // Add standard ATTACH parameters
    final filename = attachment.filename;
    if (filename.isNotEmpty) {
      parameters.add('FILENAME=${_escapeCalendarText(filename)}');
    }
    
    final contentType = attachment.contentType;
    if (contentType.isNotEmpty) {
      parameters.add('FMTTYPE=$contentType');
    }
    
    final size = attachment.size;
    if (size > 0) {
      parameters.add('SIZE=$size');
    }
    
    // Add S3-specific parameters if available
    final s3Key = attachment.s3Key;
    if (s3Key != null && s3Key.isNotEmpty) {
      parameters.add('X-FLOWIT-S3KEY=$s3Key');
    }

    final s3Url = attachment.s3Url;
    if (s3Url != null && s3Url.isNotEmpty) {
      parameters.add('X-FLOWIT-S3URL=$s3Url');
    }
    
    // Build the ATTACH line
    final paramString = parameters.isNotEmpty ? ';${parameters.join(';')}' : '';
    return 'ATTACH$paramString:$uri';
  }
  
  /// Parse an ATTACH line according to RFC 5545 with FlowIt extensions
  /// Returns an Attachment object instead of Map<String, dynamic>
  static Attachment? parseAttachment(String line) {
    try {
      // Split line into parameters and value parts
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) return null;
      
      final parametersPart = line.substring(0, colonIndex);
      final valuePart = line.substring(colonIndex + 1);
      
      // Extract URI from value part
      final uri = valuePart.trim();
      if (uri.isEmpty) return null;
      
      // Parse parameters
      final parameters = <String, String>{};
      if (parametersPart.contains(';')) {
        final paramList = parametersPart.split(';').skip(1); // Skip 'ATTACH' part
        for (final param in paramList) {
          final equalIndex = param.indexOf('=');
          if (equalIndex > 0) {
            final key = param.substring(0, equalIndex).trim().toUpperCase();
            final value = param.substring(equalIndex + 1).trim();
            // Remove quotes if present and unescape
            parameters[key] = _unescapeCalendarText(value.replaceAll('"', ''));
          }
        }
      }
      
      // Determine attachment type
      final attachType = parameters['X-FLOWIT-ATTACHTYPE'];
      final type = attachType == 'media' ? AttachmentType.media : AttachmentType.file;
      
      // Parse media type for media attachments
      MediaType? mediaType;
      if (type == AttachmentType.media) {
        final mediaTypeStr = parameters['X-FLOWIT-MEDIATYPE'];
        mediaType = _parseMediaType(mediaTypeStr);
      }
      
      // Build attachment object
      final filename = parameters['FILENAME'] ?? '';
      final contentType = parameters['FMTTYPE'] ?? 'application/octet-stream';
      final size = int.tryParse(parameters['SIZE'] ?? '0') ?? 0;
      final aesKey = parameters['X-FLOWIT-AESKEY'] ?? '';
      final s3Key = parameters['X-FLOWIT-S3KEY'];
      final s3Url = parameters['X-FLOWIT-S3URL'];
      
      return type == AttachmentType.media
          ? Attachment.createMedia(
              uri: uri,
              filename: filename,
              size: size,
              contentType: contentType,
              aesKey: aesKey,
              mediaType: mediaType ?? MediaType.unknown,
              s3Key: s3Key,
              s3Url: s3Url,
            )
          : Attachment.createFile(
              uri: uri,
              filename: filename,
              size: size,
              contentType: contentType,
              aesKey: aesKey,
              s3Key: s3Key,
              s3Url: s3Url,
            );
    } catch (e) {
      AppLogger.error('AttachmentParser: Failed to parse attachment line: $line', e, StackTrace.current);
      return null;
    }
  }
  
  /// Parse attachments from JSON array string
  /// Returns List<Attachment> instead of List<Map<String, dynamic>>
  static List<Attachment> parseAttachmentsFromJson(String attachmentsJson) {
    try {
      if (attachmentsJson.isEmpty || attachmentsJson == '[]') {
        return [];
      }
      
      final decoded = jsonDecode(attachmentsJson);
      if (decoded is List) {
        return decoded.map<Attachment>((item) {
          if (item is Map<String, dynamic>) {
            return Attachment.fromLegacyMap(item);
          }
          // Fallback for invalid data
          return Attachment.createFile(
            uri: 'unknown',
            filename: 'unknown',
            size: 0,
            contentType: 'application/octet-stream',
            aesKey: '',
          );
        }).toList();
      }
      
      return [];
    } catch (e) {
      AppLogger.error('AttachmentParser: Failed to parse attachments JSON', e, StackTrace.current);
      return [];
    }
  }
  
  /// Serialize attachments to JSON array string
  /// Accepts List<Attachment> instead of List<Map<String, dynamic>>
  static String serializeAttachmentsToJson(List<Attachment> attachments) {
    try {
      final legacyMaps = attachments.map((a) => a.toLegacyMap()).toList();
      return jsonEncode(legacyMaps);
    } catch (e) {
      AppLogger.error('AttachmentParser: Failed to serialize attachments', e, StackTrace.current);
      return '[]';
    }
  }
  
  /// Separate attachments by type
  /// Returns tuple of (fileAttachments, mediaAttachments)
  static (List<Attachment>, List<Attachment>) separateAttachmentsByType(List<Attachment> attachments) {
    final fileAttachments = <Attachment>[];
    final mediaAttachments = <Attachment>[];
    
    for (final attachment in attachments) {
      if (attachment.type == AttachmentType.media) {
        mediaAttachments.add(attachment);
      } else {
        fileAttachments.add(attachment);
      }
    }
    
    return (fileAttachments, mediaAttachments);
  }
  
  /// Filter attachments by type
  static List<Attachment> filterAttachmentsByType(List<Attachment> attachments, AttachmentType type) {
    return attachments.where((attachment) => attachment.type == type).toList();
  }
  
  /// Get file attachments only
  static List<Attachment> getFileAttachments(List<Attachment> attachments) {
    return filterAttachmentsByType(attachments, AttachmentType.file);
  }
  
  /// Get media attachments only
  static List<Attachment> getMediaAttachments(List<Attachment> attachments) {
    return filterAttachmentsByType(attachments, AttachmentType.media);
  }
  
  // Private helper methods
  
  /// Escape calendar text according to RFC 5545
  static String _escapeCalendarText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }

  /// Unescape calendar text according to RFC 5545 and decode HTML entities
  static String _unescapeCalendarText(String text) {
    return text
        // First handle HTML entities (common in CalDAV responses)
        .replaceAll('&#13;', '') // Remove carriage return entities
        .replaceAll('&#10;', '\n') // Line feed entity to newline
        .replaceAll('&#9;', '\t') // Tab entity
        .replaceAll('&lt;', '<') // Less than entity
        .replaceAll('&gt;', '>') // Greater than entity
        .replaceAll('&amp;', '&') // Ampersand entity (must be last)
        .replaceAll('&quot;', '"') // Quote entity
        .replaceAll('&apos;', "'") // Apostrophe entity
        // Then handle standard iCalendar escaping (RFC 5545)
        .replaceAll('\\n', '\n')
        .replaceAll('\\;', ';')
        .replaceAll('\\,', ',')
        .replaceAll('\\\\', '\\');
  }
  
  /// Parse media type from string
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
}
