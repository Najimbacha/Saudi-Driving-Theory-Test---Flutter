import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_result_model.dart';
import '../../../models/question.dart';
import '../../../presentation/providers/exam_history_provider.dart';
import '../../../presentation/providers/quiz_provider.dart';
import '../../../state/data_state.dart';
import '../../../state/app_state.dart';
import '../../providers/category_provider.dart';

class PracticeFlowScreen extends ConsumerStatefulWidget {
  const PracticeFlowScreen({super.key});

  @override
  ConsumerState<PracticeFlowScreen> createState() => _PracticeFlowScreenState();
}

class _PracticeFlowScreenState extends ConsumerState<PracticeFlowScreen> {
  bool _handledCompletion = false;
  bool _initialCategoryHandled = false;

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionsProvider);
    final quiz = ref.watch(quizProvider);
    final quizController = ref.read(quizProvider.notifier);
    final categoryParam =
        GoRouterState.of(context).uri.queryParameters['category'];

    return questionsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: Text('quiz.title'.tr())),
        body: Center(child: Text('common.error'.tr())),
      ),
      data: (questions) {
        if (quiz.questions.isEmpty && _handledCompletion) {
          _handledCompletion = false;
        }
        if (quiz.questions.isEmpty) {
          if (categoryParam != null && !_initialCategoryHandled) {
            _initialCategoryHandled = true;
            final filtered = _filterByCategory(questions, categoryParam);
            if (filtered.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('categories.empty'.tr()),
                    backgroundColor: AppColors.secondary,
                  ),
                );
              });
            } else {
              quizController.start(filtered);
              return const SizedBox.shrink();
            }
          }
          return _PracticeSelector(
            onStart: (categoryId) {
              final filtered = _filterByCategory(questions, categoryId);
              quizController.start(filtered);
            },
          );
        }
        if (quiz.isCompleted) {
          if (!_handledCompletion) {
            _handledCompletion = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _finishPractice(context, ref, quiz);
              quizController.reset();
            });
          }
          return const SizedBox.shrink();
        }
        final current = quiz.currentQuestion;
        final locale = context.locale.languageCode;
        final selected = quiz.selectedAnswers[current.id];
        final isCorrect = selected != null && selected == current.correctIndex;
        final questionText = _questionText(current, locale);
        final options = _options(current, locale);
        return Scaffold(
          appBar: AppBar(
            title: Text('quiz.title'.tr()),
            actions: [
              IconButton(
                onPressed: () {
                  ref.read(appSettingsProvider.notifier).toggleFavorite(
                        type: 'questions',
                        id: current.id,
                      );
                },
                icon: Icon(
                  ref
                          .watch(appSettingsProvider)
                          .favorites
                          .questions
                          .contains(current.id)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'quiz.question'.tr()} ${quiz.currentIndex + 1} ${'quiz.of'.tr()} ${quiz.questions.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    questionText,
                    key: ValueKey(current.id),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey('${current.id}-options'),
                    children: List.generate(options.length, (idx) {
                      final optionText = options[idx];
                      final wasSelected = selected == idx;
                      Color? borderColor;
                      Color? fill;
                      if (quiz.showAnswer) {
                        if (idx == current.correctIndex) {
                          fill = AppColors.success.withOpacity(0.15);
                          borderColor = AppColors.success;
                        } else if (wasSelected) {
                          fill = AppColors.error.withOpacity(0.12);
                          borderColor = AppColors.error;
                        }
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: borderColor ?? Colors.transparent),
                          borderRadius: BorderRadius.circular(14),
                          color: fill ?? Theme.of(context).cardColor,
                        ),
                        child: ListTile(
                          title: Text(optionText),
                          onTap: quiz.showAnswer
                              ? null
                              : () => quizController.selectAnswer(idx),
                        ),
                      );
                    }),
                  ),
                ),
                if (quiz.showAnswer) ...[
                  const SizedBox(height: 12),
                  Text(
                    isCorrect ? 'quiz.correct'.tr() : 'quiz.incorrect'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              isCorrect ? AppColors.success : AppColors.error,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _explanation(current, locale),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: quiz.currentIndex == 0
                            ? null
                            : () => quizController.reset(),
                        child: Text('common.cancel'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!quiz.showAnswer) {
                            return;
                          }
                          quizController.next();
                        },
                        child: Text(
                          quiz.currentIndex + 1 == quiz.questions.length
                              ? 'quiz.submit'.tr()
                              : 'common.next'.tr(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _finishPractice(BuildContext context, WidgetRef ref, QuizState quiz) {
    final total = quiz.questions.length;
    final correct = quiz.correctCount;
    final wrong = total - correct;
    final result = ExamResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      examType: 'practice',
      totalQuestions: total,
      correctAnswers: correct,
      wrongAnswers: wrong,
      skippedAnswers: 0,
      scorePercentage: total == 0 ? 0 : (correct / total) * 100,
      passed: correct / total >= 0.7,
      timeTakenSeconds: DateTime.now().difference(quiz.startedAt).inSeconds,
      categoryScores: _categoryScores(quiz),
      questionAnswers: quiz.selectedAnswers.entries
          .map((e) => QuestionAnswer(
                questionId: e.key,
                userAnswerIndex: e.value,
                correctAnswerIndex: quiz.questions
                    .firstWhere((q) => q.id == e.key)
                    .correctIndex,
              ))
          .toList(),
    );
    ref.read(examHistoryProvider.notifier).addResult(result);
    context.push('/results', extra: result);
  }

  static Map<String, int> _categoryScores(QuizState quiz) {
    final scores = <String, int>{};
    for (final entry in quiz.selectedAnswers.entries) {
      final question = quiz.questions.firstWhere((q) => q.id == entry.key);
      final category = question.categoryId;
      if (entry.value == question.correctIndex) {
        scores[category] = (scores[category] ?? 0) + 1;
      }
    }
    return scores;
  }

  static List<Question> _filterByCategory(
      List<Question> questions, String categoryId) {
    if (categoryId == 'all') return questions;
    return questions.where((q) => q.categoryId == categoryId).toList();
  }
}

String _questionText(Question question, String locale) {
  if (locale == 'ar' && question.questionTextAr != null) {
    return question.questionTextAr!;
  }
  if (question.questionText != null) return question.questionText!;
  return question.questionKey.tr();
}

List<String> _options(Question question, String locale) {
  if (locale == 'ar' &&
      question.optionsAr != null &&
      question.optionsAr!.isNotEmpty) {
    return question.optionsAr!;
  }
  if (question.options != null && question.options!.isNotEmpty) {
    return question.options!;
  }
  return question.optionsKeys.map((key) => key.tr()).toList();
}

String _explanation(Question question, String locale) {
  if (locale == 'ar' && question.explanationAr != null) {
    return question.explanationAr!;
  }
  if (question.explanation != null) return question.explanation!;
  return question.explanationKey?.tr() ?? 'quiz.explanationFallback'.tr();
}

class _PracticeSelector extends ConsumerWidget {
  const _PracticeSelector({required this.onStart});

  final void Function(String categoryId) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text('quiz.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('quiz.selectCategory'.tr(),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CategoryPill(
                label: 'quiz.categories.all'.tr(),
                onTap: () => onStart('all'),
              ),
              ...categories.map(
                (cat) => _CategoryPill(
                  label: cat.titleKey.tr(),
                  onTap: () => onStart(cat.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => onStart('all'),
            child: Text('quiz.start'.tr()),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      labelStyle: const TextStyle(color: AppColors.primary),
    );
  }
}
