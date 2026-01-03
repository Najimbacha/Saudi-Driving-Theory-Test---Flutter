import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_result_model.dart';
import '../../../models/question.dart';
import '../../../presentation/providers/exam_history_provider.dart';
import '../../../presentation/providers/exam_provider.dart';
import '../../../state/data_state.dart';
import '../../../utils/back_guard.dart';
import '../../../utils/text_formatters.dart';

class ExamFlowScreen extends ConsumerStatefulWidget {
  const ExamFlowScreen({super.key});

  @override
  ConsumerState<ExamFlowScreen> createState() => _ExamFlowScreenState();
}

class _ExamFlowScreenState extends ConsumerState<ExamFlowScreen> {
  bool _handledCompletion = false;

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionsProvider);
    final exam = ref.watch(examProvider);
    final controller = ref.read(examProvider.notifier);

    return questionsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: Text('exam.title'.tr())),
        body: Center(child: Text('common.error'.tr())),
      ),
      data: (questions) {
        if (exam.questions.isEmpty && _handledCompletion) {
          _handledCompletion = false;
        }
        if (exam.questions.isEmpty || exam.isCompleted) {
          if (exam.isCompleted && exam.questions.isNotEmpty) {
            if (!_handledCompletion) {
              _handledCompletion = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _finishExam(context, ref, exam);
                controller.reset();
              });
            }
            return const SizedBox.shrink();
          }
          return _ExamIntro(
            onStart: (count, minutes, strictMode) =>
                controller.start(
                  (_randomSubset(questions, count)),
                  minutes: minutes,
                  strictMode: strictMode,
                ),
          );
        }
        final current = exam.currentQuestion;
        final locale = context.locale.languageCode;
        final questionText = _questionText(current, locale);
        final options = _options(current, locale);
        final selected = exam.answers[current.id];
        final inProgress = exam.questions.isNotEmpty && !exam.isCompleted;
        return PopScope(
          canPop: !inProgress,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (!inProgress) {
              Navigator.of(context).pop();
              return;
            }
            final shouldExit = await confirmExitExam(context);
            if (shouldExit && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('exam.title'.tr()),
              actions: [
                IconButton(
                  onPressed: controller.toggleFlag,
                  tooltip: 'exam.flag'.tr(),
                  icon: Icon(
                    exam.flagged.contains(current.id) ? Icons.flag : Icons.outlined_flag,
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimerBanner(timeLeftSeconds: exam.timeLeftSeconds),
                const SizedBox(height: 12),
                Semantics(
                  label: formatQuestionOf(
                    context,
                    exam.currentIndex + 1,
                    exam.questions.length,
                  ),
                  child: Text(
                    formatProgress(
                      context,
                      exam.currentIndex + 1,
                      exam.questions.length,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (exam.currentIndex + 1) / exam.questions.length,
                    backgroundColor: Theme.of(context).colorScheme.outline,
                    color: AppColors.primary,
                    minHeight: 8,
                  ),
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected == idx
                                ? AppColors.accent
                                : Colors.transparent,
                          ),
                          color: selected == idx
                              ? AppColors.accent.withValues(alpha: 0.12)
                              : Theme.of(context).cardColor,
                        ),
                        child: ListTile(
                          leading: _OptionBadge(
                            label: String.fromCharCode(65 + idx),
                            active: selected == idx,
                          ),
                          title: Text(optionText),
                          onTap: () => controller.selectAnswer(idx),
                        ),
                      );
                    }),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: exam.strictMode || exam.currentIndex == 0
                            ? null
                            : controller.previous,
                        child: Text('common.previous'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (exam.currentIndex + 1 == exam.questions.length) {
                            controller.finish();
                          } else {
                            controller.next();
                          }
                        },
                        child: Text(exam.currentIndex + 1 == exam.questions.length ? 'exam.submit'.tr() : 'common.next'.tr()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: exam.strictMode && !exam.isCompleted
                      ? null
                      : () => _showQuestionGrid(context, exam, controller),
                  child: Text('exam.reviewAnswers'.tr()),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  void _finishExam(BuildContext context, WidgetRef ref, ExamState exam) {
    final total = exam.questions.length;
    final correct = exam.answers.entries
        .where((e) => exam.questions.firstWhere((q) => q.id == e.key).correctIndex == e.value)
        .length;
    final wrong = exam.answers.length - correct;
    final skipped = total - exam.answers.length;
    final result = ExamResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      examType: 'exam',
      totalQuestions: total,
      correctAnswers: correct,
      wrongAnswers: wrong,
      skippedAnswers: skipped,
      scorePercentage: total == 0 ? 0 : (correct / total) * 100,
      passed: total == 0 ? false : correct / total >= 0.7,
      timeTakenSeconds: DateTime.now().difference(exam.startedAt).inSeconds,
      categoryScores: _categoryScores(exam),
      questionAnswers: exam.answers.entries
          .map((e) => QuestionAnswer(
                questionId: e.key,
                userAnswerIndex: e.value,
                correctAnswerIndex: exam.questions.firstWhere((q) => q.id == e.key).correctIndex,
              ))
          .toList(),
    );
    ref.read(examHistoryProvider.notifier).addResult(result);
    context.push('/results', extra: result);
  }

  static Map<String, int> _categoryScores(ExamState exam) {
    final scores = <String, int>{};
    for (final entry in exam.answers.entries) {
      final question = exam.questions.firstWhere((q) => q.id == entry.key);
      final category = question.categoryId;
      if (entry.value == question.correctIndex) {
        scores[category] = (scores[category] ?? 0) + 1;
      }
    }
    return scores;
  }

  void _showQuestionGrid(BuildContext context, ExamState exam, ExamController controller) {
    if (exam.strictMode && !exam.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('exam.strictModeDesc'.tr())),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: exam.questions.length,
          itemBuilder: (context, index) {
            final question = exam.questions[index];
            final answered = exam.answers.containsKey(question.id);
            final flagged = exam.flagged.contains(question.id);
            Color color = Theme.of(context).cardColor;
            if (flagged) color = AppColors.secondary.withValues(alpha: 0.4);
            if (answered) color = AppColors.success.withValues(alpha: 0.3);
            return InkWell(
              onTap: () {
                controller.goTo(index);
                Navigator.of(context).pop();
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${index + 1}'),
              ),
            );
          },
        );
      },
    );
  }
}

