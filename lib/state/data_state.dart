import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_repository.dart';
import '../models/question.dart';
import '../models/sign.dart';
import 'app_state.dart';

final dataRepositoryProvider = Provider<DataRepository>((ref) => DataRepository());

/// Make questionsProvider locale-aware so it invalidates when language changes.
/// This ensures question content updates instantly when locale changes.
/// Questions are loaded from JSON which contains all languages, so we don't
/// need to reload the file - just invalidate so widgets rebuild with new locale.
final questionsProvider = FutureProvider<List<Question>>((ref) {
  // Watch locale changes to invalidate provider when language changes
  // This ensures widgets using questions rebuild with new locale
  // The select() causes provider invalidation when languageCode changes
  ref.watch(appSettingsProvider.select((s) => s.languageCode));
  
  // This will cause the provider to recreate when locale changes
  // The actual questions data is the same (multi-language JSON), but widgets
  // will rebuild and use the correct language via _questionText/_options helpers
  return ref.read(dataRepositoryProvider).loadQuestions();
});

final signsProvider = FutureProvider<List<AppSign>>((ref) {
  // Signs are language-agnostic (images), but watch locale to ensure rebuilds
  // when language changes (for any localized labels/descriptions)
  ref.watch(appSettingsProvider.select((s) => s.languageCode));
  return ref.read(dataRepositoryProvider).loadSigns();
});
