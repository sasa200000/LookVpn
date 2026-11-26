import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../services/my_ip.dart';
import 'look_i18n.dart';

/// The selected Psiphon/Tor country, or the automatic fastest server.
String exitRegionLabel(String code) => code.isEmpty
    ? LookLocale.t('سریع‌ترین', 'Fastest')
    : '${countryFlag(code)} ${exitRegions[code] ?? code}';

/// Opens the shared Psiphon/Tor location sheet. Null means the user closed it without a
/// choice; an empty string explicitly selects the fastest server.
Future<String?> showExitRegionPicker(
  BuildContext context, {
  required String selected,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _RegionSheet(selected: selected),
);

/// Psiphon/Tor location picker: fastest first, then every country by name, with search.
class _RegionSheet extends StatefulWidget {
  final String selected;
  const _RegionSheet({required this.selected});

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countries = exitRegions.entries
        .where(
          (e) =>
              _query.isEmpty ||
              e.value.toLowerCase().contains(_query.toLowerCase()) ||
              e.key.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: keyboard + 12,
      ),
      child: SizedBox(
        // Shrinks with the keyboard so the search field and the country list stay usable.
        height: (MediaQuery.sizeOf(context).height - keyboard) * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.location_on_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  LookLocale.t('انتخاب لوکیشن', 'Choose location'),
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              LookLocale.t(
                'برای سایفون و تور؛ سریع‌ترین به‌صورت خودکار یا یک کشور مشخص',
                'For Psiphon and Tor: fastest automatically, or a specific country',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _RegionOption(
              label: LookLocale.t('سریع‌ترین (خودکار)', 'Fastest (automatic)'),
              leading: '⚡',
              selected: widget.selected.isEmpty,
              onTap: () => Navigator.of(context).pop(''),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                hintText: LookLocale.t('جستجوی کشور…', 'Search countries…'),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text(
                LookLocale.t('کشورها', 'Countries'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: countries.isEmpty
                  ? Center(
                      child: Text(
                        LookLocale.t('کشوری پیدا نشد', 'No country found'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final e = countries[index];
                        return _RegionOption(
                          label: e.value,
                          leading: countryFlag(e.key),
                          selected: widget.selected == e.key,
                          onTap: () => Navigator.of(context).pop(e.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionOption extends StatelessWidget {
  final String label;
  final String leading;
  final bool selected;
  final VoidCallback onTap;
  const _RegionOption({
    required this.label,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
      leading: SizedBox(
        width: 32,
        child: Text(leading, style: const TextStyle(fontSize: 20)),
      ),
      title: Text(label),
      trailing: selected
          ? Icon(Symbols.check_circle_rounded, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
