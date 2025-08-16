// VJOURNAL parser for CalDAV operations
// Centralizes all VJOURNAL serialization and parsing logic including attendee and attachments handling

import '../../../core/logger.dart';
import '../../models/journal.dart';
import '../../models/attendee.dart';
import '../../models/attachment.dart';
import 'attachment_parser.dart';

class VJournalParser {
  /// Convert FlowIt Journal to iCalendar VJOURNAL format - RFC 5545
  static String serializeJournal(Journal journal, {String? etag}) {
    final vcal = StringBuffer();
    vcal.writeln('BEGIN:VCALENDAR');
    vcal.writeln('VERSION:2.0');
    vcal.writeln('PRODID:-//FlowIt//FlowIt CalDAV//EN');
    vcal.writeln('BEGIN:VJOURNAL');
    vcal.writeln('UID:${journal.uid}');
    vcal.writeln('DTSTAMP:${_formatDateTime(journal.dtstamp)}');
    vcal.writeln('CREATED:${_formatDateTime(journal.created)}');
    vcal.writeln('LAST-MODIFIED:${_formatDateTime(journal.lastModified)}');
    vcal.writeln('SUMMARY:${_escapeCalendarText(journal.summary)}');

    if (journal.description.isNotEmpty) {
      vcal.writeln('DESCRIPTION:${_escapeCalendarText(journal.description)}');
    }

    // Categories
    if (journal.categoryIds.isNotEmpty) {
      vcal.writeln('CATEGORIES:${journal.categoryIds.join(',')}');
    }

    // Organizer (RFC 5545)
    if (journal.organizer != null) {
      vcal.writeln('ORGANIZER:mailto:${journal.organizer}');
    }

    // Attendees (RFC 5545)
    for (final attendee in journal.attendees) {
      vcal.writeln(_serializeAttendee(attendee));
    }

    // Attachments (RFC 5545 ATTACH with FlowIt extensions)
    final allAttachments = AttachmentParser.parseAttachmentsFromJson(journal.attachments);
    final mediaAttachments = AttachmentParser.parseAttachmentsFromJson(journal.mediaAttachments);
    
    // Serialize all attachments using unified parser
    for (final attachment in allAttachments) {
      vcal.writeln(AttachmentParser.serializeAttachment(attachment));
    }
    
    for (final attachment in mediaAttachments) {
      vcal.writeln(AttachmentParser.serializeAttachment(attachment));
    }

    // FlowIt-specific extensions
    vcal.writeln('X-FLOWIT-TYPE:journal');

    if (etag != null) {
      vcal.writeln('X-FLOWIT-ETAG:$etag');
    }

    vcal.writeln('END:VJOURNAL');
    vcal.writeln('END:VCALENDAR');
    return vcal.toString();
  }

