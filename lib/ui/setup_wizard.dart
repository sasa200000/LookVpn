import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/cf_account.dart';
import '../models/settings.dart';
import '../services/cloudflare_api.dart';
import '../services/cloudflare_client.dart';
import '../services/net_errors.dart';
import '../services/vpn_channel.dart';
import '../state/app_state.dart';
import 'cf_accounts_page.dart';
import 'look_i18n.dart';
import 'look_logo.dart';

const _signUpUrl = 'https://dash.cloudflare.com/sign-up';

/// A checked API token: the token, its user's email and the accounts it can access.
typedef CheckedToken = ({String token, String email, List<CfAccount> accounts});

/// First-run setup, like LookVPN-Wizard's three steps: Cloudflare account → API token →
/// install the VPN worker. Shown instead of the home page until a worker is set up, and pushed
/// by Cloudflare accounts → Add account ([addingAccount]); every run deploys a fresh worker.
class SetupWizard extends StatefulWidget {
  final bool addingAccount;
  const SetupWizard({super.key, this.addingAccount = false});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

enum _Step { account, token, install, done }

class _SetupWizardState extends State<SetupWizard> {
  _Step _step = _Step.account;

  /// Tapped "No" on step 1: sign-up page opened, waiting for the user to come back.
  bool _signingUp = false;

  CheckedToken? _token;

  /// Installing has started: no going back to the token.
  bool _installing = false;

  /// What the install step did, for the last page.
  Map<_Item, _Row> _results = const {};

  void _go(_Step step) => setState(() => _step = step);

