import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/look_home_shell.dart';
import 'ui/look_i18n.dart';
import 'ui/setup_wizard.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LookLocale.init();
  final state = AppState();
  await state.init();
  runApp(LookApp(state: state));
}

class LookApp extends StatelessWidget {
  final AppState state;
  const LookApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          state.themeColor,
          state.themeMode,
          state.fontFamily,
          state.fontScale,
          state.motionEnabled,
          state.pageTransition,
          state.meshBackground,
          LookLocale.code,
        ]),
        builder: (context, _) => MaterialApp(
          title: 'LookVPN',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            // Keep the phone's accessibility scale, then apply the in-app text-size choice.
            final systemScale = media.textScaler.scale(14) / 14;
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  systemScale * state.fontScale.value,
                ),
                disableAnimations:
                    media.disableAnimations || !state.motionEnabled.value,
              ),
              child: Directionality(
                textDirection: LookLocale.direction,
                child: SafeArea(
                  top: false,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          theme: buildTheme(
            Brightness.light,
            state.themeColor.value,
            fontFamily: state.fontFamily.value,
            pageTransition: state.pageTransition.value,
            motionEnabled: state.motionEnabled.value,
          ),
          darkTheme: buildTheme(
            Brightness.dark,
            state.themeColor.value,
            fontFamily: state.fontFamily.value,
            pageTransition: state.pageTransition.value,
            motionEnabled: state.motionEnabled.value,
          ),
          themeMode: state.themeMode.value,
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Opens SetupWizard on first launch (with Skip option), then the Bettbox LookHomeShell.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final needsSetup = AppScope.of(context).needsSetup;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: needsSetup
          ? const SetupWizard(key: ValueKey('setup'))
          : const LookHomeShell(key: ValueKey('home')),
    );
  }
}
