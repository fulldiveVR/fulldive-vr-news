import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/fulldive_theme.dart';

/// Who publishes the app and how to reach them.
///
/// Play's News and Magazines policy requires a clearly labelled contact
/// section in the app itself — not only in the store listing — showing an
/// email address or a phone number belonging to the developer. The same
/// details have to appear on the website and in the Console's store listing
/// contact fields; see `store/README.md` §7.
abstract final class FulldiveContact {
  /// The address published on fulldive.com. Mail sent here has to be read:
  /// Play verifies that the contact route works, and so do users.
  static const email = 'support@fulldive.com';

  /// The trailing slashes matter: without them fulldive.com answers 308, and
  /// Play's URL checks follow redirects rather than accepting them.
  static const contactPage = 'https://fulldive.com/pages/contact-us/';
  static const privacyPolicy = 'https://fulldive.com/privacy-policy/';
  static const termsOfUse = 'https://fulldive.com/terms-of-use/';

  /// The legal entity, as named in the privacy policy and the terms of use.
  /// The Play developer account displays "Browser by Fulldive Co."; the
  /// company behind it, and behind the app, is this one.
  static const publisher = 'Fulldive Corp.';

  /// Kept in step with `version:` in pubspec.yaml by a test, so the number a
  /// user quotes in a support mail is the build they are actually running.
  static const appVersion = '7.0.3';
}

/// Full-screen "Contact us" page, reachable from the feed's menu.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const ContactScreen(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          const Text(
            'Fulldive VR News is published by ${FulldiveContact.publisher} '
            'Write to us about anything in the app — a story that should not '
            'be here, a publisher who wants their feed removed, a bug, or a '
            'question about your data.',
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: FulldiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Email us'),
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.mail_outline,
            label: 'Support email',
            value: FulldiveContact.email,
            onTap: () => _openMail(context),
            trailing: _CopyButton(value: FulldiveContact.email),
          ),
          const SizedBox(height: 10),
          const Text(
            'We answer support mail within a few business days.',
            style: TextStyle(fontSize: 13, color: FulldiveColors.textTertiary),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('On the web'),
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.language,
            label: 'Contact page',
            value: 'fulldive.com/pages/contact-us',
            onTap: () => _openUrl(context, FulldiveContact.contactPage),
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy policy',
            value: 'fulldive.com/privacy-policy',
            onTap: () => _openUrl(context, FulldiveContact.privacyPolicy),
          ),
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.gavel_outlined,
            label: 'Terms of use',
            value: 'fulldive.com/terms-of-use',
            onTap: () => _openUrl(context, FulldiveContact.termsOfUse),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Where the news comes from'),
          const SizedBox(height: 12),
          const Text(
            'Fulldive VR News is a news aggregator. It carries no reporting of '
            'its own: every story is written and published by the outlet named '
            'on it — Road to VR, UploadVR, MIXED Reality and Skarred Ghost '
            'among them. Each story shows its publisher and author, and opens '
            'the publisher’s own page on request.\n\n'
            'Publishers who want their feed removed can write to '
            '${FulldiveContact.email} and we will drop it.',
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: FulldiveColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Fulldive VR News ${FulldiveContact.appVersion}\n'
            '${FulldiveContact.publisher}',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: FulldiveColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the mail client with the address and a subject already filled in.
  /// A headset or emulator often has no mail app at all, so a failure points
  /// the user back at the address rather than silently doing nothing.
  Future<void> _openMail(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // The query is built by hand: Uri's queryParameters encodes spaces as
    // "+", which mail clients show literally in the subject line.
    final uri = Uri(
      scheme: 'mailto',
      path: FulldiveContact.email,
      query: 'subject='
          '${Uri.encodeComponent('Fulldive VR News ${FulldiveContact.appVersion}')}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(const ClipboardData(text: FulldiveContact.email));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No mail app found — ${FulldiveContact.email} copied to the clipboard',
          ),
        ),
      );
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: FulldiveColors.orange,
      ),
    );
  }
}

/// One tappable detail — icon, what it is, and the value in plain text so it
/// is readable even where the link cannot be opened.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FulldiveColors.navySurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: FulldiveColors.orange),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: FulldiveColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: FulldiveColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy',
      icon: const Icon(Icons.copy_rounded, size: 19),
      color: FulldiveColors.textTertiary,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: value));
        messenger.showSnackBar(
          SnackBar(content: Text('$value copied')),
        );
      },
    );
  }
}
