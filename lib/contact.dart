import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where students contact you to get a premium key.
const adminTelegramUrl = 'https://t.me/Use_r_tg';

Future<void> openAdminTelegram(BuildContext context) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(adminTelegramUrl), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Telegram. Message @Use_r_tg directly.')),
    );
  }
}
