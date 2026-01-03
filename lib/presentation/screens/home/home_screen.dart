import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/home_shell.dart';
import '../../../state/app_state.dart';
import '../../../state/learning_state.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = ref.watch(appSettingsProvider).stats;
    final learning = ref.watch(learningProvider);

    // Calculate stats
    final totalAnswered = stats.totalAnswered;
    final accuracy = totalAnswered == 0
        ? 0
        : ((stats.totalCorrect / totalAnswered) * 100).round();
    final streak = learning.streak['current'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('home.explore'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () {
              // Profile/settings action
            },
            tooltip: 'home.profile'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Hero Banner Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _HeroBanner(),
              ),
            ),

            // Statistics Cards Row
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _StatsRow(
                  totalAnswered: totalAnswered,
                  accuracy: accuracy,
                  streak: streak,
                ),
              ),
            ),

            // Quick Start Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'home.quickStart'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _QuickActionsRow(
                  onPractice: () {
                    final shell = TabShellScope.maybeOf(context);
                    if (shell != null) {
                      shell.value = 2;
                    } else {
                      context.push('/practice');
                    }
                  },
                  onExam: () {
                    final shell = TabShellScope.maybeOf(context);
                    if (shell != null) {
                      shell.value = 3;
                    } else {
                      context.push('/exam');
                    }
                  },
                ),
              ),
            ),

            // Learning Paths Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'home.learningPaths'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _LearningPathsList(
                  onCategories: () => context.push('/categories'),
                  onSigns: () {
                    final shell = TabShellScope.maybeOf(context);
                    if (shell != null) {
                      shell.value = 1;
                    } else {
                      context.push('/signs');
                    }
                  },
                  onProgress: () => context.push('/stats'),
                  onHistory: () => context.push('/history'),
                ),
              ),
            ),

            const SliverPadding(
              padding: EdgeInsets.only(bottom: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero banner - simpler blue banner matching the image
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'home.greeting'.tr(),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'home.subtitle'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Car icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Badge pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BadgePill(
                icon: Icons.wifi_off_rounded,
                label: 'home.badges.offline'.tr(),
              ),
              _BadgePill(
                icon: Icons.lock_open_rounded,
                label: 'home.badges.noLogin'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge pill component
class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Statistics row - white cards
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalAnswered,
    required this.accuracy,
    required this.streak,
  });

  final int totalAnswered;
  final int accuracy;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.my_library_books_rounded,
            value: totalAnswered.toString(),
            label: 'home.statLabels.questions'.tr(),
            iconColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            value: '$accuracy%',
            label: 'home.statLabels.accuracy'.tr(),
            iconColor: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            value: streak.toString(),
            label: 'home.statLabels.dayStreak'.tr(),
            iconColor: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

/// Individual stat card - white background
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick actions row - two large buttons
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onPractice,
    required this.onExam,
  });

  final VoidCallback onPractice;
  final VoidCallback onExam;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                title: 'home.practice'.tr(),
                subtitle: 'home.practiceSubtitle'.tr(),
                icon: Icons.play_arrow_rounded,
                gradient: AppColors.primaryGradient,
                onTap: onPractice,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                title: 'home.mockExam'.tr(),
                subtitle: 'home.mockExamSubtitle'.tr(),
                icon: Icons.description_rounded,
                gradient: AppColors.secondaryGradient,
                onTap: onExam,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quick action button - larger, cleaner design
class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Learning paths list - vertical list cards
class _LearningPathsList extends StatelessWidget {
  const _LearningPathsList({
    required this.onCategories,
    required this.onSigns,
    required this.onProgress,
    required this.onHistory,
  });

  final VoidCallback onCategories;
  final VoidCallback onSigns;
  final VoidCallback onProgress;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LearningPathCard(
          title: 'home.practiceByCategory'.tr(),
          subtitle: 'home.practiceByCategoryDesc'.tr(),
          icon: Icons.folder_rounded,
          iconColor: AppColors.primary,
          onTap: onCategories,
        ),
        const SizedBox(height: 12),
        _LearningPathCard(
          title: 'home.learnSigns'.tr(),
          subtitle: 'home.learnSignsDesc'.tr(),
          icon: Icons.signpost_rounded,
          iconColor: AppColors.success,
          onTap: onSigns,
        ),
        const SizedBox(height: 12),
        _LearningPathCard(
          title: 'home.stats'.tr(),
          subtitle: 'home.statsDesc'.tr(),
          icon: Icons.insights_rounded,
          iconColor: AppColors.tertiary,
          onTap: onProgress,
        ),
        const SizedBox(height: 12),
        _LearningPathCard(
          title: 'home.history'.tr(),
          subtitle: 'home.historyDesc'.tr(),
          icon: Icons.history_rounded,
          iconColor: AppColors.accent,
          onTap: onHistory,
        ),
      ],
    );
  }
}

/// Learning path card - list style with icon, text, arrow
class _LearningPathCard extends StatefulWidget {
  const _LearningPathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<_LearningPathCard> createState() => _LearningPathCardState();
}

class _LearningPathCardState extends State<_LearningPathCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: scheme.onSurface.withValues(alpha: 0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
