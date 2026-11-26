import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'expressive.dart';
import 'mili_i18n.dart';

/// The app's GPL-3.0 license, plus the third-party licenses of bundled packages.
class LicensePageView extends StatelessWidget {
  const LicensePageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ExpressiveSubpageHeader(
        title: MiliLocale.t('مجوز متن‌باز', 'Open source license'),
        subtitle: 'GNU GPL v3.0',
        actions: [
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'MiliConfig',
            ),
            child: Text(MiliLocale.t('کتابخانه‌ها', 'Third-party')),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('LICENSE'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MiliConfig VPN is free software: you can redistribute it and/or modify it under the terms of the '
                  'GNU General Public License as published by the Free Software Foundation, version 3. '
                  'Powered by Xray-core, Psiphon, and Tor.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Divider(height: 32),
                SelectableText(snapshot.data!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}
