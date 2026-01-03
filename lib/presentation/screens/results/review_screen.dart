import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/exam_result_model.dart';
import '../../../models/question.dart';
import '../../../state/data_state.dart';
import '../../../utils/text_formatters.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.result});

  final ExamResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsProvider);
    final signsAsync = ref.watch(signsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('review.title'.tr())),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text('common.error'.tr())),
        data: (questions) {
          final questionMap = {for (final q in questions) q.id: q};
          final signMap = signsAsync.valueOrNull == null
              ? <String, String>{}
              : {for (final s in signsAsync.valueOrNull!) s.id: s.svgPath};
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: result.questionAnswers.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ReviewHeader(result: result);
              }
              final answer = result.questionAnswers[index - 1];
              final question = questionMap[answer.questionId];
              if (question == null) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('review.missingQuestion'.tr()),
                  ),
                );
              }
              return _ReviewCard(
                index: index,
                question: question,
                answer: answer,
                signPath: question.signId == null ? null : signMap[question.signId!],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.result});

  final ExamResult result;

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final color = passed ? AppColors.success : AppColors.error;
    final accuracy = result.scorePercentage.toStringAsFixed(0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(passed ? Icons.check_circle : Icons.cancel, color: color),
                const SizedBox(width: 8),
                Text(
                  passed ? 'results.passed'.tr() : 'results.failed'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color),
                ),
                const Spacer(),
                Text('$accuracy%',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatCorrectAnswers(
                context,
                result.correctAnswers,
                result.totalQuestions,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate back, which will go to results screen, then user can navigate from there
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.pushReplacement('/home');
                      }
                    },
                    child: Text('results.backHome'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to exam, replacing the review screen
                      context.pushReplacement('/exam');
                    },
                    child: Text('exam.tryAgain'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.signPath,
  });

  final int index;
  final Question question;
  final QuestionAnswer answer;
  final String? signPath;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final questionText = _questionText(question, locale);
    final options = _options(question, locale);
    final correct = answer.correctAnswerIndex;
    final selected = answer.userAnswerIndex;
    final isCorrect = answer.isCorrect;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isCorrect ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$index',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Spacer(),
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? AppColors.success : AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              question.categoryKey.tr(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(questionText, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (signPath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
            ...List.generate(options.length, (idx) {
              final optionText = options[idx];
              final isSelected = idx == selected;
              final isCorrectOption = idx == correct;
              Color? border;
              Color? fill;
              if (isCorrectOption) {
                border = AppColors.success;
                fill = AppColors.success.withValues(alpha: 0.12);
              } else if (isSelected && !isCorrectOption) {
                border = AppColors.error;
                fill = AppColors.error.withValues(alpha: 0.12);
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: fill ?? Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border ?? Colors.transparent),
                ),
                child: ListTile(
                  dense: true,
                  leading: _OptionBadge(
                    label: String.fromCharCode(65 + idx),
                    success: isCorrectOption,
                    error: isSelected && !isCorrectOption,
                  ),
                  title: Text(optionText),
                  trailing: isCorrectOption
                      ? const Icon(Icons.check, color: AppColors.success)
                      : isSelected
                          ? const Icon(Icons.close, color: AppColors.error)
                          : null,
                ),
              );
            }),
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('review.explanation'.tr()),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_explanation(question, locale)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({
    required this.label,
    required this.success,
    required this.error,
  });

  final String label;
  final bool success;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color borderColor = scheme.outline;
    Color fillColor = Colors.transparent;
    Color textColor = scheme.onSurface;
    if (success) {
      borderColor = AppColors.success;
      fillColor = AppColors.success.withValues(alpha: 0.2);
      textColor = AppColors.success;
    } else if (error) {
      borderColor = AppColors.error;
      fillColor = AppColors.error.withValues(alpha: 0.18);
      textColor = AppColors.error;
    }
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