List<Question> _randomSubset(List<Question> questions, int count) {
  final items = List<Question>.from(questions)..shuffle();
  final safeCount = count > items.length ? items.length : count;
  return items.take(safeCount).toList();
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

class _ExamIntro extends StatefulWidget {
  const _ExamIntro({required this.onStart});

  final void Function(int count, int minutes, bool strictMode) onStart;

  @override
  State<_ExamIntro> createState() => _ExamIntroState();
}

class _ExamIntroState extends State<_ExamIntro> {
  final bool _strictMode = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('exam.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.95),
                  AppColors.secondary.withValues(alpha: 0.85),
                ],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'exam.title'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'exam.title'.tr(),
                  style:
                      theme.textTheme.displaySmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'exam.description'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _StatChip(
                      label: 'exam.duration'.tr(),
                      value: '30 ${'exam.minutes'.tr()}',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'exam.questions'.tr(),
                      value: '40',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'exam.passingScore'.tr(),
                      value: '70%',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 20),
          _ModeCard(
            title: 'exam.modes.quick'.tr(),
            description:
                '20 ${'exam.questions'.tr()} • 15 ${'exam.minutes'.tr()}',
            icon: Icons.bolt_outlined,
            onTap: () => _confirmStart(context, 20, 15),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            title: 'exam.modes.standard'.tr(),
            description:
                '30 ${'exam.questions'.tr()} • 20 ${'exam.minutes'.tr()}',
            icon: Icons.dashboard_outlined,
            onTap: () => _confirmStart(context, 30, 20),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            title: 'exam.modes.full'.tr(),
            description:
                '40 ${'exam.questions'.tr()} • 30 ${'exam.minutes'.tr()}',
            icon: Icons.workspace_premium_outlined,
            onTap: () => _confirmStart(context, 40, 30),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStart(BuildContext context, int count, int minutes) async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
          actionsPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.quiz_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'exam.title'.tr(),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          content: Text(
            'exam.disclaimer'.tr(),
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('common.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('exam.startExam'.tr()),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (shouldStart == true) {
      widget.onStart(count, minutes, _strictMode);
    }
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = description.split('•').map((s) => s.trim()).toList();
    final highlight = title.toLowerCase().contains('standard');
    return Semantics(
      button: true,
      label: '$title. $description',
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: highlight ? 0.3 : 0.2),
                        AppColors.secondary.withValues(alpha: highlight ? 0.22 : 0.16),
                      ],
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: parts.map((item) {
                          return Container(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                10, 6, 10, 6),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: highlight ? 0.12 : 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              item,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: highlight ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Icon(Icons.arrow_forward, color: scheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _TimerBanner extends StatelessWidget {
  const _TimerBanner({required this.timeLeftSeconds});

  final int timeLeftSeconds;

  @override
  Widget build(BuildContext context) {
    final minutes = (timeLeftSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (timeLeftSeconds % 60).toString().padLeft(2, '0');
    final totalSeconds = timeLeftSeconds;
    Color color = AppColors.success;
    if (totalSeconds <= 60) {
      color = AppColors.error;
    } else if (totalSeconds <= 300) {
      color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            '$minutes:$seconds',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = active ? AppColors.primary : scheme.outline;
    final fillColor = active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent;
    final textColor = active ? AppColors.primary : scheme.onSurface;
    return Container(
      width: 34,
      height: 34,
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
