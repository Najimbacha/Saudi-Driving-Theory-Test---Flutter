import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_result_model.dart';
import '../../../data/models/category_model.dart';
import '../../../models/question.dart';
import '../../../presentation/providers/exam_history_provider.dart';
import '../../../presentation/providers/quiz_provider.dart';
import '../../../state/data_state.dart';
import '../../../state/app_state.dart';
import '../../providers/category_provider.dart';
import '../../../utils/text_formatters.dart';

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
    final signsAsync = ref.watch(signsProvider);
    final quiz = ref.watch(quizProvider);
    final quizController = ref.read(quizProvider.notifier);
    final categories = ref.watch(categoriesProvider);
    final favorites = ref.watch(appSettingsProvider).favorites;
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
            final availableCategories = categories
                .where((cat) => _filterByCategory(questions, cat.id).isNotEmpty)
                .toList();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              if (filtered.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('categories.empty'.tr()),
                    backgroundColor: AppColors.secondary,
                  ),
                );
              }
            });
            if (filtered.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                quizController.start(filtered);
              });
              return const SizedBox.shrink();
            }
            return _PracticeSelector(
              categories: availableCategories,
              questions: questions,
              onStart: (categoryId) {
                final nextFiltered = _filterByCategory(questions, categoryId);
                if (nextFiltered.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('categories.empty'.tr()),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                  return;
                }
                quizController.start(nextFiltered);
              },
            );
          }
          final availableCategories = categories
              .where((cat) => _filterByCategory(questions, cat.id).isNotEmpty)
              .toList();
          return _PracticeSelector(
            categories: availableCategories,
            questions: questions,
            onStart: (categoryId) {
              final filtered = _filterByCategory(questions, categoryId);
              if (filtered.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('categories.empty'.tr()),
                    backgroundColor: AppColors.secondary,
                  ),
                );
                return;
              }
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
        final signMap = signsAsync.valueOrNull == null
            ? <String, String>{}
            : {for (final s in signsAsync.valueOrNull!) s.id: s.svgPath};
        final signPath = current.signId != null ? signMap[current.signId!] : null;
        final locale = context.locale.languageCode;
        final selected = quiz.selectedAnswers[current.id];
        final isCorrect = selected != null && selected == current.correctIndex;
        final questionText = _questionText(current, locale);
        final options = _options(current, locale);
        final isActiveQuiz = quiz.questions.isNotEmpty && !quiz.isCompleted;
        return PopScope(
          canPop: !isActiveQuiz,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (!isActiveQuiz) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              return;
            }
            // Confirm exit during active quiz
            final shouldExit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('exam.exitTitle'.tr()),
                content: Text('exam.exitMessage'.tr()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('common.cancel'.tr()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('exam.exitConfirm'.tr()),
                  ),
                ],
              ),
            );
            if (shouldExit == true && context.mounted) {
              quizController.reset();
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
          appBar: AppBar(
            title: Text('quiz.title'.tr()),
            actions: [
              _BookmarkButton(
                isBookmarked: favorites.questions.contains(current.id),
                count: favorites.questions.length,
                onTap: () {
                  ref.read(appSettingsProvider.notifier).toggleFavorite(
                        type: 'questions',
                        id: current.id,
                      );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Semantics(
                            label: formatQuestionOf(
                              context,
                              quiz.currentIndex + 1,
                              quiz.questions.length,
                            ),
                            child: Text(
                              '${'quiz.question'.tr()} ${formatProgress(context, quiz.currentIndex + 1, quiz.questions.length)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            current.categoryKey.tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (quiz.currentIndex + 1) / quiz.questions.length,
                          backgroundColor: Theme.of(context).colorScheme.outline,
                          color: AppColors.primary,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          questionText,
                          key: ValueKey(current.id),
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (signPath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.asset(
                                'assets/$signPath',
                                height: 140,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
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
                                fill = AppColors.success.withValues(alpha: 0.15);
                                borderColor = AppColors.success;
                              } else if (wasSelected) {
                                fill = AppColors.error.withValues(alpha: 0.12);
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
                                leading: _OptionBadge(
                                  label: String.fromCharCode(65 + idx),
                                  active: wasSelected,
                                  success: quiz.showAnswer && idx == current.correctIndex,
                                  error: quiz.showAnswer && wasSelected && idx != current.correctIndex,
                                ),
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (quiz.questions.isNotEmpty && !quiz.isCompleted) {
                              // Confirm exit
                              showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('exam.exitTitle'.tr()),
                                  content: Text('exam.exitMessage'.tr()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('common.cancel'.tr()),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(true);
                                      },
                                      child: Text('exam.exitConfirm'.tr()),
                                    ),
                                  ],
                                ),
                              ).then((shouldExit) {
                                if (shouldExit == true && context.mounted) {
                                  quizController.reset();
                                  Navigator.of(context).pop();
                                }
                              });
                            } else {
                              // No active quiz, just go back
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text('common.cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: quiz.showAnswer
                              ? () {
                                  quizController.next();
                                }
                              : null,
                          child: Text(
                            quiz.currentIndex + 1 == quiz.questions.length
                                ? 'quiz.submit'.tr()
                                : 'common.next'.tr(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  // Try current locale embedded text first
  switch (locale) {
    case 'ar':
      if (question.questionTextAr != null) return question.questionTextAr!;
      break;
    case 'ur':
      if (question.questionTextUr != null) return question.questionTextUr!;
      break;
    case 'hi':
      if (question.questionTextHi != null) return question.questionTextHi!;
      break;
    case 'bn':
      if (question.questionTextBn != null) return question.questionTextBn!;
      break;
  }
  // Fallback to English embedded text
  if (question.questionText != null) return question.questionText!;
  // Final fallback to translation key
  return question.questionKey.tr();
}

List<String> _options(Question question, String locale) {
  // Try current locale embedded options first
  List<String>? localeOptions;
  switch (locale) {
    case 'ar':
      localeOptions = question.optionsAr;
      break;
    case 'ur':
      localeOptions = question.optionsUr;
      break;
    case 'hi':
      localeOptions = question.optionsHi;
      break;
    case 'bn':
      localeOptions = question.optionsBn;
      break;
  }
  if (localeOptions != null && localeOptions.isNotEmpty) {
    return localeOptions;
  }
  // Fallback to English embedded options
  if (question.options != null && question.options!.isNotEmpty) {
    return question.options!;
  }
  // Final fallback to translation keys
  return question.optionsKeys.map((key) => key.tr()).toList();
}

String _explanation(Question question, String locale) {
  // Try current locale embedded explanation first
  switch (locale) {
    case 'ar':
      if (question.explanationAr != null) return question.explanationAr!;
      break;
    case 'ur':
      if (question.explanationUr != null) return question.explanationUr!;
      break;
    case 'hi':
      if (question.explanationHi != null) return question.explanationHi!;
      break;
    case 'bn':
      if (question.explanationBn != null) return question.explanationBn!;
      break;
  }
  // Fallback to English embedded explanation
  if (question.explanation != null) return question.explanation!;
  // Final fallback to translation key
  return question.explanationKey?.tr() ?? 'quiz.explanationFallback'.tr();
}

class _PracticeSelector extends StatefulWidget {
  const _PracticeSelector({
    required this.categories,
    required this.questions,
    required this.onStart,
  });

  final List<CategoryModel> categories;
  final List<Question> questions;
  final void Function(String categoryId) onStart;

  @override
  State<_PracticeSelector> createState() => _PracticeSelectorState();
}

class _PracticeSelectorState extends State<_PracticeSelector> {
  String _selectedId = 'all';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = _buildCounts(widget.questions, widget.categories);
    final selectedLabel = _selectedId == 'all'
        ? 'quiz.categories.all'.tr()
        : widget.categories
            .firstWhere(
              (c) => c.id == _selectedId,
              orElse: () => widget.categories.first,
            )
            .titleKey
            .tr();
    final selectedCount = counts[_selectedId] ?? counts['all'] ?? 0;
    final minutes = ((selectedCount * 25) / 60).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text('quiz.title'.tr()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'quiz.selectCategory'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            key: ValueKey(selectedCount),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              'categories.totalQuestions'
                                  .tr(namedArgs: {'value': '$selectedCount'}),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'quiz.selectCategory'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 12) / 2;
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _CategoryTile(
                          width: tileWidth,
                          label: 'quiz.categories.all'.tr(),
                          selected: _selectedId == 'all',
                          onTap: () => _select('all'),
                        ),
                        ...widget.categories.map(
                          (cat) => _CategoryTile(
                            width: tileWidth,
                            label: cat.titleKey.tr(),
                            selected: _selectedId == cat.id,
                            onTap: () => _select(cat.id),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => widget.onStart(_selectedId),
                      child: Text('quiz.start'.tr()),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$selectedCount ${'quiz.question'.tr()} • ~$minutes ${'exam.minutes'.tr()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _select(String id) {
    setState(() => _selectedId = id);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.width,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary.withValues(alpha: 0.12) : scheme.surface;
    final border = selected ? scheme.primary : scheme.outline;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            child: Row(
              children: [
                if (selected)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 18)
                else
                  Icon(Icons.circle_outlined,
                      color: scheme.onSurface.withValues(alpha: 0.5), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, int> _buildCounts(
  List<Question> questions,
  List<CategoryModel> categories,
) {
  final counts = <String, int>{'all': questions.length};
  for (final category in categories) {
    counts[category.id] =
        questions.where((q) => q.categoryId == category.id).length;
  }
  return counts;
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({
    required this.isBookmarked,
    required this.count,
    required this.onTap,
  });

  final bool isBookmarked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'common.bookmark'.tr(),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: Stack(
          alignment: AlignmentDirectional.topEnd,
          children: [
            IconButton(
              onPressed: onTap,
              tooltip: 'common.bookmark'.tr(),
              icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({
    required this.label,
    required this.active,
    required this.success,
    required this.error,
  });

  final String label;
  final bool active;
  final bool success;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color borderColor = scheme.outline;
    Color fillColor = Colors.transparent;
    Color textColor = scheme.onSurface;
    if (active) {
      borderColor = AppColors.primary;
      fillColor = AppColors.primary.withValues(alpha: 0.12);
      textColor = AppColors.primary;
    }
    if (success) {
      borderColor = AppColors.success;
      fillColor = AppColors.success.withValues(alpha: 0.2);
      textColor = AppColors.success;
    }
    if (error) {
      borderColor = AppColors.error;
      fillColor = AppColors.error.withValues(alpha: 0.18);
      textColor = AppColors.error;
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
