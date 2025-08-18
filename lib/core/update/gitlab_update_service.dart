// GitLab Update Service for TowDow
// Checks for new app versions from GitLab releases and shows update dialog
// Uses global navigator key to show dialog from any context

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import '../../data/providers/providers_services_core.dart';

class GitLabUpdateService {
  // --- CONFIG ---
  static const _gitlabBase = 'https://gitlab.com';
  static const _projectPathEncoded = 'towdow%2Ftowdow-flutter';
  static const _downloadUrl = 'https://gettowdow.com/download';
  static const _timeout = Duration(seconds: 6);
  static const _minCheckInterval = Duration(hours: 24);

  // cache keys
  static const _kLastCheckMs = 'update_last_check_epoch';
  static const _kLastSeenVersion = 'update_last_seen_version';

  static bool _dialogShowing = false;

  Future<void> checkAndPromptIfNeeded() async {
    // Respect frequency limit
    if (!await _shouldCheckNow()) return;

    try {
      final current = await _currentVersion();
      if (current == null) {
        await _touchLastCheck();
        return;
      }

      final latest = await _fetchLatestVersionWithNotes();
      if (latest == null) {
        await _touchLastCheck();
        return;
      }

      // Compare versions
      if (latest.version > current) {
        final sp = await SharedPreferences.getInstance();


        await _showUpdateDialog(latest);
        await sp.setString(_kLastSeenVersion, latest.version.toString());
      }
    } finally {
      await _touchLastCheck();
    }
  }

  // --- internals ---
  Future<bool> _shouldCheckNow() async {
    //return true; // DO NOT CHANGE THIS
    final sp = await SharedPreferences.getInstance();
    final last = sp.getInt(_kLastCheckMs);
    if (last == null) return true;
    final lastDt = DateTime.fromMillisecondsSinceEpoch(last);
    return DateTime.now().difference(lastDt) >= _minCheckInterval;
  }

  Future<void> _touchLastCheck() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kLastCheckMs, DateTime.now().millisecondsSinceEpoch);
  }

  Future<Version?> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform(); // reads pubspec version
      return _parseSemVer(info.version);
    } catch (_) {
      return null;
    }
  }

  Version? _parseSemVer(String? v) {
    if (v == null || v.isEmpty) return null;
    try {
      return Version.parse(v); // supports build metadata: 1.2.3+45
    } catch (_) {
      return null;
    }
  }

  String _stripV(String s) => s.startsWith('v') ? s.substring(1) : s;

  Future<_Latest?> _fetchLatestVersionWithNotes() async {
    // Prefer Releases (have description == notes)
    final releasesUri = Uri.parse(
      '$_gitlabBase/api/v4/projects/$_projectPathEncoded/releases'
      '?per_page=1&order_by=released_at&sort=desc',
    );
    try {
      final r = await http
          .get(releasesUri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (r.statusCode == 200) {
        final list = json.decode(r.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final m = list.first as Map<String, dynamic>;
          final tag = (m['tag_name'] ?? '').toString();
          final ver = _parseSemVer(_stripV(tag));
          if (ver != null) {
            final notes = (m['description'] ?? '').toString();
            return _Latest(version: ver, notes: notes.isNotEmpty ? notes : null);
          }
        }
      }
    } catch (_) {}

    // Fallback: latest tag (no notes)
    final tagsUri = Uri.parse(
      '$_gitlabBase/api/v4/projects/$_projectPathEncoded/repository/tags?per_page=1',
    );
    try {
      final t = await http
          .get(tagsUri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (t.statusCode == 200) {
        final list = json.decode(t.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final m = list.first as Map<String, dynamic>;
          final tag = (m['name'] ?? '').toString();
          final ver = _parseSemVer(_stripV(tag));
          if (ver != null) return _Latest(version: ver, notes: null);
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _showUpdateDialog(_Latest latest) async {
    if (_dialogShowing) return; // prevent duplicates if called twice
    final ctx = globalContext;
    if (ctx == null) return;
    _dialogShowing = true;

    await showDialog(
      context: ctx,
      barrierDismissible: false, // <<< MODAL: user must choose
      builder: (dCtx) {
        return PopScope(
          canPop: false, // disable back button
          child: AlertDialog(
            title: Text('New version ${latest.version} available'),
            content: SizedBox(
              width: 520,
              child: latest.notes != null && latest.notes!.trim().isNotEmpty
                  ? Markdown(
                      data: latest.notes!,
                      shrinkWrap: true,
                    )
                  : const Text('A new version of TowDow is available.'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dCtx).pop();
                },
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () async {
                  final uri = Uri.parse(_downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (dCtx.mounted) Navigator.of(dCtx).pop();
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      },
    );

    _dialogShowing = false;
  }
}

class _Latest {
  final Version version;
  final String? notes;
  _Latest({required this.version, this.notes});
}