  void _back() => switch (_step) {
    _Step.account => setState(() => _signingUp = false),
    _Step.token => _go(_Step.account),
    _Step.install => _installing ? null : _go(_Step.token),
    _Step.done => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final canGoBack =
        _step != _Step.done &&
        !_installing &&
        (_step != _Step.account || _signingUp);

    return PopScope(
      // System back goes to the previous step instead of closing the app.
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: DecoratedBox(
          // Use the same adaptive surface as the Bento shell. The wizard is shown before
          // the shell, so it must not be stuck on a dark gradient when the user chose light.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? const [
                      Color(0xFFF8FAFC),
                      Color(0xFFF1F5F9),
                      Color(0xFFF7F8FC),
                    ]
                  : [
                      scheme.primary.withValues(alpha: 0.10),
                      scheme.surface,
                      scheme.surface,
                    ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_step != _Step.done) ...[
                  ValueListenableBuilder<String>(
                    valueListenable: LookLocale.code,
                    builder: (context, _, __) => Row(
                      children: [
                        const LookLogo(size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LookVPN',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                LookLocale.t('راه‌اندازی امن در ۳ مرحله', 'Secure setup in 3 steps'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final index = LookLocale.languages.indexWhere(
                              (l) => l.code == LookLocale.code.value,
                            );
                            final next =
                                LookLocale.languages[(index + 1) %
                                    LookLocale.languages.length];
                            LookLocale.setLang(next.code);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: Text(
                            LookLocale.code.value.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!widget.addingAccount && _step == _Step.account)
                          TextButton(
                            onPressed: () => AppScope.read(context).finishSetup(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(LookLocale.t('رد کردن', 'Skip')),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StepBar(current: _step.index),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        _Step.account => _AccountStep(
                          signingUp: _signingUp,
                          onNo: () async {
                            setState(() => _signingUp = true);
                            await _openUrl(context, _signUpUrl);
                          },
                          onYes: () => _go(_Step.token),
                          onBack: _back,
                        ),
                        _Step.token => _TokenStep(
                          onBack: _back,
                          onNext: (token) {
                            _token = token;
                            _go(_Step.install);
                          },
                        ),
                        _Step.install => _InstallStep(
                          token: _token!,
                          addingAccount: widget.addingAccount,
                          onBack: _back,
                          onStarted: () => setState(() => _installing = true),
                          onDone: (rows) {
                            _results = rows;
                            _go(_Step.done);
                          },
                        ),
                        _Step.done => _DoneStep(rows: _results, addingAccount: widget.addingAccount),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Three labelled steps: the current one glows, finished ones are checked.
class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  static const _labels = [
    ('حساب کلادفلر', 'Cloudflare'),
    ('توکن API', 'API token'),
    ('نصب و اتصال', 'Install'),
  ];
  static const _icons = [
    Symbols.cloud_rounded,
    Symbols.key_rounded,
    Symbols.rocket_launch_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: i <= current
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current
                        ? scheme.primary.withValues(alpha: 0.18)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    border: Border.all(
                      color: i <= current
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.7),
                      width: i == current ? 2 : 1,
                    ),
                  ),
                  child: i < current
                      ? Icon(Symbols.check_rounded, size: 20, color: scheme.primary)
                      : Icon(
                          _icons[i],
                          size: 18,
                          color: i == current
                              ? scheme.primary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  LookLocale.t(_labels[i].$1, _labels[i].$2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                    color: i == current
                        ? scheme.primary
                        : scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A compact progress summary above the worker installation checklist.
class _InstallProgress extends StatelessWidget {
  final List<_Row> rows;
  const _InstallProgress({required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = rows.length;
    final done = rows.where((row) => row.status == _Status.done).length;
    final failed = rows.where((row) => row.status == _Status.failed).length;
    final progress = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                failed > 0
                    ? Symbols.error_outline_rounded
                    : Symbols.rocket_launch_rounded,
                size: 17,
                color: failed > 0 ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  LookLocale.t('پیشرفت نصب ورکر', 'Worker installation'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$done / $total',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: failed > 0 ? scheme.error : scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

/// The glowing card with the step's icon, title, body, and buttons pinned below.
class _StepLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final List<Widget> buttons;
  const _StepLayout({required this.icon, required this.title, required this.children, required this.buttons});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.10),
                    scheme.surfaceContainer.withValues(alpha: 0.55),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.08),
                    blurRadius: 32,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.16),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(icon, size: 25, color: scheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.7,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: buttons),
      ],
    );
  }
}

/// "1. Do this" lines.
class _Instruction extends StatelessWidget {
  final int number;
  final InlineSpan text;
  const _Instruction(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.secondaryContainer,
            child: Text(
              '$number',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text.rich(text)),
        ],
      ),
    );
  }
}

TextSpan _bold(String text) => TextSpan(
  text: text,
  style: const TextStyle(fontWeight: FontWeight.w700),
);

Future<void> _openUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await VpnChannel.openUrl(url)) {
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          LookLocale.t(
            'لینک کپی شد. آن را در مرورگر باز کنید.',
            'Link copied. Open it in your browser.',
          ),
        ),
      ),
    );
  }
}

// region step 1: account

class _AccountStep extends StatelessWidget {
  final bool signingUp;
  final VoidCallback onNo;
  final VoidCallback onYes;
  final VoidCallback onBack;
  const _AccountStep({required this.signingUp, required this.onNo, required this.onYes, required this.onBack});

