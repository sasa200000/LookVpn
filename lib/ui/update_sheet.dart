import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/updates.dart';
import '../services/vpn_channel.dart';
import '../state/app_state.dart';
import 'look_i18n.dart';
import 'theme.dart';

Future<void> showUpdateSheet(BuildContext context, AppUpdate update) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UpdateSheet(update: update),
  );
}

/// A compact, animated notification on the dashboard. It appears automatically when a newer
/// release is found and stays out of the way otherwise.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final update = state.availableUpdate;
    if (update == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kCardRadius),
          onTap: () => showUpdateSheet(context, update),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kCardRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.18),
                  scheme.tertiary.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.34),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    Symbols.system_update_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LookLocale.t(
                          'بروزرسانی ${update.version} آماده است',
                          'Update ${update.version} is ready',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.downloadingUpdate
                            ? LookLocale.t(
                                'در حال دانلود… ${(state.updateProgress * 100).round()}٪',
                                'Downloading… ${(state.updateProgress * 100).round()}%',
                              )
                            : LookLocale.t(
                                'بدون خروج از برنامه نصب کنید',
                                'Install it without leaving the app',
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (state.downloadingUpdate) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: state.updateProgress > 0
                                ? state.updateProgress
                                : null,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Symbols.chevron_left_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpdateSheet extends StatelessWidget {
  final AppUpdate update;
  const UpdateSheet({super.key, required this.update});

  Future<void> _install(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.installUpdate();
      if (context.mounted) Navigator.of(context).pop();
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on PlatformException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Update failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) {
        final state = AppScope.of(context);
        final scheme = Theme.of(context).colorScheme;
        final downloading = state.downloadingUpdate;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.system_update_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LookLocale.t(
                          'بروزرسانی ${update.version}',
                          'Update ${update.version}',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  LookLocale.t(
                    'فایل APK داخل برنامه دانلود و مستقیماً نصب می‌شود. داده‌ها و تنظیمات شما حفظ می‌شوند.',
                    'The APK downloads and installs directly inside the app. Your data and settings are kept.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (update.notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.25,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        update.notes,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
                if (downloading) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: state.updateProgress > 0
                          ? state.updateProgress
                          : null,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(state.updateProgress * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
                if (state.updateError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    state.updateError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: downloading
                            ? null
                            : () async {
                                await VpnChannel.openUrl(update.pageUrl);
                              },
                        child: Text(LookLocale.t('صفحه انتشار', 'Release page')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: downloading ? null : () => _install(context),
                        icon: const Icon(Symbols.download_rounded, size: 18),
                        label: Text(
                          downloading
                              ? LookLocale.t('در حال دانلود', 'Downloading')
                              : LookLocale.t('نصب', 'Install'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
