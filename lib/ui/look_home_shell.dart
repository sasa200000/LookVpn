import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/cf_account.dart';
import '../models/settings.dart';
import '../services/chain_proxy.dart';
import '../services/look_ip_pool.dart';
import '../services/look_live_scanner.dart';
import '../services/look_panel_client.dart';
import '../services/my_ip.dart';
import '../services/scanner_channel.dart';
import '../services/vpn_channel.dart';
import '../services/xray_config.dart';
import '../state/app_state.dart';
import 'bettbox_widgets.dart';
import 'cf_accounts_page.dart';
import 'chain_proxies_page.dart';
import 'cloudflare_scanner_page.dart';
import 'dashboard_page.dart';
import 'dashboard_tools.dart';
import 'expressive.dart';
import 'format.dart';
import 'log_page.dart';
import 'look_settings_tab.dart';
import 'look_i18n.dart';
import 'look_light_dance.dart';
import 'look_logo.dart';
import 'look_toolbox_page.dart';
import 'region_picker.dart';
import 'scanner_page.dart';
import 'theme.dart';
import 'update_sheet.dart';

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// Psiphon and Tor use one shared exit location; changing it asks for a reconnect.
Future<void> _pickExitRegion(BuildContext context, AppState state) async {
  final picked = await showExitRegionPicker(
    context,
    selected: state.device.exitRegion,
  );
  if (picked != null) state.setExitRegion(picked);
}