  @override
  Widget build(BuildContext context) {
    if (signingUp) {
      return _StepLayout(
        icon: Symbols.person_add_rounded,
        title: LookLocale.t('حساب کلادفلر بسازید', 'Create your Cloudflare account'),
        buttons: [
          TextButton(
            onPressed: onBack,
            child: Text(LookLocale.t('بازگشت', 'Back')),
          ),
          const SizedBox(width: 12),
          // Takes the rest of the row, so the label stays on one line (and can't overflow).
          Expanded(
            child: FilledButton(
              onPressed: onYes,
              child: Text(LookLocale.t('ایمیل را تأیید کردم', "I've verified it")),
            ),
          ),
        ],
        children: [
          _Instruction(
            1,
            TextSpan(
              text: LookLocale.t(
                'در صفحه‌ای که باز شد، در کلادفلر ثبت‌نام کنید.',
                'Sign up on the Cloudflare page that just opened.',
              ),
            ),
          ),
          _Instruction(
            2,
            TextSpan(
              text: LookLocale.t(
                'ایمیل کلادفلر را باز کنید و آدرس ایمیل خود را تأیید کنید.',
                'Open the email Cloudflare sends you and verify your address.',
              ),
            ),
          ),
          _Instruction(
            3,
            TextSpan(
              text: LookLocale.t(
                'به اینجا برگردید و ادامه دهید.',
                'Come back here and continue.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openUrl(context, _signUpUrl),
            icon: const Icon(Symbols.open_in_new_rounded, size: 18),
            label: Text(LookLocale.t('بازکردن دوباره صفحه ثبت‌نام', 'Open sign-up page again')),
          ),
        ],
      );
    }
    return _StepLayout(
      icon: Symbols.shield_rounded,
      title: LookLocale.t('به LookVPN خوش آمدید', 'Welcome to LookVPN'),
      buttons: [
        Expanded(
          child: OutlinedButton(
            onPressed: onNo,
            child: Text(LookLocale.t('نه، ثبت‌نام می‌کنم', 'No, sign me up')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onYes,
            child: Text(LookLocale.t('بله، دارم', 'Yes')),
          ),
        ),
      ],
      children: [
        Text(
          LookLocale.t(
            'LookVPN یک پروکسی خصوصی روی پلن رایگان کلادفلر برای شما می‌سازد. '
                'راه‌اندازی فقط سه مرحله و چند دقیقه وقت می‌برد.',
            'LookVPN runs your own private proxy server on Cloudflare\'s free plan. '
                'Setting it up takes three steps and a couple of minutes.',
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.verified_user_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LookLocale.t(
                    'آیا حساب کلادفلر با ایمیل تأییدشده دارید؟',
                    'Do you have a Cloudflare account with a verified email?',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// endregion

// region step 2: token

class _TokenStep extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(CheckedToken token) onNext;
  const _TokenStep({required this.onBack, required this.onNext});

  @override
  State<_TokenStep> createState() => _TokenStepState();
}

class _TokenStepState extends State<_TokenStep> {
  final _token = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) setState(() => _token.text = text);
  }

  Future<void> _next() async {
    if (_token.text.trim().isEmpty) {
      return setState(
        () => _error = LookLocale.t(
          'اول توکن API را جای‌گذاری کنید',
          'Paste your API token first',
        ),
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.onNext(await AppScope.read(context).checkCfToken(_token.text));
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      icon: Symbols.key_rounded,
      title: LookLocale.t('توکن API بسازید', 'Create an API token'),
      buttons: [
        TextButton(
          onPressed: _busy ? null : widget.onBack,
          child: Text(LookLocale.t('بازگشت', 'Back')),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _busy ? null : _next,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(LookLocale.t('ادامه', 'Next')),
        ),
      ],
      children: [
        _Instruction(
          1,
          TextSpan(
            children: [
              TextSpan(text: LookLocale.t('روی ', 'Tap ')),
              _bold(LookLocale.t('ساخت توکن', 'Create token')),
              TextSpan(
                text: LookLocale.t(
                  ' پایین بزنید؛ دسترسی‌های لازم از قبل پر شده‌اند.',
                  ' below. The permissions are filled in for you.',
                ),
              ),
            ],
          ),
        ),
        _Instruction(
          2,
          TextSpan(
            children: [
              TextSpan(
                text: LookLocale.t(
                  'اگر خواست وارد شوید، پایین بروید و ',
                  'Log in if asked, scroll down and tap ',
                ),
              ),
              _bold(LookLocale.t('ادامه به خلاصه', 'Continue to summary')),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        _Instruction(
          3,
          TextSpan(
            children: [
              TextSpan(text: LookLocale.t('روی ', 'Tap ')),
              _bold(LookLocale.t('ساخت توکن', 'Create Token')),
              TextSpan(
                text: LookLocale.t(
                  ' بزنید و توکن را کپی کنید.',
                  ', then copy the token.',
                ),
              ),
            ],
          ),
        ),
        _Instruction(
          4,
          TextSpan(
            text: LookLocale.t(
              'به اینجا برگردید و آن را جای‌گذاری کنید.',
              'Come back and paste it here.',
            ),
          ),
        ),
        const SizedBox(height: 4),
        FilledButton.tonalIcon(
          onPressed: () => openTokenPage(context),
          icon: const Icon(Symbols.open_in_new_rounded, size: 18),
          label: Text(LookLocale.t('ساخت توکن', 'Create token')),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _token,
          enabled: !_busy,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: LookLocale.t('توکن API کلادفلر', 'Cloudflare API token'),
            errorText: _error,
            errorMaxLines: 4,
            helperText: LookLocale.t(
              'فقط روی همین دستگاه ذخیره می‌شود.',
              'Stored only on this device.',
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: LookLocale.t('جای‌گذاری', 'Paste'),
                  onPressed: _busy ? null : _paste,
                  icon: const Icon(Symbols.content_paste_rounded),
                ),
                IconButton(
                  tooltip: _obscure
                      ? LookLocale.t('نمایش', 'Show')
                      : LookLocale.t('پنهان', 'Hide'),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
                ),
              ],
            ),
          ),
          onSubmitted: (_) => _next(),
        ),
      ],
    );
  }
}

// endregion

// region step 3: install

/// What the wizard installs, one after another.
enum _Item {
  workers('استقرار Workers', 'Workers deployment'),
  pages('استقرار Pages', 'Pages deployment'),
  warp('ثبت WARP', 'WARP registration'),
  masque('ثبت MASQUE', 'MASQUE registration');

  final String fa;
  final String en;
  const _Item(this.fa, this.en);
  String get label => LookLocale.t(fa, en);
}

enum _Status { waiting, running, done, failed, skipped }

class _Row {
  _Status status = _Status.waiting;
  String? message;

  /// It failed to reach the server (Tor may help), rather than being refused.
  bool network = false;
}

/// The Tor bridges the build embedded for "Retry with Tor" (assets/tor/bridges.json, written by
/// scripts/fetch_tor_bridges.sh), or null without them. Only the wizard uses them.
Future<List<String>?> _embeddedBridges() async {
  try {
    final json = jsonDecode(await rootBundle.loadString('assets/tor/bridges.json')) as Map;
    final bridges = (json['bridges'] as List).whereType<String>().toList();
    return bridges.isEmpty ? null : bridges;
  } catch (_) {
    return null;
  }
}

class _InstallStep extends StatefulWidget {
  final CheckedToken token;
  final bool addingAccount;
  final VoidCallback onBack;

  /// Called once installing starts (no going back after that).
  final VoidCallback onStarted;

  /// Called when every item is done, or the failed ones were skipped.
  final void Function(Map<_Item, _Row> rows) onDone;
  const _InstallStep({
    required this.token,
    required this.addingAccount,
    required this.onBack,
    required this.onStarted,
    required this.onDone,
  });

  @override
  State<_InstallStep> createState() => _InstallStepState();
}

class _InstallStepState extends State<_InstallStep> {
  late CfAccount _account = widget.token.accounts.first;

  /// The account's UUID, in both deployments' ENV.
  final _uuid = generateUuid();

  /// What's deployed so far: the account is saved only once it has both.
  final _deployed = <WorkerType, Deployment>{};
  bool _saved = false;

  /// Adding an account only deploys; WARP and MASQUE belong to the device.
  late final _rows = {
    for (final i in _Item.values)
      if (!widget.addingAccount || i == _Item.workers || i == _Item.pages) i: _Row(),
  };
  bool _started = false;
  bool _busy = false;
  List<String>? _bridges;

  /// Tor's bootstrap progress while "Retry with Tor" connects.
  int? _torProgress;
  String? _torError;

  @override
  void initState() {
    super.initState();
    _embeddedBridges().then((b) {
      if (mounted) setState(() => _bridges = b);
    });
  }

  Iterable<_Item> get _failed => [
    for (final e in _rows.entries)
      if (e.value.status == _Status.failed) e.key,
  ];

  Future<void> _install(_Item item) async {
    final row = _rows[item]!;
    final state = AppScope.read(context);
    setState(() {
      row
        ..status = _Status.running
        ..message = null
        ..network = false;
    });
    try {
      switch (item) {
        case _Item.workers || _Item.pages:
          final type = item == _Item.workers ? WorkerType.workers : WorkerType.pages;
          _deployed[type] = await state.deployFresh(
            token: widget.token.token,
            accountId: _account.id,
            type: type,
            uuid: _uuid,
          );
        case _Item.warp:
          await state.renewWarpAccount();
        case _Item.masque:
          await state.renewMasqueAccount();
      }
      row.status = _Status.done;
    } catch (e) {
      row
        ..status = _Status.failed
        ..network = isNetworkError(e)
        ..message = isNetworkError(e)
            ? LookLocale.t('اتصال به سرور برقرار نشد', "Can't reach the server")
            : (e is StateError ? e.message : '$e');
    }
    if (mounted) setState(() {});
  }

  /// Installs [items] side by side; when nothing failed, moves on.
  Future<void> _run(Iterable<_Item> items) async {
    if (!_started) {
      _started = true;
      widget.onStarted();
      // First run: keep the wizard on screen until its last page, though things now exist.
      if (!widget.addingAccount) AppScope.read(context).setSetupInProgress(true);
    }
    setState(() => _busy = true);
    await Future.wait([for (final item in items.toList()) _install(item)]);
    if (!mounted) return;
    // The account is added only with both its workers deployed.
    if (!_saved && _deployed.length == WorkerType.values.length) {
      try {
        await AppScope.read(context).addCfAccount(
          token: widget.token.token,
          email: widget.token.email,
          account: _account,
          uuid: _uuid,
          deployments: _deployed.values.toList(),
        );
        _saved = true;
      } catch (e) {
        _rows[_Item.workers]!
          ..status = _Status.failed
          ..message = '$e';
      }
      if (!mounted) return;
    }
    setState(() => _busy = false);
    if (_failed.isEmpty) widget.onDone(_rows);
  }

  /// Starts Tor with the embedded bridges, then retries the failed items through it.
  Future<void> _retryWithTor() async {
    setState(() {
      _busy = true;
      _torProgress = 0;
      _torError = null;
    });
    try {
      final port = await VpnChannel.startSetupTor(_bridges!);
      var last = -1;
      var since = DateTime.now();
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        final status = await VpnChannel.setupTorStatus();
        if (!status.running) {
          throw StateError(status.error ?? LookLocale.t('تور متوقف شد', 'Tor stopped'));
        }
        if (status.progress != last) {
          last = status.progress;
          since = DateTime.now();
        }
        setState(() => _torProgress = status.progress);
        if (status.progress >= 100) break;
        if (DateTime.now().difference(since) > const Duration(minutes: 2)) {
          throw StateError(
            LookLocale.t(
              'تور با بریج‌های داخلی وصل نشد',
              "Tor couldn't connect with the built-in bridges",
            ),
          );
        }
      }
      setState(() => _torProgress = null);
      await CloudflareClient.viaTor(port, () => _run(_failed));
    } catch (e) {
      if (mounted) {
        setState(() {
          _torError = e is StateError ? e.message : '$e';
          _torProgress = null;
          _busy = false;
        });
      }
    } finally {
      await VpnChannel.stopSetupTor();
    }
  }

  /// Skips what failed. Half a worker deployment isn't kept: what did deploy is deleted from
  /// Cloudflare again (best effort), and the account isn't added.
  Future<void> _skip() async {
    if (!_saved && _deployed.isNotEmpty) {
      setState(() => _busy = true);
      await AppScope.read(context)
          .deleteFresh(token: widget.token.token, accountId: _account.id, deployments: _deployed.values.toList())
          .catchError((_) {});
      _deployed.clear();
      if (!mounted) return;
      for (final item in [_Item.workers, _Item.pages]) {
        if (_rows[item]?.status == _Status.done) _rows[item]!.status = _Status.skipped;
      }
    }
    for (final item in _failed.toList()) {
      _rows[item]!.status = _Status.skipped;
    }
    widget.onDone(_rows);
  }

  @override
  void dispose() {
    VpnChannel.stopSetupTor();
    super.dispose();
  }

  Widget _rowTile(BuildContext context, _Item item, _Row row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (row.status) {
      _Status.waiting => Icon(
        Symbols.radio_button_unchecked_rounded,
        color: scheme.outline,
        size: 21,
      ),
      _Status.running => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      ),
      _Status.done => Icon(
        Symbols.check_circle_rounded,
        color: scheme.primary,
        fill: 1,
        size: 21,
      ),
      _Status.failed => Icon(
        Symbols.cancel_rounded,
        color: scheme.error,
        fill: 1,
        size: 21,
      ),
      _Status.skipped => Icon(
        Symbols.do_not_disturb_on_rounded,
        color: scheme.outline,
        size: 21,
      ),
    };
    final active = row.status == _Status.running;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active
              ? scheme.primary.withValues(alpha: 0.09)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.46),
          border: Border.all(
            color: active
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (row.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        row.message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = widget.token.accounts;
    final failed = _failed.toList();
    final offerTor = _bridges != null && failed.any((i) => _rows[i]!.network);
    final List<Widget> buttons;
    if (!_started) {
      buttons = [
        TextButton(
          onPressed: widget.onBack,
          child: Text(LookLocale.t('بازگشت', 'Back')),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => _run(_rows.keys),
          icon: const Icon(Symbols.cloud_upload_rounded),
          label: Text(LookLocale.t('نصب و راه‌اندازی', 'Install')),
        ),
      ];
    } else if (!_busy && failed.isNotEmpty) {
      // One set of choices for whatever failed.
      buttons = [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: Text(LookLocale.t('فعلاً رد کن', 'Skip for now')),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (offerTor) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _retryWithTor,
                        child: Text(LookLocale.t('تلاش دوباره با تور', 'Retry with Tor')),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ] else
                    const Spacer(),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _run(failed),
                      child: Text(LookLocale.t('تلاش دوباره', 'Retry')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ];
    } else {
      buttons = const [];
    }
    return _StepLayout(
      icon: Symbols.rocket_launch_rounded,
      title: widget.addingAccount
          ? LookLocale.t('نصب ورکر VPN', 'Install your VPN worker')
          : LookLocale.t('نصب LookVPN', 'Install LookVPN'),
      buttons: buttons,
      children: [
        Text(
          widget.addingAccount
              ? LookLocale.t(
                  'پروکسی شما روی کلادفلر به شکل یک Worker و یک پروژه Pages نصب می‌شود.',
                  'Your proxy will be deployed to Cloudflare as a Worker and a Pages project.',
                )
              : LookLocale.t(
                  'پروکسی شما روی کلادفلر به شکل Worker و Pages نصب می‌شود و سپس حساب‌های WARP و MASQUE ثبت می‌شوند.',
                  'Your proxy will be deployed to Cloudflare as a Worker and a Pages project, '
                      'then WARP and MASQUE accounts are registered.',
                ),
        ),
        const SizedBox(height: 14),
        _InstallProgress(rows: _rows.values.toList()),
        const SizedBox(height: 14),
        if (accounts.length > 1 && !_started) ...[
          DropdownMenu<CfAccount>(
            initialSelection: _account,
            expandedInsets: EdgeInsets.zero,
            label: Text(LookLocale.t('حساب کلادفلر', 'Cloudflare account')),
            dropdownMenuEntries: [for (final a in accounts) DropdownMenuEntry(value: a, label: a.name)],
            onSelected: (a) {
              if (a != null) setState(() => _account = a);
            },
          ),
          const SizedBox(height: 8),
        ],
        for (final MapEntry(key: item, value: row) in _rows.entries) _rowTile(context, item, row),
        if (_torProgress case final progress?) ...[
          const SizedBox(height: 12),
          Text(
            LookLocale.t(
              'اتصال از طریق تور… $progress%',
              'Connecting through Tor… $progress%',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress / 100),
        ],
        if (_torError != null) ...[
          const SizedBox(height: 12),
          Text(_torError!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (!_busy && failed.any((i) => _rows[i]!.network)) ...[
          const SizedBox(height: 12),
          Text(
            LookLocale.t(
              'برخی مراحل به سرور نرسیدند. با یک VPN یا پروکسی دیگر دوباره تلاش کنید'
                  '${offerTor ? '، یا با تور تلاش کنید' : ''}، یا فعلاً رد کنید و بعداً از تب ابزارها کامل کنید.',
              "Some steps couldn't reach the server. Connect through another VPN or proxy and retry"
                  '${offerTor ? ', retry through Tor' : ''}, or skip them and finish later from Tools.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (!_busy && failed.any((i) => (i == _Item.workers || i == _Item.pages) && !_rows[i]!.network)) ...[
          const SizedBox(height: 12),
          Text(
            LookLocale.t(
              'نصب Workers انجام نشد. حساب کلادفلر را بررسی کنید یا از حساب دیگری استفاده کنید.',
              'Workers could not be deployed. Please check your Cloudflare account or use another account.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

// endregion

// region done

class _DoneStep extends StatelessWidget {
  final Map<_Item, _Row> rows;
  final bool addingAccount;
  const _DoneStep({required this.rows, required this.addingAccount});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final theme = Theme.of(context);
    final skipped = [
      for (final e in rows.entries)
        if (e.value.status == _Status.skipped) e.key,
    ];
    final deploySkipped = skipped.any((i) => i == _Item.workers || i == _Item.pages);
    final registerSkipped = skipped.any((i) => i == _Item.warp || i == _Item.masque);
    return _StepLayout(
      icon: Symbols.check_circle_rounded,
      title: skipped.isEmpty
          ? LookLocale.t('همه‌چیز آماده است', "You're all set")
          : LookLocale.t('تقریباً تمام شد', 'Almost done'),
      buttons: [
        Expanded(
          child: addingAccount
              ? FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(LookLocale.t('تمام', 'Done')),
                )
              : FilledButton(
                  onPressed: state.finishSetup,
                  child: Text(LookLocale.t('شروع استفاده از LookVPN', 'Start using LookVPN')),
                ),
        ),
      ],
      children: [
        for (final MapEntry(key: item, value: row) in rows.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                row.status == _Status.done
                    ? Icon(
                        Symbols.check_circle_rounded,
                        color: theme.colorScheme.primary,
                        fill: 1,
                      )
                    : Icon(
                        Symbols.do_not_disturb_on_rounded,
                        color: theme.colorScheme.outline,
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    row.status == _Status.done
                        ? item.label
                        : LookLocale.t('${item.label} (رد شد)', '${item.label} (skipped)'),
                  ),
                ),
              ],
            ),
          ),
        if (skipped.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            LookLocale.t(
              'این پروتکل‌ها بعد از تکمیل راه‌اندازی در دسترس قرار می‌گیرند:',
              'These protocols will be available once you finish setting them up:',
            ),
          ),
          if (deploySkipped)
            Text(
              LookLocale.t(
                '• ورکر: در تنظیمات → VLESS → حساب‌های کلادفلر یک حساب اضافه کنید.',
                '• Worker: add a Cloudflare account in Settings → VLESS → Cloudflare accounts.',
              ),
            ),
          if (registerSkipped)
            Text(
              LookLocale.t(
                '• WARP / MASQUE: تنظیمات → Warp یا Masque → ثبت.',
                '• WARP / MASQUE: Settings → Warp or Masque → Register.',
              ),
            ),
          if (!addingAccount)
            Text(
              LookLocale.t(
                'Psiphon، Tor و Serverless بدون آن‌ها هم کار می‌کنند.',
                'Psiphon, Tor and Serverless work without them.',
              ),
            ),
        ],
      ],
    );
  }
}

// endregion
