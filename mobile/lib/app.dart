import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/auth/mode_router.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

/// Root widget of the Operion Mobile application.
class OperionMobileApp extends StatelessWidget {
  const OperionMobileApp({super.key, this.container});

  /// The app-wide [ProviderContainer] created in `main()` and shared with the
  /// Phase 5A OS-integration services (push, quick actions, widgets).
  ///
  /// When `null` (tests), a fresh [ProviderScope] is created internally.
  final ProviderContainer? container;

  @override
  Widget build(BuildContext context) {
    return container == null
        ? const ProviderScope(
            child: _OperionMobileApp(),
          )
        : UncontrolledProviderScope(
            container: container!,
            child: const _OperionMobileApp(),
          );
  }
}

/// Internal Riverpod-aware app widget.
class _OperionMobileApp extends ConsumerWidget {
  const _OperionMobileApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Operion Mobile',
      debugShowCheckedModeBanner: false,
      // Phase 5A: OS services (quick actions, notification actions) push
      // screens without a BuildContext via this key.
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ModeRouter(),
    );
  }
}
