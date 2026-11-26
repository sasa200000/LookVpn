import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../services/my_ip.dart';
import '../services/vpn_channel.dart';
import '../services/xray_config.dart';
import '../state/app_state.dart';
import 'about_page.dart';
import 'bettbox_widgets.dart';
import 'cf_accounts_page.dart';
import 'chain_proxies_page.dart';
import 'config_view_page.dart';
import 'dashboard_tools.dart';
import 'dns_page.dart';
import 'engine_page.dart';
import 'expressive.dart';
import 'format.dart';
import 'fragments_page.dart';
import 'interface_settings_page.dart';
import 'log_page.dart';
import 'mili_i18n.dart';
import 'mili_toolbox_page.dart';
import 'noises_page.dart';
import 'per_app_page.dart';
import 'routing_page.dart';
import 'settings_page.dart';
import 'tor_bridges_page.dart';
import 'update_sheet.dart';

/// The expressive Bento dashboard.
///
/// Cards are real modules, not static decoration: each one opens a working tool
/// or inspector. The edit mode adds widget-board wobble, drag-and-drop ordering
/// and 1x1 / 2x1 / 2x2 footprints persisted through DeviceSettings.
class ExpressiveDashboardTab extends StatefulWidget {
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenSettings;
  final VoidCallback onManageNodes;

  const ExpressiveDashboardTab({
    super.key,
    required this.onOpenScanner,
    required this.onOpenSettings,
    required this.onManageNodes,
  });

  @override
  State<ExpressiveDashboardTab> createState() => _ExpressiveDashboardTabState();
}

class _ExpressiveDashboardTabState extends State<ExpressiveDashboardTab> {
  static const _dailyLimit = 100000;

