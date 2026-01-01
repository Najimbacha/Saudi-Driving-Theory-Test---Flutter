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
            onStart: (count, minutes) =>
                controller.start(questions.take(count).toList(), minutes: minutes),
          );
        }
        final current = exam.currentQuestion;
        final locale = context.locale.languageCode;
        final questionText = _questionText(current, locale);
        final options = _options(current, locale);
        final selected = exam.answers[current.id];
        return Scaffold(
          appBar: AppBar(
            title: Text('exam.title'.tr()),
            actions: [
              IconButton(
                onPressed: controller.toggleFlag,
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
                Text('exam.progressCount'.tr(args: [(exam.currentIndex + 1).toString(), exam.questions.length.toString()])),
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
                              ? AppColors.accent.withOpacity(0.12)
                              : Theme.of(context).cardColor,
                        ),
                        child: ListTile(
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
                        onPressed: exam.currentIndex == 0 ? null : controller.previous,
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
                  onPressed: () => _showQuestionGrid(context, exam, controller),
                  child: Text('exam.reviewAnswers'.tr()),
                ),
              ],
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
            if (flagged) color = AppColors.secondary.withOpacity(0.4);
            if (answered) color = AppColors.success.withOpacity(0.3);
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

class _ExamIntro extends StatelessWidget {
  const _ExamIntro({required this.onStart});

  final void Function(int count, int minutes) onStart;

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
                  AppColors.primary.withOpacity(0.9),
                  AppColors.secondary.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'exam.title'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'exam.description'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatChip(
                      label: 'exam.duration'.tr(),
                      value: '30 ${'exam.minutes'.tr()}',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'exam.questions'.tr(),
                      value: '30',
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'exam.disclaimer'.tr(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('exam.selectMode'.tr(), style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _ModeCard(
            title: 'exam.modes.quick'.tr(),
            description: '10 ${'exam.questions'.tr()} • 10 ${'exam.minutes'.tr()}',
            icon: Icons.bolt_outlined,
            onTap: () => onStart(10, 10),
          ),
          _ModeCard(
            title: 'exam.modes.standard'.tr(),
            description: '20 ${'exam.questions'.tr()} • 20 ${'exam.minutes'.tr()}',
            icon: Icons.dashboard_outlined,
            onTap: () => onStart(20, 20),
          ),
          _ModeCard(
            title: 'exam.modes.full'.tr(),
            description: '30 ${'exam.questions'.tr()} • 30 ${'exam.minutes'.tr()}',
            icon: Icons.workspace_premium_outlined,
            onTap: () => onStart(30, 30),
          ),
        ],
      ),
    );
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
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
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
        color: Colors.white.withOpacity(0.18),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined),
          const SizedBox(width: 8),
          Text('$minutes:$seconds', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