  /// Parse a single VJOURNAL string into a Journal object
  static Journal? parseVJOURNAL(String vjournal) {
    try {
      final unfolded = vjournal.replaceAll(RegExp(r'\r?\n[\s]+'), '');
      final lines = unfolded.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);

      String? uid, summary, description, organizer;
      DateTime? created, lastModified;
      List<String> categories = [];
      List<Attendee> attendees = [];
      List<Attachment> attachments = [];
      List<Attachment> mediaAttachments = [];

      for (final line in lines) {
        if (line.startsWith('UID:')) {
          uid = line.substring(4);
        } else if (line.startsWith('SUMMARY:')) {
          summary = _unescapeCalendarText(line.substring(8));
        } else if (line.startsWith('DESCRIPTION:')) {
          description = _unescapeCalendarText(line.substring(12));
        } else if (line.startsWith('CREATED:')) {
          created = _parseDateTime(line.substring(8));
        } else if (line.startsWith('LAST-MODIFIED:')) {
          lastModified = _parseDateTime(line.substring(14));
        } else if (line.startsWith('CATEGORIES:')) {
          categories = line.substring(11).split(',').where((c) => c.trim().isNotEmpty).toList();
        } else if (line.startsWith('ORGANIZER:')) {
          organizer = line.substring(10);
          if (organizer.startsWith('mailto:')) {
            organizer = organizer.substring(7);
          }
        } else if (line.startsWith('ATTENDEE:') || line.startsWith('ATTENDEE;')) {
          final attendee = _parseAttendee(line);
          if (attendee != null) {
            final idx = attendees.indexWhere((a) => a.email == attendee.email);
            if (idx >= 0) {
              attendees[idx] = attendee;
            } else {
              attendees.add(attendee);
            }
          }
        } else if (line.startsWith('ATTACH:') || line.startsWith('ATTACH;')) {
          final attachment = AttachmentParser.parseAttachment(line);
          if (attachment != null) {
            if (attachment.type == AttachmentType.media) {
              mediaAttachments.add(attachment);
            } else {
              attachments.add(attachment);
            }
          }
        }
      }

      if (uid != null && summary != null) {
        return Journal(
          uid: uid,
          summary: summary,
          description: description ?? '',
          lastModified: lastModified ?? DateTime.now(),
          created: created ?? DateTime.now(),
          dtstamp: DateTime.now(),
          organizer: organizer,
          categoryIds: categories,
          attachments: AttachmentParser.serializeAttachmentsToJson(attachments),
          mediaAttachments: AttachmentParser.serializeAttachmentsToJson(mediaAttachments),
          attendees: attendees,
        );
      }
    } catch (e) {
      AppLogger.error('VJournalParser: Failed to parse VJOURNAL', e, StackTrace.current);
    }
    return null;
  }

  /// Parse multiple VJOURNAL objects from CalDAV XML response
  static List<Journal> parseJournalsFromResponse(String xmlResponse) {
    final result = <Journal>[];
    try {
      final pattern = RegExp(r'BEGIN:VJOURNAL.*?END:VJOURNAL', dotAll: true);
      final matches = pattern.allMatches(xmlResponse);
      for (final m in matches) {
        final content = m.group(0)!;
        final j = parseVJOURNAL(content);
        if (j != null) result.add(j);
      }
    } catch (e) {
      AppLogger.error('VJournalParser: Failed to parse journals response', e, StackTrace.current);
    }
    return result;
  }

  /// Parse VJOURNAL from calendar-data (REPORT)
  static Journal? parseVJOURNALFromCalendarData(String calendarData) {
    try {
      final pattern = RegExp(r'BEGIN:VJOURNAL.*?END:VJOURNAL', dotAll: true);
      final match = pattern.firstMatch(calendarData);
      if (match != null) {
        return parseVJOURNAL(match.group(0)!);
      }
    } catch (e) {
      AppLogger.error('VJournalParser: Failed to parse from calendar data', e, StackTrace.current);
    }
    return null;
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').replaceAll('.', '').substring(0, 15)}Z';
  }

  static DateTime? _parseDateTime(String dateTimeStr) {
    try {
      if (dateTimeStr.endsWith('Z')) {
        final clean = dateTimeStr.substring(0, dateTimeStr.length - 1);
        if (clean.length >= 15) {
          return DateTime.utc(
            int.parse(clean.substring(0, 4)),
            int.parse(clean.substring(4, 6)),
            int.parse(clean.substring(6, 8)),
            int.parse(clean.substring(9, 11)),
            int.parse(clean.substring(11, 13)),
            int.parse(clean.substring(13, 15)),
          );
        }
      }
      return DateTime.tryParse(dateTimeStr);
    } catch (_) {
      return null;
    }
  }

  static String _escapeCalendarText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }

  static String _unescapeCalendarText(String text) {
    return text
        .replaceAll('&#13;', '')
        .replaceAll('&#10;', '\n')
        .replaceAll('&#9;', '\t')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('\\n', '\n')
        .replaceAll('\\;', ';')
        .replaceAll('\\,', ',')
        .replaceAll('\\\\', '\\');
  }

  static String _serializeAttendee(Attendee attendee) {
    final parameters = <String>[];
    if (attendee.displayName != null && attendee.displayName!.isNotEmpty) {
      parameters.add('CN=${attendee.displayName}');
    }
    if (attendee.status != AttendeeStatus.needsAction) {
      parameters.add('PARTSTAT=${attendee.status.value}');
    }
    if (attendee.role != AttendeeRole.requiredParticipant) {
      parameters.add('ROLE=${attendee.role.value}');
    }
    if (attendee.rsvpRequested) {
      parameters.add('RSVP=TRUE');
    }
    if (attendee.userType != CalendarUserType.individual) {
      parameters.add('CUTYPE=${attendee.userType.value}');
    }
    if (attendee.delegatedFrom != null) {
      parameters.add('DELEGATED-FROM=${attendee.delegatedFrom}');
    }
    if (attendee.delegatedTo != null) {
      parameters.add('DELEGATED-TO=${attendee.delegatedTo}');
    }
    if (attendee.scheduleAgent != null) {
      parameters.add('SCHEDULE-AGENT=${attendee.scheduleAgent}');
    }
    if (attendee.memberOf != null) {
      parameters.add('MEMBER=${attendee.memberOf}');
    }
    final paramString = parameters.isNotEmpty ? ';${parameters.join(';')}' : '';
    return 'ATTENDEE$paramString:mailto:${attendee.email}';
  }

  static Attendee? _parseAttendee(String line) {
    try {
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) return null;
      final parametersPart = line.substring(0, colonIndex);
      final valuePart = line.substring(colonIndex + 1);

      String email = valuePart;
      if (email.startsWith('mailto:')) {
        email = email.substring(7);
      }
      if (email.isEmpty) return null;

      final parameters = <String, String>{};
      if (parametersPart.contains(';')) {
        final paramList = parametersPart.split(';').skip(1);
        for (final param in paramList) {
          final equalIndex = param.indexOf('=');
          if (equalIndex > 0) {
            final key = param.substring(0, equalIndex).trim().toUpperCase();
            final value = param.substring(equalIndex + 1).trim();
            parameters[key] = _unescapeCalendarText(value.replaceAll('"', ''));
          }
        }
      }

      return Attendee(
        email: email,
        displayName: parameters['CN'],
        status: AttendeeStatus.fromString(parameters['PARTSTAT'] ?? 'NEEDS-ACTION'),
        role: AttendeeRole.fromString(parameters['ROLE'] ?? 'REQ-PARTICIPANT'),
        rsvpRequested: parameters['RSVP']?.toUpperCase() == 'TRUE',
        userType: CalendarUserType.fromString(parameters['CUTYPE'] ?? 'INDIVIDUAL'),
        delegatedFrom: parameters['DELEGATED-FROM'],
        delegatedTo: parameters['DELEGATED-TO'],
        scheduleAgent: parameters['SCHEDULE-AGENT'],
        memberOf: parameters['MEMBER'],
      );
    } catch (e) {
      AppLogger.error('VJournalParser: Failed to parse attendee line: $line', e, StackTrace.current);
      return null;
    }
  }


}