  Timer? _ticker;
  final List<double> _speedHistory = List<double>.filled(24, 0, growable: true);
  int _chartRevision = 0;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    QuickSettingsStore.load();
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      final speed = (state.downSpeed + state.upSpeed).toDouble();
      _speedHistory.add(speed);
      if (_speedHistory.length > 24) _speedHistory.removeAt(0);
      _chartRevision++;
      if (state.isConnected ||
          speed > 0 ||
          _speedHistory.any((value) => value > 0)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _modeName(ConnectionMode mode) => switch (mode) {
    ConnectionMode.worker => MiliLocale.t('ورکر', 'Worker'),
    ConnectionMode.warp => 'WARP',
    ConnectionMode.masque => 'MASQUE',
    ConnectionMode.serverless => MiliLocale.t('سرورلس', 'Serverless'),
    ConnectionMode.psiphon => MiliLocale.t('سایفون', 'Psiphon'),
    ConnectionMode.tor => MiliLocale.t('تور', 'Tor'),
    ConnectionMode.node => MiliLocale.t('نود مستقیم', 'Direct node'),
  };

  String _protocolLabel(String protocol) => switch (protocol) {
    'vless_xhttp' => 'XHTTP',
    'trojan_ws' => 'Trojan',
    'shadowsocks_ws' => 'SS',
    _ => 'VLESS',
  };

  String _exitLabel(AppState state) {
    if (state.mode == ConnectionMode.node && state.nodeChain != null) {
      return state.nodeChain!.name;
    }
    if (state.mode == ConnectionMode.worker && state.selected != null) {
      final deployment = state.selected!;
      return deployment.deployment.customDomain ?? deployment.deployment.host;
    }
    return state.exitNode.name;
  }

  void _setSize(BuildContext context, AppState state, String id) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final current = state.device.dashboardSizes[id] ?? '1x1';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MiliLocale.t('اندازه کارت', 'Card size'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MiliLocale.t(
                    'چیدمان بنتو را دقیقاً مطابق سلیقه‌ات بساز.',
                    'Shape the bento layout exactly the way you want.',
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final (size, label, ratio) in const [
                      ('1x1', 'کوچک', '1 × 1'),
                      ('2x1', 'پهن', '2 × 1'),
                      ('2x2', 'بزرگ', '2 × 2'),
                    ]) ...[
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            final next = Map<String, String>.of(
                              state.device.dashboardSizes,
                            )..[id] = size;
                            state.write('device.dashboard.sizes', next);
                            Navigator.of(context).pop();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: current == size
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: current == size
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  height: 42,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: current == size ? 0.20 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      ratio,
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (size != '2x2') const SizedBox(width: 9),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _moveCard(AppState state, String from, String to) {
    if (from == to) return;
    final cards = List<String>.of(state.device.dashboardCards);
    if (!cards.contains(from) || !cards.contains(to)) return;
    cards.remove(from);
    cards.insert(cards.indexOf(to), from);
    HapticFeedback.mediumImpact();
    state.write('device.dashboard.cards', cards);
  }

  void _hideCard(AppState state, String id) {
    HapticFeedback.mediumImpact();
    final cards = List<String>.of(state.device.dashboardCards)..remove(id);
    state.write('device.dashboard.cards', cards);
  }

  void _addCard(AppState state, String id) {
    if (state.device.dashboardCards.contains(id)) return;
    HapticFeedback.selectionClick();
    state.write('device.dashboard.cards', [...state.device.dashboardCards, id]);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = state.isConnected;
    final busy = state.isBusy;
    final failed = state.status == VpnStatus.disconnected && state.error != null;
    final cards = state.device.dashboardCards;
    final hidden = DeviceSettings.dashboardCardIds
        .where((id) => !cards.contains(id))
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        miliHomeTopInset(context) + 8,
        16,
        108,
      ),
      children: [
        const UpdateBanner(),
        if (state.needsReconnect)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: BentoSurface(
              highlight: true,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  BentoIcon(Symbols.sync_rounded, filled: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      MiliLocale.t(
                        'تنظیمات تغییر کرده؛ برای اعمال دوباره وصل شوید.',
                        'Settings changed; reconnect to apply them.',
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: state.reconnect,
                    child: Text(MiliLocale.t('اعمال', 'Apply')),
                  ),
                ],
              ),
            ),
          ),
        _DashboardHeading(
          editMode: _editMode,
          connected: connected,
          onEdit: () => setState(() => _editMode = !_editMode),
        ),
        if (_editMode) ...[
          _EditToolbar(
            onAdd: hidden.isEmpty
                ? null
                : () => _showCardsSheet(context, state),
            onReset: () {
              state.write(
                'device.dashboard.cards',
                DeviceSettings.defaultDashboardCards,
              );
              state.write(
                'device.dashboard.sizes',
                DeviceSettings.defaultDashboardSizes,
              );
            },
            onDone: () => setState(() => _editMode = false),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final full = width;
            final half = (width - kBentoGap) / 2;
            final children = <Widget>[];
            for (final id in cards) {
              final size = state.device.dashboardSizes[id] ?? '1x1';
              final cardWidth = size.startsWith('1') ? half : full;
              children.add(
                _BentoEditSlot(
                  key: ValueKey(id),
                  id: id,
                  width: cardWidth,
                  editing: _editMode,
                  animate: state.motionEnabled.value,
                  onMove: (from) => _moveCard(state, from, id),
                  onResize: () => _setSize(context, state, id),
                  onHide: () => _hideCard(state, id),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: size == '2x2'
                          ? 264
                          : size == '2x1'
                          ? 178
                          : 158,
                    ),
                    child: _buildCard(
                      context,
                      state,
                      id,
                      compact: size.startsWith('1'),
                    ),
                  ),
                ),
              );
            }
            if (_editMode) {
              for (final id in hidden) {
                children.add(
                  SizedBox(
                    width: half,
                    child: _HiddenCardSlot(
                      id: id,
                      onAdd: () => _addCard(state, id),
                    ),
                  ),
                );
              }
            }
            return Wrap(
              spacing: kBentoGap,
              runSpacing: kBentoGap,
              children: children,
            );
          },
        ),
        const SizedBox(height: 16),
        _DashboardFooter(
          connected: connected,
          busy: busy,
          failed: failed,
          onManageNodes: widget.onManageNodes,
          onSettings: widget.onOpenSettings,
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppState state,
    String id, {
    required bool compact,
  }) {
    return switch (id) {
      'connection' => _ConnectionCard(
        state: state,
        compact: compact,
        modeName: _modeName,
        protocolLabel: _protocolLabel,
        exitLabel: _exitLabel,
        onManageNodes: widget.onManageNodes,
      ),
      'speed' => _SpeedCard(
        state: state,
        compact: compact,
        history: _speedHistory,
        revision: _chartRevision,
      ),
      'quota' => _QuotaCard(state: state, compact: compact),
      'network' => _NetworkCard(state: state, compact: compact),
      'quick' => _QuickCard(state: state, compact: compact),
      'toolbox' => _ToolboxCard(
        state: state,
        compact: compact,
        onOpenScanner: widget.onOpenScanner,
      ),
      'engine' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: state.isMihomo ? 'Mihomo' : 'Xray',
        detail: state.isMihomo
            ? MiliLocale.t(
                '${state.mihomoSubscriptions.length} اشتراک',
                '${state.mihomoSubscriptions.length} subscriptions',
              )
            : MiliLocale.t('Worker · WARP · MASQUE', 'Worker · WARP · MASQUE'),
        onTap: () => _openPage(const EngineSettingsPage()),
      ),
      'cleanIps' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t(
          '${state.vless.cleanIps.length} آی‌پی',
          '${state.vless.cleanIps.length} IPs',
        ),
        detail: state.vless.cleanIps.isEmpty
            ? MiliLocale.t('لیست خالی است', 'List is empty')
            : state.vless.cleanIps.take(2).join(' · '),
        onTap: widget.onOpenScanner,
      ),
      'proxyIps' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t(
          '${state.vless.proxyIps.length} آی‌پی',
          '${state.vless.proxyIps.length} IPs',
        ),
        detail: state.vless.proxyIps.isEmpty
            ? MiliLocale.t('پیش‌فرض ورکر', 'Worker default')
            : state.vless.proxyIps.take(2).join(' · '),
        onTap: () => _openPage(const SettingsPage()),
      ),
      'placement' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: switch (state.vless.placement) {
          'smart' => MiliLocale.t('هوشمند', 'Smart'),
          'targeted' => MiliLocale.t('منطقه‌ای', 'Targeted'),
          _ => MiliLocale.t('خودکار', 'Automatic'),
        },
        detail: state.vless.placement == 'targeted'
            ? state.vless.placementRegion
            : (state.device.deployment.isEmpty
                  ? MiliLocale.t('بدون استقرار', 'No deployment')
                  : state.device.deployment),
        wide: true,
        onTap: () => _openPage(const SettingsPage()),
      ),
      'dns' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: state.profile.general.localDns,
        detail: state.profile.general.enableFakeDns
            ? MiliLocale.t('DNS فیک روشن', 'Fake DNS on')
            : state.profile.general.antiSanctionDns,
        onTap: () => _openPage(const DnsPage()),
      ),
      'routing' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t(
          '${_activeRules(state)} قانون',
          '${_activeRules(state)} rules',
        ),
        detail: MiliLocale.t(
          '${state.profile.routing.bypass.domains.length + state.profile.routing.block.domains.length} سفارشی',
          '${state.profile.routing.bypass.domains.length + state.profile.routing.block.domains.length} custom',
        ),
        onTap: () => _openPage(const RoutingHubPage()),
      ),
      'fragments' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t(
          '${state.profile.fragments.length} قطعه',
          '${state.profile.fragments.length} pieces',
        ),
        detail: MiliLocale.t('تنظیم TCP', 'TCP tuning'),
        onTap: () => _openPage(const FragmentsPage(section: 'serverless.')),
      ),
      'noises' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t(
          '${state.profile.udpNoises.length} پروفایل',
          '${state.profile.udpNoises.length} profiles',
        ),
        detail: MiliLocale.t('تنظیم UDP', 'UDP tuning'),
        onTap: () => _openPage(const NoisesPage(section: 'serverless.')),
      ),
      'perApp' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: switch (state.device.perAppMode) {
          PerAppMode.include => MiliLocale.t('انتخابی', 'Selected'),
          PerAppMode.exclude => MiliLocale.t('استثنا', 'Excluded'),
          PerAppMode.off => MiliLocale.t('همه برنامه‌ها', 'All apps'),
        },
        detail: MiliLocale.t(
          '${state.device.perAppApps.length} برنامه',
          '${state.device.perAppApps.length} apps',
        ),
        onTap: () => _openPage(const PerAppPage()),
      ),
      'chains' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t(
          '${state.profile.chains.length} کانفیگ',
          '${state.profile.chains.length} configs',
        ),
        detail: MiliLocale.t('خروج زنجیره‌ای', 'Chained exit'),
        onTap: () => _openPage(const ChainProxiesPage()),
      ),
      'cloudflare' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t(
          '${state.cfAccounts.length} حساب',
          '${state.cfAccounts.length} accounts',
        ),
        detail: MiliLocale.t(
          '${state.deployments.length} استقرار',
          '${state.deployments.length} deployments',
        ),
        onTap: () => _openPage(const CfAccountsPage()),
      ),
      'tor' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: torBridges[state.device.torBridge] ?? 'Tor',
        detail: state.profile.tor.bridges.isEmpty
            ? MiliLocale.t('بریج سفارشی ندارید', 'No custom bridges')
            : MiliLocale.t(
                '${state.profile.tor.bridges.length} بریج',
                '${state.profile.tor.bridges.length} bridges',
              ),
        onTap: () => _openPage(const TorBridgesPage()),
      ),
      'appearance' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: state.device.themeColor,
        detail: '${state.device.themeMode} · ${state.device.fontFamily}',
        onTap: () => _openPage(const InterfaceSettingsPage()),
      ),
      'scanner' => _InfoCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        value: MiliLocale.t('کشوری', 'By country'),
        detail: MiliLocale.t('پینگ و Clean IP', 'Ping & Clean IP'),
        onTap: widget.onOpenScanner,
      ),
      'logs' => _ShortcutCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        detail: MiliLocale.t('مشاهده خروجی هسته', 'View core output'),
        onTap: () => _openPage(const LogPage()),
      ),
      'config' => _ShortcutCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        detail: MiliLocale.t('پیش‌نمایش JSON', 'Preview JSON'),
        onTap: () => _openPage(const ConfigViewPage()),
      ),
      'about' => _ShortcutCard(
        title: _cardMeta(id).$1,
        icon: _cardMeta(id).$2,
        detail: MiliLocale.t('نسخه و بروزرسانی', 'Version & updates'),
        onTap: () => _openPage(const AboutPage()),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  int _activeRules(AppState state) {
    final routing = state.profile.routing;
    return routing.bypass.presets.values.where((v) => v).length +
        routing.sanctionBypass.presets.values.where((v) => v).length +
        routing.block.presets.values.where((v) => v).length;
  }

  void _openPage(Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _showCardsSheet(BuildContext context, AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DashboardCardsSheet(state: state),
    );
  }
}

