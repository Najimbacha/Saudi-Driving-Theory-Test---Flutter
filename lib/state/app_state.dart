import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStats {
  const AppStats({
    required this.quizzesTaken,
    required this.bestScore,
    required this.totalCorrect,
    required this.totalAnswered,
    required this.totalScore,
  });

  final int quizzesTaken;
  final int bestScore;
  final int totalCorrect;
  final int totalAnswered;
  final int totalScore;

  AppStats copyWith({
    int? quizzesTaken,
    int? bestScore,
    int? totalCorrect,
    int? totalAnswered,
    int? totalScore,
  }) {
    return AppStats(
      quizzesTaken: quizzesTaken ?? this.quizzesTaken,
      bestScore: bestScore ?? this.bestScore,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalAnswered: totalAnswered ?? this.totalAnswered,
      totalScore: totalScore ?? this.totalScore,
    );
  }

  Map<String, dynamic> toJson() => {
        'quizzesTaken': quizzesTaken,
        'bestScore': bestScore,
        'totalCorrect': totalCorrect,
        'totalAnswered': totalAnswered,
        'totalScore': totalScore,
      };

  static AppStats fromJson(Map<String, dynamic> json) => AppStats(
        quizzesTaken: json['quizzesTaken'] ?? 0,
        bestScore: json['bestScore'] ?? 0,
        totalCorrect: json['totalCorrect'] ?? 0,
        totalAnswered: json['totalAnswered'] ?? 0,
        totalScore: json['totalScore'] ?? 0,
      );
}

class Favorites {
  const Favorites({
    required this.questions,
    required this.signs,
  });

  final List<String> questions;
  final List<String> signs;

  Map<String, dynamic> toJson() => {
        'questions': questions,
        'signs': signs,
      };

  static Favorites fromJson(Map<String, dynamic> json) => Favorites(
        questions: List<String>.from(json['questions'] ?? const []),
        signs: List<String>.from(json['signs'] ?? const []),
      );
}

class AppSettingsState {
  const AppSettingsState({
    required this.languageCode,
    required this.themeMode,
    required this.hasSeenOnboarding,
    required this.favorites,
    required this.stats,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.adsEnabled,
  });

  final String languageCode;
  final ThemeMode themeMode;
  final bool hasSeenOnboarding;
  final Favorites favorites;
  final AppStats stats;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool adsEnabled;

  AppSettingsState copyWith({
    String? languageCode,
    ThemeMode? themeMode,
    bool? hasSeenOnboarding,
    Favorites? favorites,
    AppStats? stats,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? adsEnabled,
  }) {
    return AppSettingsState(
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      favorites: favorites ?? this.favorites,
      stats: stats ?? this.stats,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      adsEnabled: adsEnabled ?? this.adsEnabled,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier(this._prefs)
      : super(
          AppSettingsState(
            languageCode: _prefs.getString('language') ?? 'en',
            themeMode: _parseTheme(_prefs.getString('theme')),
            hasSeenOnboarding: _prefs.getString('hasSeenOnboarding') == 'true',
            favorites: _loadFavorites(_prefs),
            stats: _loadStats(_prefs),
            soundEnabled: _prefs.getString('soundEnabled') != 'false',
            vibrationEnabled: _prefs.getString('vibrationEnabled') != 'false',
            adsEnabled: _prefs.getBool('adsEnabled') ?? false,
          ),
        );

  final SharedPreferences _prefs;

  static ThemeMode _parseTheme(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static Favorites _loadFavorites(SharedPreferences prefs) {
    final raw = prefs.getString('favorites');
    if (raw == null) {
      return const Favorites(questions: [], signs: []);
    }
    try {
      return Favorites.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      return const Favorites(questions: [], signs: []);
    }
  }

  static AppStats _loadStats(SharedPreferences prefs) {
    final raw = prefs.getString('stats');
    if (raw == null) {
      return const AppStats(
        quizzesTaken: 0,
        bestScore: 0,
        totalCorrect: 0,
        totalAnswered: 0,
        totalScore: 0,
      );
    }
    try {
      return AppStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      return const AppStats(
        quizzesTaken: 0,
        bestScore: 0,
        totalCorrect: 0,
        totalAnswered: 0,
        totalScore: 0,
      );
    }
  }

  void setLanguage(String code) {
    // Update SharedPreferences for non-localization use (e.g., analytics, logging)
    // EasyLocalization handles its own persistence via saveLocale: true
    _prefs.setString('language', code);
    state = state.copyWith(languageCode: code);
  }

  void setThemeMode(ThemeMode mode) {
    final value = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.system
            ? 'system'
            : 'light';
    _prefs.setString('theme', value);
    state = state.copyWith(themeMode: mode);
  }

  void setHasSeenOnboarding(bool seen) {
    _prefs.setString('hasSeenOnboarding', seen.toString());
    state = state.copyWith(hasSeenOnboarding: seen);
  }

  void setSoundEnabled(bool enabled) {
    _prefs.setString('soundEnabled', enabled.toString());
    state = state.copyWith(soundEnabled: enabled);
  }

  void setVibrationEnabled(bool enabled) {
    _prefs.setString('vibrationEnabled', enabled.toString());
    state = state.copyWith(vibrationEnabled: enabled);
  }

  void setAdsEnabled(bool enabled) {
    _prefs.setBool('adsEnabled', enabled);
    state = state.copyWith(adsEnabled: enabled);
  }

  void toggleFavorite({required String type, required String id}) {
    final current = state.favorites;
    final list = type == 'questions' ? current.questions : current.signs;
    final nextList = list.contains(id) ? list.where((i) => i != id).toList() : [...list, id];
    final nextFavorites = type == 'questions'
        ? Favorites(questions: nextList, signs: current.signs)
        : Favorites(questions: current.questions, signs: nextList);
    _prefs.setString('favorites', jsonEncode(nextFavorites.toJson()));
    state = state.copyWith(favorites: nextFavorites);
  }

  void updateStats({required int correct, required int total}) {
    final score = ((correct / total) * 100).round();
    final stats = state.stats.copyWith(
      quizzesTaken: state.stats.quizzesTaken + 1,
      bestScore: score > state.stats.bestScore ? score : state.stats.bestScore,
      totalCorrect: state.stats.totalCorrect + correct,
      totalAnswered: state.stats.totalAnswered + total,
      totalScore: state.stats.totalScore + score,
    );
    _prefs.setString('stats', jsonEncode(stats.toJson()));
    state = state.copyWith(stats: stats);
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main()');
});

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return AppSettingsNotifier(prefs);
});
