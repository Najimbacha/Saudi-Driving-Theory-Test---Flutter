import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/routes/app_router.dart';
import 'state/app_state.dart';

/// Root Cause: MaterialApp.locale was bound to settings state, but EasyLocalization
/// context wasn't updating synchronously, causing a delay. Also, questionsProvider
/// wasn't invalidating on locale change, so question content stayed in old language.
///
/// Fix: Update EasyLocalization context before state update, use ValueKey to force
/// MaterialApp rebuild, and make questionsProvider locale-aware.
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  bool _hasSyncedLocale = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(sharedPrefsProvider);
    final router = ref.watch(appRouterProvider);

    final settings = ref.watch(appSettingsProvider);

    // Sync Riverpod state with EasyLocalization's saved locale on first build
    // This ensures both systems start in sync (EasyLocalization loads saved locale automatically)
    if (!_hasSyncedLocale) {
      _hasSyncedLocale = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final easyLocale = context.locale.languageCode;
          if (easyLocale != settings.languageCode) {
            // Update Riverpod state to match EasyLocalization's saved locale
            ref.read(appSettingsProvider.notifier).setLanguage(easyLocale);
          }
        }
      });
    }

    return MaterialApp.router(
      // Force complete rebuild when locale changes - ensures all widgets rebuild
      // ValueKey changes when settings.languageCode changes, forcing MaterialApp rebuild
      key: ValueKey('locale_${settings.languageCode}'),
      title: 'app.name'.tr(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      // MaterialApp uses context.locale from EasyLocalization's InheritedWidget
      // When context.setLocale() is called, EasyLocalization updates its InheritedWidget,
      // which causes MaterialApp to rebuild because it depends on context.locale
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
    );
  }
}
