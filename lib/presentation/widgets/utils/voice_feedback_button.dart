// Voice feedback button widget
// Displays a text button with mic icon that redirects to voice feedback URL
// Only shown on desktop screens

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

class VoiceFeedbackButton extends StatelessWidget {
  const VoiceFeedbackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _launchVoiceFeedback(),
      icon: const Icon(Icons.mic_rounded, size: 18),
      label: Text(
        AppLocalizations.of(context)!.voiceFeedback,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Future<void> _launchVoiceFeedback() async {
    final Uri url = Uri.parse('https://voice.gettowdow.com/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
