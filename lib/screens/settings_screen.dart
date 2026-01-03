import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ad_service.dart';
import '../state/app_state.dart';
import '../widgets/banner_ad_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _getThemeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'settings.themes.light'.tr();
      case ThemeMode.dark:
        return 'settings.themes.dark'.tr();
      case ThemeMode.system:
        return 'settings.themes.system'.tr();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // DEBUG: Show current locale for verification
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Locale: ${context.locale.languageCode}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: Text('settings.language'.tr()),
            subtitle: Text('settings.languages.${settings.languageCode}'.tr()),
            onTap: () {
              showModalBottomSheet<String>(
                context: context,
                builder: (context) => _LanguageSheet(current: settings.languageCode),
              );
              // Language change is handled inside _LanguageSheet for instant update
            },
          ),
          ListTile(
            title: Text('settings.theme'.tr()),
            subtitle: Text(_getThemeName(context, settings.themeMode)),
            onTap: () async {
              final mode = await showModalBottomSheet<ThemeMode>(
                context: context,
                builder: (context) => _ThemeSheet(current: settings.themeMode),
              );
              if (!context.mounted) return;
              if (mode != null) {
                notifier.setThemeMode(mode);
              }
            },
          ),
          SwitchListTile(
            value: settings.soundEnabled,
            onChanged: notifier.setSoundEnabled,
            title: Text('settings.sound'.tr()),
          ),
          SwitchListTile(
            value: settings.vibrationEnabled,
            onChanged: notifier.setVibrationEnabled,
            title: Text('settings.vibration'.tr()),
          ),
          SwitchListTile(
            value: settings.adsEnabled,
            onChanged: (value) async {
              if (value) {
                await AdService.instance.init();
              }
              notifier.setAdsEnabled(value);
            },
            title: Text('settings.ads'.tr()),
            subtitle: Text('settings.adsDesc'.tr()),
          ),
          const SizedBox(height: 12),
          if (settings.adsEnabled) const Center(child: BannerAdWidget()),
        ],
      ),
    );
  }
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const codes = ['en', 'ar', 'ur', 'hi', 'bn'];
    final notifier = ref.read(appSettingsProvider.notifier);
    
    return SafeArea(
      child: ListView(
        children: codes
            .map(
              (code) => ListTile(
                title: Text('settings.languages.$code'.tr()),
                trailing: current == code ? const Icon(Icons.check) : null,
                onTap: () async {
                  // Update EasyLocalization runtime locale - this updates context.locale immediately
                  // MaterialApp uses context.locale, so it will rebuild with new locale
                  // EasyLocalization handles persistence via saveLocale: true
                  await context.setLocale(Locale(code));
                  
                  // Update Riverpod state to sync with EasyLocalization
                  // This triggers AppRoot rebuild via ref.watch(appSettingsProvider)
                  notifier.setLanguage(code);
                  
                  // Close bottom sheet
                  if (context.mounted) {
                    Navigator.pop(context, code);
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.current});

  final ThemeMode current;

  String _getThemeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'settings.themes.light'.tr();
      case ThemeMode.dark:
        return 'settings.themes.dark'.tr();
      case ThemeMode.system:
        return 'settings.themes.system'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    const modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    return SafeArea(
      child: ListView(
        children: modes
            .map(
              (mode) => ListTile(
                title: Text(_getThemeName(context, mode)),
                trailing: current == mode ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, mode),
              ),
            )
            .toList(),
      ),
    );
  }
}