class _DashboardHeading extends StatelessWidget {
  final bool editMode;
  final bool connected;
  final VoidCallback onEdit;

  const _DashboardHeading({
    required this.editMode,
    required this.connected,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 2, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      editMode
                          ? MiliLocale.t('ویرایش چیدمان', 'Edit layout')
                          : MiliLocale.t('داشبورد', 'Dashboard'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    BentoTag(
                      connected
                          ? MiliLocale.t('زنده', 'Live')
                          : MiliLocale.t('آفلاین', 'Offline'),
                      icon: Symbols.circle,
                      filled: connected,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  editMode
                      ? MiliLocale.t(
                          'کارت‌ها را بکشید، اندازه را عوض کنید یا پنهان کنید',
                          'Drag cards, resize them or hide them',
                        )
                      : MiliLocale.t(
                          'ابزارهای واقعی، یک لمس با شما فاصله دارند',
                          'Real tools, one tap away',
                        ),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (editMode)
            FilledButton.tonalIcon(
              onPressed: onEdit,
              icon: const Icon(Symbols.check_rounded, size: 17),
              label: Text(MiliLocale.t('ذخیره', 'Save')),
            )
          else
            Material(
              color: scheme.primaryContainer.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: IconButton(
                tooltip: MiliLocale.t('ویرایش داشبورد', 'Edit dashboard'),
                onPressed: onEdit,
                icon: Icon(
                  Symbols.dashboard_customize_rounded,
                  size: 21,
                  color: scheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditToolbar extends StatelessWidget {
  final VoidCallback? onAdd;
  final VoidCallback onReset;
  final VoidCallback onDone;

  const _EditToolbar({
    required this.onAdd,
    required this.onReset,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          BentoIcon(
            Symbols.vibration_rounded,
            box: 34,
            size: 17,
            color: scheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              MiliLocale.t(
                'برای جابه‌جایی، کارت را نگه دارید',
                'Hold a card to move it',
              ),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: MiliLocale.t('افزودن یا حذف کارت', 'Add or remove cards'),
            onPressed: onAdd,
            icon: const Icon(Symbols.add_card_rounded, size: 20),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: MiliLocale.t('بازنشانی چیدمان', 'Reset layout'),
            onPressed: onReset,
            icon: const Icon(Symbols.restart_alt_rounded, size: 20),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: MiliLocale.t('پایان ویرایش', 'Finish editing'),
            onPressed: onDone,
            icon: const Icon(Symbols.check_circle_rounded, size: 21),
          ),
        ],
      ),
    );
  }
}

class _BentoEditSlot extends StatelessWidget {
  final String id;
  final double width;
  final bool editing;
  final bool animate;
  final ValueChanged<String> onMove;
  final VoidCallback onResize;
  final VoidCallback onHide;
  final Widget child;

  const _BentoEditSlot({
    super.key,
    required this.id,
    required this.width,
    required this.editing,
    required this.animate,
    required this.onMove,
    required this.onResize,
    required this.onHide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return SizedBox(
        width: width,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1),
          duration: animate
              ? const Duration(milliseconds: 280)
              : Duration.zero,
          curve: Curves.easeOutBack,
          builder: (context, value, child) =>
              Transform.scale(scale: value, child: child),
          child: child,
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != id,
        onAcceptWithDetails: (details) => onMove(details.data),
        builder: (context, candidates, rejected) {
          final hovering = candidates.isNotEmpty;
          return LongPressDraggable<String>(
            data: id,
            hapticFeedbackOnStart: true,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                child: Opacity(opacity: 0.94, child: child),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.22, child: child),
            child: _Wiggle(
              animate: animate,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kBentoRadius + 2),
                  border: Border.all(
                    color: hovering
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.30),
                    width: hovering ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    AbsorbPointer(child: child),
                    PositionedDirectional(
                      top: 5,
                      start: 5,
                      child: Material(
                        color: scheme.surfaceContainerHigh.withValues(
                          alpha: 0.94,
                        ),
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: MiliLocale.t('پنهان کردن کارت', 'Hide card'),
                          onPressed: onHide,
                          icon: Icon(
                            Symbols.visibility_off_rounded,
                            size: 17,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 5,
                      end: 5,
                      child: Material(
                        color: scheme.primaryContainer.withValues(alpha: 0.96),
                        shape: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Symbols.drag_indicator_rounded,
                            size: 19,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 7,
                      end: 7,
                      child: Material(
                        color: scheme.surfaceContainerHigh.withValues(
                          alpha: 0.96,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onResize,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Symbols.aspect_ratio_rounded,
                                  size: 15,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  MiliLocale.t('اندازه', 'Resize'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Wiggle extends StatefulWidget {
  final Widget child;
  final bool animate;
  const _Wiggle({required this.child, required this.animate});

  @override
  State<_Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<_Wiggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Wiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: math.sin(_controller.value * math.pi * 2) * 0.0028,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _HiddenCardSlot extends StatelessWidget {
  final String id;
  final VoidCallback onAdd;

  const _HiddenCardSlot({required this.id, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = _cardMeta(id);
    return SizedBox(
      height: 122,
      child: InkWell(
        borderRadius: BorderRadius.circular(kBentoRadius),
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kBentoRadius),
            border: Border.all(
              color: scheme.outlineVariant,
              width: 1,
            ),
            color: scheme.surfaceContainerLow.withValues(alpha: 0.45),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(meta.$2, size: 25, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                meta.$1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.add_rounded, size: 14, color: scheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    MiliLocale.t('افزودن', 'Add'),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(String, IconData) _cardMeta(String id) => switch (id) {
  'connection' => (
    MiliLocale.t('هسته و اتصال', 'Core & connection'),
    Symbols.power_settings_new_rounded,
  ),
  'speed' => (
    MiliLocale.t('سرعت شبکه', 'Network speed'),
    Symbols.speed_rounded,
  ),
  'quota' => (
    MiliLocale.t('سهمیه ورکر', 'Worker quota'),
    Symbols.cloud_done_rounded,
  ),
  'network' => (
    MiliLocale.t('آی‌پی و DNS', 'IP & DNS'),
    Symbols.public_rounded,
  ),
  'quick' => (
    MiliLocale.t('تنظیمات سریع', 'Quick settings'),
    Symbols.bolt_rounded,
  ),
  'toolbox' => (
    MiliLocale.t('جعبه‌ابزار', 'Toolbox'),
    Symbols.construction_rounded,
  ),
  'engine' => (
    MiliLocale.t('هسته اتصال', 'Connection engine'),
    Symbols.memory_rounded,
  ),
  'cleanIps' => (
    MiliLocale.t('کلین آی‌پی', 'Clean IPs'),
    Symbols.verified_rounded,
  ),
  'proxyIps' => (
    MiliLocale.t('پروکسی آی‌پی', 'Proxy IPs'),
    Symbols.router_rounded,
  ),
  'placement' => (
    MiliLocale.t('پلیسمنت ورکر', 'Worker placement'),
    Symbols.public_rounded,
  ),
  'dns' => (MiliLocale.t('سرورهای DNS', 'DNS servers'), Symbols.dns_rounded),
  'routing' => (
    MiliLocale.t('مسیریابی و قوانین', 'Routing & rules'),
    Symbols.alt_route_rounded,
  ),
  'fragments' => (
    MiliLocale.t('فرگمنت TCP', 'TCP fragments'),
    Symbols.view_week_rounded,
  ),
  'noises' => (
    MiliLocale.t('مبهم‌سازی UDP', 'UDP obfuscation'),
    Symbols.graphic_eq_rounded,
  ),
  'perApp' => (
    MiliLocale.t('پروکسی هر برنامه', 'Per-app proxy'),
    Symbols.apps_rounded,
  ),
  'chains' => (
    MiliLocale.t('زنجیره پروکسی', 'Chain proxies'),
    Symbols.link_rounded,
  ),
  'cloudflare' => (
    MiliLocale.t('حساب‌های کلادفلر', 'Cloudflare accounts'),
    Symbols.cloud_rounded,
  ),
  'tor' => (MiliLocale.t('پل تور', 'Tor bridges'), Symbols.travel_explore_rounded),
  'appearance' => (
    MiliLocale.t('ظاهر و تم', 'Appearance'),
    Symbols.palette_rounded,
  ),
  'scanner' => (
    MiliLocale.t('اسکنر شبکه', 'Network scanner'),
    Symbols.radar_rounded,
  ),
  'logs' => (MiliLocale.t('لاگ زنده', 'Live logs'), Symbols.terminal_rounded),
  'config' => (
    MiliLocale.t('کانفیگ Xray', 'Xray config'),
    Symbols.data_object_rounded,
  ),
  'about' => (
    MiliLocale.t('درباره و بروزرسانی', 'About & updates'),
    Symbols.info_rounded,
  ),
  _ => (id, Symbols.dashboard_rounded),
};

class _DashboardCardFrame extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accent;
  final bool highlight;
  final VoidCallback? onTap;
  final Widget child;
  final Widget? action;

  const _DashboardCardFrame({
    required this.title,
    required this.icon,
    required this.child,
    this.accent,
    this.highlight = false,
    this.onTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoSurface(
      onTap: onTap,
      highlight: highlight,
      accent: accent,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: highlight ? (accent ?? scheme.primary) : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

/// A compact data card for settings whose value is worth seeing on the board.
class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final String detail;
  final VoidCallback onTap;
  final bool wide;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.detail,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _DashboardCardFrame(
      title: title,
      icon: icon,
      onTap: onTap,
      action: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Symbols.chevron_left_rounded
            : Symbols.chevron_right_rounded,
        size: 17,
        color: scheme.onSurfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: wide ? 20 : 17,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact one-tap destination card for pages that have no headline value.
class _ShortcutCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String detail;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.title,
    required this.icon,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _DashboardCardFrame(
      title: title,
      icon: icon,
      onTap: onTap,
      action: Icon(
        Symbols.arrow_outward_rounded,
        size: 16,
        color: scheme.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            MiliLocale.t('باز کردن', 'Open'),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final AppState state;
  final bool compact;
  final String Function(ConnectionMode) modeName;
  final String Function(String) protocolLabel;
  final String Function(AppState) exitLabel;
  final VoidCallback onManageNodes;

  const _ConnectionCard({
    required this.state,
    required this.compact,
    required this.modeName,
    required this.protocolLabel,
    required this.exitLabel,
    required this.onManageNodes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = state.isConnected;
    final busy = state.isBusy;
    final elapsed = state.connectedAt == null
        ? MiliLocale.t('آماده اتصال', 'Ready to connect')
        : formatDuration(DateTime.now().difference(state.connectedAt!));
    final mode = state.isMihomo
        ? 'Mihomo · ${state.mihomoSubscriptions.length} ${MiliLocale.t('اشتراک', 'subs')}'
        : state.mode == ConnectionMode.worker
        ? '${modeName(state.mode)} · ${protocolLabel(state.device.workerProtocol)}'
        : modeName(state.mode);
    void openEngine() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EngineSettingsPage()),
    );

    return BentoSurface(
      highlight: connected,
      accent: connected ? scheme.primary : null,
      onTap: state.isMihomo
          ? openEngine
          : () => openCoreStatusSheet(
              context,
              onManageNodes: onManageNodes,
            ),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoIcon(
                connected
                    ? Symbols.verified_user_rounded
                    : Symbols.shield_rounded,
                filled: connected,
                box: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isMihomo
                          ? MiliLocale.t('هسته Mihomo', 'Mihomo core')
                          : MiliLocale.t('هسته و اتصال', 'Core & connection'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      connected
                          ? MiliLocale.t('محافظت فعال', 'Protection on')
                          : (state.status == VpnStatus.connecting
                                ? MiliLocale.t('در حال اتصال…', 'Connecting…')
                                : MiliLocale.t('آماده', 'Ready')),
                      style: TextStyle(
                        fontSize: 10,
                        color: connected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: MiliLocale.t('وضعیت هسته', 'Core status'),
                onPressed: state.isMihomo
                    ? openEngine
                    : () => openCoreStatusSheet(
                        context,
                        onManageNodes: onManageNodes,
                      ),
                icon: const Icon(Symbols.memory_rounded, size: 21),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (state.status) {
                        VpnStatus.connected => MiliLocale.t('متصل', 'Connected'),
                        VpnStatus.connecting => MiliLocale.t(
                          'در حال اتصال',
                          'Connecting',
                        ),
                        VpnStatus.disconnecting => MiliLocale.t(
                          'در حال قطع',
                          'Disconnecting',
                        ),
                        VpnStatus.disconnected => state.error != null
                            ? MiliLocale.t('خطا', 'Failed')
                            : MiliLocale.t('متوقف', 'Stopped'),
                      },
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: compact ? 23 : 29,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: connected
                            ? scheme.primary
                            : (state.error != null
                                  ? scheme.error
                                  : scheme.onSurface),
                      ),
                    ),
                    Text(
                      connected
                          ? elapsed
                          : (state.error ??
                                MiliLocale.t(
                                  'برای اتصال، دکمه پخش را لمس کنید',
                                  'Tap play to start your tunnel',
                                )),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: state.error != null
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  state.toggle();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  width: compact ? 56 : 66,
                  height: compact ? 50 : 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: connected
                          ? [
                              scheme.primary,
                              Color.alphaBlend(
                                scheme.tertiary.withValues(alpha: 0.60),
                                scheme.primary,
                              ),
                            ]
                          : [
                              scheme.primary.withValues(alpha: 0.22),
                              scheme.primary.withValues(alpha: 0.10),
                            ],
                    ),
                    border: Border.all(
                      color: scheme.primary.withValues(
                        alpha: connected ? 0.6 : 0.30,
                      ),
                    ),
                    boxShadow: connected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.28),
                              blurRadius: 22,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: connected
                                  ? scheme.onPrimary
                                  : scheme.primary,
                            ),
                          )
                        : Icon(
                            connected
                                ? Symbols.stop_rounded
                                : Symbols.play_arrow_rounded,
                            size: compact ? 29 : 34,
                            color: connected
                                ? scheme.onPrimary
                                : scheme.primary,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: state.isMihomo ? openEngine : onManageNodes,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
                child: Row(
                  children: [
                    Icon(
                      Symbols.hub_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isMihomo
                                ? MiliLocale.t('اشتراک‌های Mihomo', 'Mihomo subscriptions')
                                : exitLabel(state),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            state.isMihomo
                                ? mode
                                : '$mode · ${state.pingMs == null ? MiliLocale.t('پینگ نشده', 'Not tested') : '${state.pingMs} ms'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BentoTag(
                      state.isMihomo
                          ? MiliLocale.t('مدیریت', 'Manage')
                          : MiliLocale.t('تغییر نود', 'Change node'),
                      icon: Symbols.expand_more_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                BettboxChip(
                  icon: Symbols.vpn_lock_rounded,
                  label: state.device.appMode == AppMode.vpn
                      ? 'VPN'
                      : MiliLocale.t('پروکسی', 'Proxy'),
                  active: state.device.appMode == AppMode.vpn,
                  onTap: state.isBusy
                      ? null
                      : () => state.setAppMode(
                            state.device.appMode == AppMode.vpn
                                ? AppMode.proxy
                                : AppMode.vpn,
                          ),
                ),
                BettboxChip(
                  icon: Symbols.exit_to_app_rounded,
                  label: exitLabel(state),
                  onTap: onManageNodes,
                ),
                BettboxChip(
                  icon: Symbols.network_ping_rounded,
                  label: state.pinging
                      ? '…'
                      : (state.pingMs == null
                            ? MiliLocale.t('تست پینگ', 'Test ping')
                            : '${state.pingMs} ms'),
                  active: state.pingMs != null && (state.pingMs ?? -1) > 0,
                  onTap: state.isConnected ? state.testPing : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  final AppState state;
  final bool compact;
  final List<double> history;
  final int revision;

  const _SpeedCard({
    required this.state,
    required this.compact,
    required this.history,
    required this.revision,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _DashboardCardFrame(
      title: MiliLocale.t('سرعت شبکه', 'Network speed'),
      icon: Symbols.speed_rounded,
      onTap: () => openSpeedTestSheet(context),
      action: Icon(
        Symbols.open_in_new_rounded,
        size: 15,
        color: scheme.onSurfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.arrow_downward_rounded,
                size: compact ? 15 : 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '${formatBytes(state.downSpeed)}/s',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 18 : 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Symbols.arrow_upward_rounded,
                size: 14,
                color: scheme.tertiary,
              ),
              const SizedBox(width: 2),
              Text(
                formatBytes(state.upSpeed),
                style: TextStyle(
                  fontSize: compact ? 9.5 : 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 11),
          BettboxLineChart(
            values: List<double>.of(history),
            revision: revision,
            color: state.isConnected ? scheme.primary : scheme.tertiary,
            height: compact ? 34 : 54,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              BentoTag(
                state.isConnected
                    ? MiliLocale.t('تونل فعال', 'Tunnel live')
                    : MiliLocale.t('اتصال غیرفعال', 'Tunnel off'),
                icon: Symbols.circle,
                filled: state.isConnected,
              ),
              const Spacer(),
              Text(
                MiliLocale.t('تست کامل', 'Full test'),
                style: TextStyle(
                  fontSize: 9.5,
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  final AppState state;
  final bool compact;
  const _QuotaCard({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usage = state.usage;
    final total = usage?.total ?? 0;
    final ratio = (total / 100000).clamp(0.0, 1.0).toDouble();
    return _DashboardCardFrame(
      title: MiliLocale.t('سهمیه ورکر · ۲۴ ساعت', 'Worker quota · 24h'),
      icon: Symbols.cloud_done_rounded,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CfAccountsPage()),
      ),
      action: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: state.loadingUsage ? null : state.refreshUsage,
        icon: state.loadingUsage
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Symbols.refresh_rounded, size: 17),
      ),
      child: usage == null
          ? Text(
              state.usageError ??
                  MiliLocale.t(
                    'برای دریافت آمار، بروزرسانی را لمس کنید',
                    'Tap refresh to load live quota',
                  ),
              style: TextStyle(
                fontSize: 11,
                color: state.usageError != null
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatCount(total),
                      style: TextStyle(
                        fontSize: compact ? 20 : 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 5),
                      Text(
                        '/ ${formatCount(100000)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    BentoTag(
                      '${(ratio * 100).toStringAsFixed(1)}%',
                      color: ratio > 0.85 ? scheme.error : scheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: ratio > 0.85 ? scheme.error : scheme.primary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  MiliLocale.t(
                    'این ورکر: ${formatCount(usage.worker)} درخواست',
                    'This worker: ${formatCount(usage.worker)} requests',
                  ),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  final AppState state;
  final bool compact;
  const _NetworkCard({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ip = state.myIps?.other ?? state.myIps?.cloudflare;
    final countryCode = ip?.country ?? '';
    return _DashboardCardFrame(
      title: MiliLocale.t('آی‌پی و DNS', 'IP & DNS'),
      icon: Symbols.public_rounded,
      onTap: () => openIpDnsSheet(context),
      action: Icon(
        Symbols.open_in_new_rounded,
        size: 15,
        color: scheme.onSurfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                countryCode.isEmpty ? '🌐' : countryFlag(countryCode),
                style: const TextStyle(fontSize: 20),
              ),
              const Spacer(),
              Icon(
                Symbols.network_ping_rounded,
                size: 15,
                color: state.pingMs != null
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                state.pingMs == null ? '—' : '${state.pingMs} ms',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: state.pingMs != null
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ip?.ip ?? MiliLocale.t('برای بررسی لمس کنید', 'Tap to inspect'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 13.5 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            state.isConnected
                ? MiliLocale.t('خروجی تونل · DNS سالم', 'Tunnel exit · DNS check')
                : MiliLocale.t('اتصال مستقیم', 'Direct connection'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final AppState state;
  final bool compact;
  const _QuickCard({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<String>>(
      valueListenable: QuickSettingsStore.selected,
      builder: (context, ids, _) {
        final actions = ids
            .map(QuickSettingsStore.action)
            .whereType<QuickSettingAction>()
            .take(compact ? 3 : 5)
            .toList();
        return _DashboardCardFrame(
          title: MiliLocale.t('تنظیمات سریع', 'Quick settings'),
          icon: Symbols.bolt_rounded,
          action: IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: MiliLocale.t('شخصی‌سازی', 'Customize'),
            onPressed: () => openQuickSettingsSheet(context),
            icon: const Icon(Symbols.tune_rounded, size: 17),
          ),
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                _QuickRow(
                  action: actions[i],
                  state: state,
                  compact: compact,
                ),
                if (i < actions.length - 1)
                  Divider(
                    height: 10,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
              ],
              if (actions.isEmpty)
                Text(
                  MiliLocale.t(
                    'کنترل‌های دلخواه را اضافه کنید',
                    'Add your preferred controls',
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickRow extends StatelessWidget {
  final QuickSettingAction action;
  final AppState state;
  final bool compact;

  const _QuickRow({
    required this.action,
    required this.state,
    required this.compact,
  });

  bool get _value => switch (action.id) {
    'dpi' => state.variant != ConnectionVariant.normal,
    'ipv6' => state.profile.general.enableIpv6,
    'fakedns' => state.readBool('general.enableFakeDns'),
    'mode' => state.device.appMode == AppMode.vpn,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => runQuickSetting(context, action.id, state),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              action.icon,
              size: compact ? 14 : 16,
              color: action.toggle && _value
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                action.localizedTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 9.8 : 10.8,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (action.toggle)
              Container(
                width: 26,
                height: 15,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _value ? scheme.primary : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Align(
                  alignment: _value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _value ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Icon(
                Symbols.chevron_right_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolboxCard extends StatelessWidget {
  final AppState state;
  final bool compact;
  final VoidCallback onOpenScanner;

  const _ToolboxCard({
    required this.state,
    required this.compact,
    required this.onOpenScanner,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final List<(IconData, String, VoidCallback)> tools = [
      (
        Symbols.speed_rounded,
        MiliLocale.t('تست سرعت', 'Speed test'),
        () => openSpeedTestSheet(context),
      ),
      (
        Symbols.public_rounded,
        MiliLocale.t('آی‌پی و DNS', 'IP & DNS'),
        () => openIpDnsSheet(context),
      ),
      (
        Symbols.memory_rounded,
        MiliLocale.t('وضعیت هسته', 'Core status'),
        () => openCoreStatusSheet(context),
      ),
      (
        Symbols.radar_rounded,
        MiliLocale.t('اسکنر', 'Scanner'),
        onOpenScanner,
      ),
    ];
    return _DashboardCardFrame(
      title: MiliLocale.t('جعبه‌ابزار', 'Toolbox'),
      icon: Symbols.construction_rounded,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MiliToolboxPage()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: tools[i].$3,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 5 : 8,
                        vertical: compact ? 9 : 11,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh.withValues(
                          alpha: 0.54,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            tools[i].$1,
                            size: compact ? 17 : 20,
                            color: i == 0 ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tools[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 8.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (i < tools.length - 1) const SizedBox(width: 7),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              BentoTag(
                state.isConnected
                    ? MiliLocale.t('اتصال سالم', 'Link healthy')
                    : MiliLocale.t('اتصال قطع', 'Link offline'),
                icon: Symbols.circle,
                filled: state.isConnected,
              ),
              const Spacer(),
              Text(
                MiliLocale.t('همه ابزارها', 'All tools'),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardFooter extends StatelessWidget {
  final bool connected;
  final bool busy;
  final bool failed;
  final VoidCallback onManageNodes;
  final VoidCallback onSettings;

  const _DashboardFooter({
    required this.connected,
    required this.busy,
    required this.failed,
    required this.onManageNodes,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BentoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: failed
                  ? scheme.error
                  : connected
                  ? scheme.primary
                  : scheme.outline,
              boxShadow: connected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              busy
                  ? MiliLocale.t('در حال اعمال تغییرات…', 'Applying changes…')
                  : connected
                  ? MiliLocale.t(
                      'اتصال پایدار · داده زنده',
                      'Stable link · live data',
                    )
                  : MiliLocale.t(
                      'برای شروع اتصال، دکمه قدرت را لمس کنید',
                      'Tap power to start your tunnel',
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.8,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onManageNodes,
            icon: const Icon(Symbols.hub_rounded, size: 16),
            label: Text(MiliLocale.t('نودها', 'Nodes')),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onSettings,
            icon: const Icon(Symbols.settings_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _DashboardCardsSheet extends StatelessWidget {
  final AppState state;
  const _DashboardCardsSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MiliLocale.t('کارت‌های داشبورد', 'Dashboard cards'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              MiliLocale.t(
                'هر تنظیم و ابزار می‌تواند کارت داشبورد شود؛ برای چیدمان، کارت‌ها را در حالت ویرایش بکشید.',
                'Any setting or tool can become a dashboard card; drag cards in edit mode to arrange them.',
              ),
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final id in DeviceSettings.dashboardCardIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: BentoSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      BentoIcon(
                        _cardMeta(id).$2,
                        box: 34,
                        size: 17,
                        color: state.device.dashboardCards.contains(id)
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _cardMeta(id).$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Switch(
                        value: state.device.dashboardCards.contains(id),
                        onChanged: (on) {
                          final next = List<String>.of(
                            state.device.dashboardCards,
                          );
                          if (on) {
                            if (!next.contains(id)) next.add(id);
                          } else {
                            next.remove(id);
                          }
                          state.write('device.dashboard.cards', next);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  state.write(
                    'device.dashboard.cards',
                    DeviceSettings.defaultDashboardCards,
                  );
                  state.write(
                    'device.dashboard.sizes',
                    DeviceSettings.defaultDashboardSizes,
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Symbols.restart_alt_rounded, size: 18),
                label: Text(
                  MiliLocale.t('بازگردانی چیدمان پیش‌فرض', 'Restore default layout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
