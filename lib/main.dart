import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/ad_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  // Get SharedPreferences for Riverpod state management
  // EasyLocalization handles locale persistence via saveLocale: true
  // We read prefs here for other app settings, not for locale
  final prefs = await SharedPreferences.getInstance();

  final adsEnabled = prefs.getBool('adsEnabled') ?? false;
  if (adsEnabled) {
    await AdService.instance.init();
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
          Locale('ur'),
          Locale('hi'),
          Locale('bn'),
        ],
        path: 'assets/i18n',
        fallbackLocale: const Locale('en'),
        // EasyLocalization automatically loads saved locale when saveLocale: true
        // If no saved locale exists, it uses fallbackLocale
        useOnlyLangCode: true,
        saveLocale: true,
        child: const AppRoot(),
      ),
    ),
  );
}