/// Node selection, protocols, ping testing and the subscription importer are
/// no longer a separate tab: they open from the dashboard's main core card.
Future<void> _showNodeManager(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.52),
  builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Material(
          color: scheme.surface,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        Symbols.hub_rounded,
                        color: scheme.primary,
                        fill: 1,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LookLocale.t('هسته و اتصال', 'Core & connection'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            LookLocale.t(
                              'انتخاب، تست پینگ و مدیریت نودها',
                              'Select, ping-test and manage nodes',
                            ),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _BettboxNodesTab(
                  embedded: true,
                  scrollController: controller,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

/// LookVPN v2.0.0 — Full Bettbox Architecture:
/// 1) Dashboard: StartButton Hero, Live non-freezing Bezier Speed Chart,
///    Daily Cloudflare Worker Requests Quota, Network Detection, Traffic Usage, Quick Options
/// 2) Nodes (Proxies): Bettbox-style 2-column grid for Worker Deployments,
///    Protocols (VLESS WS / XHTTP / Trojan / SS), Built-in Cores (WARP/MASQUE/Psiphon/Tor),
///    Chain Proxies, and Panel Sync
/// 3) Scanner: live TCP probing, Clean IP/Proxy actions and deep tunnel scans.
/// 4) Settings: the expressive central settings directory.
/// Nodes live inside the Core & Connection card instead of a separate tab.
class LookHomeShell extends StatefulWidget {
  const LookHomeShell({super.key});

  @override
  State<LookHomeShell> createState() => _LookHomeShellState();
}

class _LookHomeShellState extends State<LookHomeShell>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // One ticker for the whole app: every dancing ring, metre and wave chart reads
    // its clock, so they stay in step and cost a single frame callback.
    LookLightDance.instance.attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      LookLightDance.instance
        ..setActive(state.lightDance)
        ..syncFromTheme(state.themeColor.value);
      unawaited(state.checkForUpdate(silent: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) => Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          toolbarHeight: kLookHomeHeaderHeight,
          // Keep the header completely transparent: no background, scrim or
          // gradient. Only the title and actions float over the page.
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarIconBrightness: isLight
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarIconBrightness: isLight
                ? Brightness.dark
                : Brightness.light,
          ),
          titleSpacing: 16,
          title: Row(
            children: [
              const LookLogo(size: 26),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  'LookVPN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (AppScope.of(context).availableUpdate != null)
              IconButton(
                tooltip: LookLocale.t('بروزرسانی آماده است', 'Update available'),
                icon: Badge(
                  backgroundColor: scheme.primary,
                  child: Icon(Symbols.system_update_rounded, size: 21),
                ),
                onPressed: () => showUpdateSheet(
                  context,
                  AppScope.of(context).availableUpdate!,
                ),
              ),
            const SizedBox(width: 6),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final state = AppScope.of(context);
            final width = constraints.maxWidth > 920
                ? 920.0
                : constraints.maxWidth;
            final topInset = lookHomeTopInset(context);
            final tabTransition = state.tabTransition.value;
            final tabDuration = !state.motionEnabled.value
                ? Duration.zero
                : switch (tabTransition) {
                    'fade' => const Duration(milliseconds: 220),
                    'scale' => const Duration(milliseconds: 300),
                    'lift' => const Duration(milliseconds: 360),
                    _ => const Duration(milliseconds: 320),
                  };
            return Stack(
              children: [
                Positioned.fill(
                  child: state.meshBackground.value
                      ? BentoBackground(
                          accent: scheme.primary,
                          secondary: scheme.secondary,
                          tertiary: scheme.tertiary,
                          connected: state.isConnected,
                          busy: state.isBusy,
                          failed:
                              state.status == VpnStatus.disconnected &&
                              state.error != null,
                          isLight: isLight,
                        )
                      : ColoredBox(color: scheme.surface),
                ),
                // The header itself is fully transparent. The page is taller
                // than its old clipped viewport and its top edge is masked with
                // a soft alpha fade, so scrolling cards dissolve under the
                // header instead of ending on a straight horizontal cut.
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: width,
                      height: constraints.maxHeight,
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) {
                          final height = rect.height;
                          final fadeStart = ((topInset - 22) / height)
                              .clamp(0.0, 1.0)
                              .toDouble();
                          final fadeEnd = ((topInset + 8) / height)
                              .clamp(0.0, 1.0)
                              .toDouble();
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                            ],
                            stops: [0.0, fadeStart, fadeEnd, 1.0],
                          ).createShader(rect);
                        },
                        child: AnimatedSwitcher(
                          duration: tabDuration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            final curved = CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                              reverseCurve: Curves.easeInCubic,
                            );
                            final faded = FadeTransition(
                              opacity: curved,
                              child: child,
                            );
                            return switch (tabTransition) {
                              'fade' => faded,
                              'scale' => ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.94,
                                  end: 1,
                                ).animate(curved),
                                child: faded,
                              ),
                              'lift' => SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.045),
                                  end: Offset.zero,
                                ).animate(curved),
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.985,
                                    end: 1,
                                  ).animate(curved),
                                  child: faded,
                                ),
                              ),
                              _ => SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.045, 0),
                                  end: Offset.zero,
                                ).animate(curved),
                                child: faded,
                              ),
                            };
                          },
                          child: RepaintBoundary(
                            key: ValueKey(_tab),
                            child: switch (_tab) {
                              0 => ExpressiveDashboardTab(
                                onOpenScanner: () => setState(() => _tab = 1),
                                onOpenSettings: () => setState(() => _tab = 2),
                                onManageNodes: () => _showNodeManager(context),
                              ),
                              1 => const ExpressiveScannerTab(),
                              _ => LookSettingsTab(
                                onOpenScanner: () => setState(() => _tab = 1),
                              ),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 86,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.surface.withValues(alpha: 0),
                            scheme.surface.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: BettboxFloatingNavBar(
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
          items: [
            (
              icon: Symbols.space_dashboard_rounded,
              label: LookLocale.t('داشبورد', 'Dashboard'),
            ),
            (
              icon: Symbols.radar_rounded,
              label: LookLocale.t('اسکنر', 'Scanner'),
            ),
            (
              icon: Symbols.tune_rounded,
              label: LookLocale.t('تنظیمات', 'Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: Bettbox Dashboard (StartButton, Live Chart, Daily Worker Requests,
// Network Detection, Traffic Usage, Quick Options)
// ---------------------------------------------------------------------------

class _BettboxDashboardTab extends StatefulWidget {
  final ValueChanged<int> onJumpTab;
  const _BettboxDashboardTab({required this.onJumpTab});

  @override
  State<_BettboxDashboardTab> createState() => _BettboxDashboardTabState();
}

class _BettboxDashboardTabState extends State<_BettboxDashboardTab> {
  static const _dailyLimit = 100000;
  Timer? _ticker;
  final List<double> _speedHistory = List<double>.filled(24, 0, growable: true);
  int _chartRev = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      final totalSpeed = (state.downSpeed + state.upSpeed).toDouble();
      _speedHistory.add(totalSpeed);
      if (_speedHistory.length > 24) _speedHistory.removeAt(0);
      _chartRev++;
      if (state.isConnected ||
          totalSpeed > 0 ||
          _speedHistory.any((v) => v > 0)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _modeName(ConnectionMode m) => switch (m) {
    ConnectionMode.worker => LookLocale.t('ورکر', 'Worker'),
    ConnectionMode.warp => 'WARP',
    ConnectionMode.masque => 'MASQUE',
    ConnectionMode.serverless => LookLocale.t('سرورلس', 'Serverless'),
    ConnectionMode.psiphon => LookLocale.t('سایفون', 'Psiphon'),
    ConnectionMode.tor => LookLocale.t('تور', 'Tor'),
    ConnectionMode.node => LookLocale.t('نود مستقیم', 'Direct Node'),
  };

  String _workerProtoLabel(String p) => switch (p) {
    'vless_xhttp' => 'XHTTP',
    'trojan_ws' => 'Trojan',
    'shadowsocks_ws' => 'SS',
    _ => 'VLESS',
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final connected = state.isConnected;
    final busy = state.isBusy;
    final failed = state.status == VpnStatus.disconnected && state.error != null;

    final elapsed = state.connectedAt == null
        ? '00:00:00'
        : formatDuration(DateTime.now().difference(state.connectedAt!));
    final myIp = state.myIps?.other ?? state.myIps?.cloudflare;
    final usage = state.usage;
    final cards = state.device.dashboardCards;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 102),
      children: [
        const UpdateBanner(),
        if (state.needsReconnect)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BettboxTileCard(
              title: LookLocale.t('تغییر تنظیمات', 'Settings Changed'),
              icon: Symbols.sync_rounded,
              borderColor: scheme.primary,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      LookLocale.t(
                        'برای اعمال تغییرات، دوباره متصل شوید.',
                        'Reconnect to apply your updated settings.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: state.reconnect,
                    child: Text(LookLocale.t('اعمال', 'Apply')),
                  ),
                ],
              ),
            ),
          ),

        // 1. Bettbox StartButton Hero Tile
        if (cards.contains('connection'))
          BettboxTileCard(
          title: LookLocale.t('وضعیت هسته و اتصال', 'Core & Connection'),
          icon: Symbols.power_settings_new_rounded,
          watermarkIcon: connected ? Symbols.verified_user_rounded : Symbols.shield_rounded,
          borderColor: connected
              ? scheme.primary.withValues(alpha: 0.6)
              : (failed ? scheme.error.withValues(alpha: 0.6) : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (state.status) {
                            VpnStatus.connected => LookLocale.t('متصل', 'Running'),
                            VpnStatus.connecting => LookLocale.t('در حال اتصال…', 'Starting…'),
                            VpnStatus.disconnecting => LookLocale.t('در حال قطع…', 'Stopping…'),
                            VpnStatus.disconnected when failed => LookLocale.t('خطا در اتصال', 'Failed'),
                            VpnStatus.disconnected => LookLocale.t('متوقف', 'Stopped'),
                          },
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: connected
                                ? scheme.primary
                                : (failed ? scheme.error : scheme.onSurface),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          connected
                              ? elapsed
                              : (failed && state.error != null
                                    ? state.error!
                                    : (state.exitDetail ??
                                          LookLocale.t(
                                            'برای شروع اتصال دکمه را لمس کنید',
                                            'Tap button to start tunnel',
                                          ))),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _tabular.copyWith(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      state.toggle();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: connected ? scheme.primary : scheme.primary,
                      ),
                      child: Center(
                        child: busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : Icon(
                                connected
                                    ? Symbols.stop_rounded
                                    : Symbols.play_arrow_rounded,
                                size: 30,
                                color: scheme.onPrimary,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BettboxChip(
                    icon: Symbols.alt_route_rounded,
                    label: state.mode == ConnectionMode.worker
                        ? '${_modeName(state.mode)} · ${_workerProtoLabel(state.device.workerProtocol)}'
                        : _modeName(state.mode),
                    active: true,
                    onTap: () => widget.onJumpTab(1),
                  ),
                  BettboxChip(
                    icon: Symbols.vpn_lock_rounded,
                    label: state.device.appMode == AppMode.proxy
                        ? LookLocale.t('پروکسی', 'Proxy')
                        : 'VPN',
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
                    label: '${LookLocale.t("خروجی", "Exit")}: ${state.exitNode.name}',
                    onTap: state.isBusy
                        ? null
                        : () {
                            final nodes = [
                              ExitNode.worker,
                              if (state.usableChains.isNotEmpty) ExitNode.chain,
                              ExitNode.psiphon,
                              ExitNode.tor,
                            ];
                            final idx = (nodes.indexOf(state.exitNode) + 1) % nodes.length;
                            state.setExitNode(nodes[idx]);
                          },
                  ),
                  if (state.exitNode == ExitNode.psiphon ||
                      state.exitNode == ExitNode.tor)
                    BettboxChip(
                      icon: Symbols.location_on_rounded,
                      label:
                          '${LookLocale.t("لوکیشن", "Location")}: ${exitRegionLabel(state.device.exitRegion)}',
                      active: true,
                      onTap: state.isBusy
                          ? null
                          : () => _pickExitRegion(context, state),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. Live Non-Freezing Network Speed Card
        if (cards.contains('speed'))
          BettboxTileCard(
          title: LookLocale.t('سرعت شبکه', 'Network Speed'),
          icon: Symbols.speed_rounded,
          watermarkIcon: Symbols.speed_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Symbols.arrow_downward_rounded, size: 17, color: scheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${formatBytes(state.downSpeed)}/s',
                    style: _tabular.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(Symbols.arrow_upward_rounded, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    '${formatBytes(state.upSpeed)}/s',
                    style: _tabular.copyWith(
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BettboxLineChart(
                values: List<double>.of(_speedHistory),
                revision: _chartRev,
                color: connected ? scheme.primary : scheme.primary,
                height: 56,
              ),
            ],
          ),
        ),

        // 3. Daily Worker Requests Quota Card (restored!)
        if (state.worker != null && cards.contains('quota')) ...[
          const SizedBox(height: 12),
          BettboxTileCard(
            title: LookLocale.t(
              'سهمیه درخواست روزانه ورکر (۲۴ ساعت)',
              'Worker Daily Requests (24h)',
            ),
            icon: Symbols.cloud_done_rounded,
            watermarkIcon: Symbols.bar_chart_rounded,
            actions: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: state.loadingUsage
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.refresh_rounded, size: 18),
                onPressed: state.loadingUsage ? null : state.refreshUsage,
              ),
            ],
            child: usage != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            formatCount(usage.total),
                            style: _tabular.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ' / ${formatCount(_dailyLimit)}',
                            style: _tabular.copyWith(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            LookLocale.t(
                              'باقی‌مانده: ${formatCount((_dailyLimit - usage.total).clamp(0, _dailyLimit))}',
                              'Left: ${formatCount((_dailyLimit - usage.total).clamp(0, _dailyLimit))}',
                            ),
                            style: _tabular.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: usage.total > 85000
                                  ? scheme.error
                                  : scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: (usage.total / _dailyLimit).clamp(0.0, 1.0),
                          backgroundColor: scheme.surfaceContainerHigh,
                          color: usage.total > 85000 ? scheme.error : scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        LookLocale.t(
                          'این ورکر: ${formatCount(usage.worker)} درخواست',
                          'This worker: ${formatCount(usage.worker)} requests',
                        ),
                        style: _tabular.copyWith(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Text(
                    state.usageError ??
                        (state.loadingUsage
                            ? LookLocale.t('در حال دریافت آمار…', 'Loading usage…')
                            : LookLocale.t(
                                'برای مشاهده سهمیه روزانه دکمه بروزرسانی را بزنید',
                                'Tap refresh to fetch 24h Cloudflare request quota',
                              )),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: state.usageError != null
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ],

        const SizedBox(height: 12),

        // 4. 2-Column Row: Network Detection + Traffic Usage
        if (cards.contains('network'))
          Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BettboxTileCard(
                title: LookLocale.t('تشخیص شبکه', 'Network'),
                icon: Symbols.language_rounded,
                watermarkEmoji: myIp?.country != null
                    ? countryFlag(myIp!.country!)
                    : null,
                watermarkIcon: myIp?.country == null ? Symbols.public_rounded : null,
                onTap: connected
                    ? () {
                        state.testPing();
                        state.refreshMyIps();
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.pinging
                          ? '…'
                          : (state.pingMs != null
                                ? '${state.pingMs} ms'
                                : LookLocale.t('تست پینگ', 'Tap ping')),
                      style: _tabular.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: state.pingMs != null ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      myIp == null
                          ? LookLocale.t('آی‌پی خروج', 'Exit IP')
                          : '${countryFlag(myIp.country ?? '')} ${myIp.ip}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _tabular.copyWith(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BettboxTileCard(
                title: LookLocale.t('مصرف ترافیک', 'Traffic Usage'),
                icon: Symbols.data_usage_rounded,
                watermarkIcon: Symbols.data_usage_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatBytes(state.totalDown + state.totalUp),
                      style: _tabular.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '↓ ${formatBytes(state.totalDown)}  ↑ ${formatBytes(state.totalUp)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _tabular.copyWith(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 5. 2-Column Quick Options
        if (cards.contains('quick'))
          Row(
          children: [
            Expanded(
              child: BettboxTileCard(
                title: LookLocale.t('فرگمنت / مبهم‌سازی', 'Anti-DPI'),
                icon: Symbols.security_rounded,
                contentPadding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.variant != ConnectionVariant.normal
                          ? LookLocale.t('فعال', 'On')
                          : LookLocale.t('عادی', 'Off'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: state.variant != ConnectionVariant.normal
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    Switch(
                      value: state.variant != ConnectionVariant.normal,
                      onChanged: state.isBusy
                          ? null
                          : (on) {
                              if (state.mode == ConnectionMode.warp) {
                                state.setVariant(
                                  on
                                      ? ConnectionVariant.obfuscated
                                      : ConnectionVariant.normal,
                                );
                              } else {
                                state.setVariant(
                                  on
                                      ? ConnectionVariant.fragment
                                      : ConnectionVariant.normal,
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BettboxTileCard(
                title: 'IPv6',
                icon: Symbols.counter_6_rounded,
                contentPadding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.profile.general.enableIpv6
                          ? LookLocale.t('فعال', 'On')
                          : LookLocale.t('خاموش', 'Off'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: state.profile.general.enableIpv6
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    Switch(
                      value: state.profile.general.enableIpv6,
                      onChanged: (v) => state.write('general.enableIpv6', v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 6. Bettbox Toolbox Shortcut Card (Speed Test, Unlock, IP Lookup, Ping, DNS)
        if (cards.contains('toolbox'))
          BettboxTileCard(
          title: LookLocale.t('جعبه‌ابزار شبکه (Bettbox Toolbox)', 'Network Toolbox'),
          icon: Symbols.construction_rounded,
          watermarkIcon: Symbols.construction_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BettboxChip(
                icon: Symbols.speed_rounded,
                label: LookLocale.t('تست سرعت', 'Speed Test'),
                active: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LookToolboxPage(initialTool: 0)),
                ),
              ),
              BettboxChip(
                icon: Symbols.verified_rounded,
                label: LookLocale.t('بازگشایی سرویس', 'Unlock'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LookToolboxPage(initialTool: 1)),
                ),
              ),
              BettboxChip(
                icon: Symbols.public_rounded,
                label: LookLocale.t('بررسی آی‌پی', 'IP Lookup'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LookToolboxPage(initialTool: 2)),
                ),
              ),
              BettboxChip(
                icon: Symbols.network_ping_rounded,
                label: LookLocale.t('پینگ محلی', 'Ping'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LookToolboxPage(initialTool: 3)),
                ),
              ),
              BettboxChip(
                icon: Symbols.dns_rounded,
                label: LookLocale.t('پرس‌وجوی DNS', 'DNS Query'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LookToolboxPage(initialTool: 4)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lets the user hide or restore dashboard cards. The order stays the stable Bento order;
/// the pencil is always available in the dashboard app bar.
class _DashboardCardsSheet extends StatelessWidget {
  const _DashboardCardsSheet();

  static const _items = <(String, String, String, IconData)>[
    ('connection', 'اتصال و هسته', 'Connection', Symbols.power_settings_new_rounded),
    ('speed', 'سرعت شبکه', 'Network speed', Symbols.speed_rounded),
    ('quota', 'سهمیه ورکر', 'Worker quota', Symbols.cloud_done_rounded),
    ('network', 'شبکه و ترافیک', 'Network & traffic', Symbols.language_rounded),
    ('quick', 'گزینه‌های سریع', 'Quick options', Symbols.tune_rounded),
    ('toolbox', 'جعبه‌ابزار', 'Toolbox', Symbols.construction_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LookLocale.code,
      builder: (context, _, __) {
        final state = AppScope.of(context);
        final visible = state.device.dashboardCards;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LookLocale.t('کارت‌های داشبورد', 'Dashboard cards'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LookLocale.t(
                    'کارت‌هایی که نمی‌خواهید را پنهان کنید. هر زمان از همین دکمه مداد برگردانید.',
                    'Hide cards you do not need. Bring them back any time from this pencil.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                for (final (id, fa, en, icon) in _items)
                  SwitchListTile(
                    secondary: Icon(icon),
                    title: Text(LookLocale.t(fa, en)),
                    value: visible.contains(id),
                    onChanged: (on) {
                      final next = [...visible];
                      if (on) {
                        if (!next.contains(id)) next.add(id);
                      } else {
                        next.remove(id);
                      }
                      state.write('device.dashboard.cards', next);
                    },
                  ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => state.write(
                          'device.dashboard.cards',
                          DeviceSettings.defaultDashboardCards,
                        ),
                        icon: const Icon(Symbols.restart_alt_rounded, size: 18),
                        label: Text(LookLocale.t('بازنشانی', 'Reset')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(LookLocale.t('تمام', 'Done')),
                      ),
                    ),
                  ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2: Bettbox-Style Nodes / Proxies Tab (Worker Deployments, Protocols,
// Built-in Cores, Chain Proxies & Panel Sync)
// ---------------------------------------------------------------------------

class _BettboxNodesTab extends StatefulWidget {
  final bool embedded;
  final ScrollController? scrollController;

  const _BettboxNodesTab({
    this.embedded = false,
    this.scrollController,
  });

  @override
  State<_BettboxNodesTab> createState() => _BettboxNodesTabState();
}

class _BettboxNodesTabState extends State<_BettboxNodesTab> {
  final _subUrlCtrl = TextEditingController();
  final _client = LookPanelClient();
  bool _syncing = false;
  String? _syncMsg;

  @override
  void dispose() {
    _subUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final deployments = state.deployments;
    final selectedDep = state.selected;
    final chains = state.profile.chains;

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        widget.embedded ? 4 : 6,
        16,
        widget.embedded ? 28 : 102,
      ),
      children: [
        // 1. Cloudflare Worker & Pages Nodes
        BettboxTileCard(
          title: LookLocale.t('نودهای ورکر کلادفلر', 'Cloudflare Worker Nodes'),
          icon: Symbols.cloud_rounded,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CfAccountsPage()),
              ),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Symbols.add_rounded, size: 16),
              label: Text(LookLocale.t('مدیریت', 'Manage')),
            ),
          ],
          child: deployments.isEmpty
              ? Text(
                  LookLocale.t(
                    'هنوز ورکر کلادفلر نصب نشده است. از دکمه مدیریت برای استقرار استفاده کنید.',
                    'No Cloudflare worker deployed yet. Tap Manage to deploy.',
                  ),
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.95,
                  ),
                  itemCount: deployments.length,
                  itemBuilder: (context, i) {
                    final item = deployments[i];
                    final isSelected = selectedDep != null &&
                        AppState.deploymentKey(selectedDep.account, selectedDep.deployment) ==
                            AppState.deploymentKey(item.account, item.deployment) &&
                        state.mode == ConnectionMode.worker;
                    final isPages = item.deployment.type == WorkerType.pages;
                    return _NodeCard(
                      title: isPages ? 'Pages Node' : 'Worker Node',
                      subtitle: item.deployment.customDomain ?? item.deployment.host,
                      badge: isPages ? 'PAGES' : 'WORKER',
                      selected: isSelected,
                      onTap: () {
                        state.selectDeployment(item.account, item.deployment);
                        state.setMode(ConnectionMode.worker);
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),

        // 2. Worker Protocol Selector Nodes (VLESS WS, VLESS XHTTP, Trojan WS, Shadowsocks WS)
        BettboxTileCard(
          title: LookLocale.t(
            'پروتکل‌های نود ورکر',
            'Worker Protocol Nodes',
          ),
          icon: Symbols.hub_rounded,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              for (final p in const [
                ('vless_ws', 'VLESS · WS', 'WebSocket + TLS'),
                ('vless_xhttp', 'VLESS · XHTTP', 'HTTP/2 Stream'),
                ('trojan_ws', 'Trojan · WS', 'SHA-224 + TLS'),
                ('shadowsocks_ws', 'Shadowsocks', 'SS + WS + TLS'),
              ])
                _NodeCard(
                  title: p.$2,
                  subtitle: p.$3,
                  badge: 'CORE',
                  selected: state.mode == ConnectionMode.worker &&
                      state.device.workerProtocol == p.$1,
                  onTap: () {
                    state.write('device.connection.workerProtocol', p.$1);
                    state.setMode(ConnectionMode.worker);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Built-in Direct Core Nodes (WARP, MASQUE, Serverless, Psiphon, Tor)
        BettboxTileCard(
          title: LookLocale.t('نودهای داخلی بدون نیاز به ورکر', 'Built-in Core Nodes'),
          icon: Symbols.shield_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              for (final m in const [
                (ConnectionMode.warp, 'WARP', 'WireGuard UDP'),
                (ConnectionMode.masque, 'MASQUE', 'HTTP/3 QUIC'),
                (ConnectionMode.serverless, 'Serverless', 'Direct Fragment'),
                (ConnectionMode.psiphon, 'Psiphon', 'Built-in Tunnel'),
                (ConnectionMode.tor, 'Tor', 'Onion Routing'),
              ])
                _NodeCard(
                  title: m.$2,
                  subtitle: m.$3,
                  badge: 'DIRECT',
                  selected: state.mode == m.$1,
                  onTap: () => state.setMode(m.$1),
                ),
            ],
          ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExitPathCard(state: state),
        const SizedBox(height: 12),

        // 4. Standalone node client: one chain proxy as the connection itself, without a worker.
        if (chains.isNotEmpty) ...[
          BettboxTileCard(
            title: LookLocale.t(
              'اتصال مستقیم به نود (کلاینت)',
              'Direct Node (Client)',
            ),
            icon: Symbols.rocket_launch_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LookLocale.t(
                    'یک نود را مثل یک کلاینت معمولی بدون ورکر وصل کنید. انتخاب نود، نوع اتصال را روی Node می‌گذارد.',
                    'Connect one node like a normal client, without a worker. Picking a node switches the connection type to Node.',
                  ),
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: chains.length,
                  itemBuilder: (context, i) {
                    final c = chains[i];
                    return _NodeCard(
                      title: c.name,
                      subtitle: ChainInfo.of(c.link)?.protocol ?? 'Proxy',
                      badge: 'NODE',
                      selected: state.mode == ConnectionMode.node &&
                          state.nodeChain?.id == c.id,
                      onTap: () {
                        state.setNode(c);
                        state.setMode(ConnectionMode.node);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 5. Chain Proxy Nodes + Subscription Import
        BettboxTileCard(
          title: LookLocale.t(
            'نودهای زنجیره‌ای و ساب‌لینک (${chains.length})',
            'Chain Nodes & Subscriptions (${chains.length})',
          ),
          icon: Symbols.link_rounded,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChainProxiesPage()),
              ),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Symbols.add_rounded, size: 16),
              label: Text(LookLocale.t('افزودن', 'Add')),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chains.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: chains.length,
                  itemBuilder: (context, i) {
                    final c = chains[i];
                    final active = state.exitNode == ExitNode.chain &&
                        state.exitChain?.id == c.id;
                    return _NodeCard(
                      title: c.name,
                      subtitle: ChainInfo.of(c.link)?.protocol ?? 'Proxy',
                      badge: 'CHAIN',
                      selected: active,
                      onTap: () {
                        state.setExitChain(c);
                        state.setExitNode(ExitNode.chain);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subUrlCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: LookLocale.t(
                          'لینک ساب‌لینک پنل میلی…',
                          'Paste Look subscription URL…',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _syncing ? null : _importSub,
                    child: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(LookLocale.t('ورود', 'Import')),
                  ),
                ],
              ),
              if (_syncMsg != null) ...[
                const SizedBox(height: 6),
                Text(_syncMsg!, style: TextStyle(fontSize: 12, color: scheme.primary)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _importSub() async {
    setState(() {
      _syncing = true;
      _syncMsg = null;
    });
    try {
      final links = await _client.fetchSubscriptionLinks(_subUrlCtrl.text);
      if (!mounted) return;
      if (links.isNotEmpty) {
        final chains = parseChainProxies(links.join('\n'));
        AppScope.read(context).addChains(chains);
        setState(() => _syncMsg = 'Imported ${chains.length} node(s).');
      } else {
        setState(() => _syncMsg = 'No supported proxy links found.');
      }
    } catch (e) {
      if (mounted) setState(() => _syncMsg = '$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

class _NodeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  const _NodeCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.4 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.22)
                          : scheme.surfaceContainer,
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Symbols.check_circle_rounded, size: 16, color: scheme.primary),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
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

/// Where the current connection leaves the tunnel. Worker, WARP, MASQUE
/// and Serverless can be combined with Psiphon, Tor or a chain proxy; the
/// Psiphon and Tor types are exits themselves and only need a region.
class _ExitPathCard extends StatelessWidget {
  final AppState state;
  const _ExitPathCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = state.mode;
    final exit = state.exitNode;
    final busy = state.isBusy;
    final fixedExit =
        mode == ConnectionMode.psiphon || mode == ConnectionMode.tor;
    final serverlessDns =
        mode == ConnectionMode.serverless &&
        state.serverlessMode == ServerlessMode.dns;
    final choices = switch (mode) {
      ConnectionMode.psiphon || ConnectionMode.tor || ConnectionMode.node =>
        const <ExitNode>[],
      ConnectionMode.serverless => serverlessDns
          ? const <ExitNode>[]
          : [
              ExitNode.worker,
              ExitNode.psiphon,
              if (state.serverlessMode == ServerlessMode.packet) ExitNode.tor,
              if (state.usableChains.isNotEmpty) ExitNode.chain,
            ],
      _ => [
          ExitNode.worker,
          if (state.usableChains.isNotEmpty) ExitNode.chain,
          ExitNode.psiphon,
          ExitNode.tor,
        ],
    };
    final regionExit = exit == ExitNode.psiphon || exit == ExitNode.tor;

    String label(ExitNode node) => switch (node) {
      ExitNode.worker => LookLocale.t('مستقیم', 'Direct'),
      ExitNode.chain => LookLocale.t('زنجیره پروکسی', 'Chain proxy'),
      ExitNode.psiphon => 'Psiphon',
      ExitNode.tor => 'Tor',
    };

    IconData icon(ExitNode node) => switch (node) {
      ExitNode.worker => Symbols.vpn_lock_rounded,
      ExitNode.chain => Symbols.link_rounded,
      ExitNode.psiphon => Symbols.hub_rounded,
      ExitNode.tor => Symbols.travel_explore_rounded,
    };

    return BettboxTileCard(
      title: LookLocale.t('مسیر خروج', 'Exit path'),
      icon: Symbols.alt_route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fixedExit
                ? LookLocale.t(
                    'این نوع اتصال همیشه از ${label(exit)} خارج می‌شود. لوکیشن را جدا انتخاب کنید.',
                    'This connection type always exits through ${label(exit)}. Pick its region below.',
                  )
                : serverlessDns
                ? LookLocale.t(
                    'حالت DNS مستقیم است و مسیر خروج جداگانه ندارد.',
                    'DNS mode is direct and has no separate exit path.',
                  )
                : mode == ConnectionMode.node
                ? LookLocale.t(
                    'در حالت نود، خود نود مقصد نهایی است: ${state.nodeChain?.name ?? '—'}',
                    'In Node mode the node is the final destination: ${state.nodeChain?.name ?? '—'}',
                  )
                : LookLocale.t(
                    'اتصال فعلی را با Psiphon، Tor یا زنجیره پروکسی ترکیب کنید. TCP و UDP تا حد امکان از مسیر انتخاب‌شده عبور می‌کنند.',
                    'Combine the current connection with Psiphon, Tor or a chain proxy. TCP and UDP follow the selected path where supported.',
                  ),
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (choices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final node in choices)
                  BettboxChip(
                    icon: icon(node),
                    label: label(node),
                    active: exit == node,
                    onTap: busy
                        ? null
                        : () => state.setExitNode(node),
                  ),
              ],
            ),
          ],
          if (exit == ExitNode.chain && state.usableChains.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final chain in state.usableChains)
                  BettboxChip(
                    icon: Symbols.link_rounded,
                    label: chain.name,
                    active: state.exitChain?.id == chain.id,
                    onTap: busy ? null : () => state.setExitChain(chain),
                  ),
              ],
            ),
          ],
          if (regionExit) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Symbols.location_on_rounded,
                  size: 17,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    LookLocale.t('لوکیشن خروجی', 'Exit location'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                BettboxChip(
                  icon: Symbols.public_rounded,
                  label: exitRegionLabel(state.device.exitRegion),
                  active: true,
                  onTap: busy ? null : () => _pickExitRegion(context, state),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy scanner implementation (replaced by ExpressiveScannerTab).
// ---------------------------------------------------------------------------

class _LookScannerTab extends StatefulWidget {
  const _LookScannerTab();

  @override
  State<_LookScannerTab> createState() => _LookScannerTabState();
}

class _LookScannerTabState extends State<_LookScannerTab> {
  String _selectedCountry = '';
  String _query = '';
  late final Future<LookIpPoolData> _poolFuture = LookCatalog.loadIpPool();
  final _liveScanner = LookLiveScanner();
  StreamSubscription? _scanSub;
  bool _scanning = false;
  int _tested = 0;
  int _total = 0;
  List<LookScanResult> _liveResults = const [];

  // The live TCP scanner's settings, persisted with the other scanners.
  int _livePort = 443;
  int _liveSample = 80;
  int _liveTimeout = 1400;
  int _liveConcurrency = 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = AppScope.read(context).device.scanners['look_live'];
      if (saved == null) return;
      setState(() {
        int? number(String key) =>
            saved[key] is num ? (saved[key] as num).toInt() : null;
        final port = number('port');
        final sample = number('sample');
        final timeout = number('timeout');
        final concurrency = number('concurrency');
        if (port != null) _livePort = port;
        if (sample != null) _liveSample = sample;
        if (timeout != null) _liveTimeout = timeout;
        if (concurrency != null) _liveConcurrency = concurrency;
      });
    });
  }

  @override
  void dispose() {
    _liveScanner.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  void _applyCleanIps(BuildContext context, List<String> ips, String label) {
    if (ips.isEmpty) return;
    AppScope.read(context).write('vless.cleanIps', ips);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LookLocale.t(
            '${ips.length} آی‌پی ($label) به‌عنوان آی‌پی تمیز ثبت شد',
            'Set ${ips.length} IP(s) ($label) as VLESS Clean IPs',
          ),
        ),
      ),
    );
  }

  void _applyProxyIps(BuildContext context, List<String> ips, String label) {
    if (ips.isEmpty) return;
    final formatted = ips
        .map((ip) => ip.contains(':') && !ip.startsWith('[') ? '[$ip]:443' : (ip.contains(':') ? ip : '$ip:443'))
        .toList();
    AppScope.read(context).write('vless.proxyIps', formatted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LookLocale.t(
            '${formatted.length} آی‌پی ($label) به‌عنوان پروکسی آی‌پی ثبت شد',
            'Set ${formatted.length} IP(s) ($label) as Worker ProxyIPs',
          ),
        ),
      ),
    );
  }

  void _startLiveScan(LookIpPoolData data) {
    _liveScanner.cancel();
    _scanSub?.cancel();
    final state = AppScope.read(context);
    if (state.isReady) {
      state.write('device.scanners.look_live', {
        'port': _livePort,
        'sample': _liveSample,
        'timeout': _liveTimeout,
        'concurrency': _liveConcurrency,
      });
    }
    final pool = List<LookIpEntry>.of(data.byCountry(_selectedCountry))..shuffle();
    final sample = (_liveSample <= 0 ? pool : pool.take(_liveSample)).toList();
    setState(() {
      _scanning = true;
      _tested = 0;
      _total = sample.length;
      _liveResults = const [];
    });
    _scanSub = _liveScanner.scan(
      entries: sample,
      port: _livePort,
      concurrency: _liveConcurrency,
      timeout: Duration(milliseconds: _liveTimeout),
    ).listen(
      (ev) {
        if (!mounted) return;
        setState(() {
          _tested = ev.tested;
          _total = ev.total;
          _liveResults = ev.results;
        });
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  void _stopLiveScan() {
    _liveScanner.cancel();
    _scanSub?.cancel();
    setState(() => _scanning = false);
  }

  Future<void> _liveScannerSettings() async {
    var port = _livePort;
    var sample = _liveSample;
    var timeout = _liveTimeout;
    var concurrency = _liveConcurrency;
    final result = await showDialog<(int, int, int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(LookLocale.t('تنظیمات اسکنر زنده', 'Live scanner settings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: port,
                decoration: InputDecoration(labelText: LookLocale.t('پورت', 'Port')),
                items: const [443, 2053, 2083, 2087, 2096, 8443]
                    .map((p) => DropdownMenuItem(value: p, child: Text('$p')))
                    .toList(),
                onChanged: (v) => v == null ? null : update(() => port = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: sample,
                decoration: InputDecoration(labelText: LookLocale.t('تعداد نمونه', 'Sample size')),
                items: const [40, 80, 160, 0]
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: Text(n == 0 ? LookLocale.t('همه', 'All') : '$n'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => v == null ? null : update(() => sample = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: timeout,
                decoration: InputDecoration(labelText: LookLocale.t('تایم‌اوت (میلی‌ثانیه)', 'Timeout (ms)')),
                items: const [800, 1400, 2000, 3000]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (v) => v == null ? null : update(() => timeout = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: concurrency,
                decoration: InputDecoration(labelText: LookLocale.t('همزمانی', 'Concurrency')),
                items: const [8, 16, 32, 48]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (v) => v == null ? null : update(() => concurrency = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(LookLocale.t('انصراف', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop((port, sample, timeout, concurrency)),
              child: Text(LookLocale.t('ذخیره', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _livePort = result.$1;
      _liveSample = result.$2;
      _liveTimeout = result.$3;
      _liveConcurrency = result.$4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentCleanIps = AppScope.of(context).vless.cleanIps;
    final currentProxyIps = AppScope.of(context).vless.proxyIps;

    return FutureBuilder<LookIpPoolData>(
      future: _poolFuture,
      builder: (context, snap) {
        final data = snap.data;
        final filtered = data == null
            ? const <LookIpEntry>[]
            : data.byCountry(_selectedCountry).where((e) {
                if (_query.isEmpty) return true;
                return e.ip.contains(_query) ||
                    e.country.toLowerCase().contains(_query.toLowerCase());
              }).toList();

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    // 1. Live Fast Look TCP Scanner (works immediately, zero worker needed!)
                    BettboxTileCard(
                      title: LookLocale.t(
                        LookLocale.t('اسکنر زنده سریع', 'Fast live scanner'),
                        'Fast live scanner',
                      ),
                      icon: Symbols.speed_rounded,
                      watermarkIcon: Symbols.radar_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: LookLocale.t('تنظیمات اسکنر', 'Scanner settings'),
                                onPressed: _scanning ? null : _liveScannerSettings,
                                icon: const Icon(Symbols.tune_rounded, size: 20),
                              ),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: data == null
                                      ? null
                                      : (_scanning
                                            ? _stopLiveScan
                                            : () => _startLiveScan(data)),
                                  icon: Icon(
                                    _scanning
                                        ? Symbols.stop_rounded
                                        : Symbols.play_arrow_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _scanning
                                        ? LookLocale.t('توقف اسکن', 'Stop Scan')
                                        : LookLocale.t('شروع اسکن زنده', 'Start Live Scan'),
                                  ),
                                ),
                              ),
                              if (_liveResults.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () => _applyCleanIps(
                                    context,
                                    _liveResults.take(8).map((e) => e.ip).toList(),
                                    'Fastest ${_liveResults.take(8).length}',
                                  ),
                                  child: Text(LookLocale.t('آی‌پی تمیز', 'Clean IP')),
                                ),
                                const SizedBox(width: 6),
                                FilledButton.tonal(
                                  onPressed: () => _applyProxyIps(
                                    context,
                                    _liveResults.take(5).map((e) => e.ip).toList(),
                                    'Fastest ${_liveResults.take(5).length}',
                                  ),
                                  child: Text(LookLocale.t('پروکسی', 'ProxyIP')),
                                ),
                              ],
                            ],
                          ),
                          if (_scanning || _total > 0) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: _total == 0 ? 0 : _tested / _total,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              LookLocale.t(
                                'بررسی‌شده: $_tested از $_total · سالم یافت‌شده: ${_liveResults.length}',
                                'Tested: $_tested / $_total · Alive: ${_liveResults.length}',
                              ),
                              style: _tabular.copyWith(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_liveResults.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final r in _liveResults.take(6))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: scheme.surfaceContainerHigh,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(countryFlag(r.country)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          r.ip,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${r.pingMs} ms',
                                        style: _tabular.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: r.pingMs < 180
                                              ? scheme.primary
                                              : (r.pingMs < 400
                                                    ? scheme.tertiary
                                                    : scheme.error),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => _applyCleanIps(context, [r.ip], r.country),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(Symbols.bolt_rounded, size: 17, color: scheme.primary),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _applyProxyIps(context, [r.ip], r.country),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(Symbols.dns_rounded, size: 17, color: scheme.secondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Native Go REAL Tunnel Scanners (VLESS, WARP, MASQUE H2/H3)
                    BettboxTileCard(
                      title: LookLocale.t(
                        'اسکنر عمیق تونل کلادفلر (REAL Scanner)',
                        'Cloudflare REAL Tunnel Scanner',
                      ),
                      icon: Symbols.radar_rounded,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in const [
                            (ScanProtocol.vless, 'VLESS'),
                            (ScanProtocol.warp, 'WARP'),
                            (ScanProtocol.masqueH2, 'MASQUE H2'),
                            (ScanProtocol.masqueH3, 'MASQUE H3'),
                          ])
                            BettboxChip(
                              icon: Symbols.radar_rounded,
                              label: s.$2,
                              active: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CloudflareScannerPage(protocol: s.$1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // IP pool actions.
                    BettboxTileCard(
                      title: LookLocale.t(
                        LookLocale.t('مخزن آی‌پی (تمیز + پروکسی)', 'IP pool (Clean + Proxy)'),
                        'IP pool (Clean + Proxy)',
                      ),
                      icon: Symbols.dns_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data != null)
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _applyCleanIps(
                                      context,
                                      data.pickRandom(count: 10, countryCode: _selectedCountry),
                                      _selectedCountry.isEmpty ? 'Random' : _selectedCountry,
                                    ),
                                    icon: const Icon(Symbols.bolt_rounded, size: 16),
                                    label: Text(LookLocale.t('۱۰ آی‌پی تمیز', '10 Clean IPs')),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _applyProxyIps(
                                      context,
                                      data.pickRandom(count: 5, countryCode: _selectedCountry),
                                      _selectedCountry.isEmpty ? 'Random' : _selectedCountry,
                                    ),
                                    icon: const Icon(Symbols.dns_rounded, size: 16),
                                    label: Text(LookLocale.t('۵ پروکسی آی‌پی', '5 ProxyIPs')),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          TextField(
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: const Icon(Symbols.search_rounded, size: 19),
                              hintText: LookLocale.t(
                                'جستجوی آی‌پی یا کشور (DE, NL, US)…',
                                'Search IP or country (DE, NL, US)…',
                              ),
                            ),
                            onChanged: (v) => setState(() => _query = v.trim()),
                          ),
                          if (data != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(end: 8),
                                    child: ChoiceChip(
                                      selected: _selectedCountry.isEmpty,
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        LookLocale.t('همه', 'All'),
                                      ),
                                      onSelected: (_) =>
                                          setState(() => _selectedCountry = ''),
                                    ),
                                  ),
                                  for (final c in data.countries)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(end: 8),
                                      child: ChoiceChip(
                                        selected: _selectedCountry == c.code,
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '${countryFlag(c.code)} ${c.code} (${c.count})',
                                        ),
                                        onSelected: (_) =>
                                            setState(() => _selectedCountry = c.code),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (data == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 102),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final isClean = currentCleanIps.contains(item.ip);
                    final isProxy = currentProxyIps.contains('${item.ip}:443');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 7),
                      shape: roundedShape(
                        15,
                        side: BorderSide(
                          color: (isClean || isProxy)
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Text(
                          countryFlag(item.country),
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(
                          item.ip,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${item.country} · ${isClean ? "Clean IP " : ""}${isProxy ? "ProxyIP" : ""}'
                              .trim(),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: LookLocale.t('ثبت به‌عنوان آی‌پی تمیز', 'Set as Clean IP'),
                              icon: Icon(
                                Symbols.bolt_rounded,
                                size: 19,
                                color: isClean ? scheme.primary : scheme.primary,
                              ),
                              onPressed: () =>
                                  _applyCleanIps(context, [item.ip], item.country),
                            ),
                            IconButton(
                              tooltip: LookLocale.t('ثبت به‌عنوان پروکسی آی‌پی', 'Set as ProxyIP'),
                              icon: Icon(
                                Symbols.dns_rounded,
                                size: 19,
                                color: isProxy ? scheme.primary : scheme.secondary,
                              ),
                              onPressed: () =>
                                  _applyProxyIps(context, [item.ip], item.country),
                            ),
                            IconButton(
                              tooltip: LookLocale.t('کپی', 'Copy'),
                              icon: const Icon(Symbols.content_copy_rounded, size: 17),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: item.ip));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied ${item.ip}')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
