import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/category_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _controller = TextEditingController();
  int _selectedFilter = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final query = _controller.text.trim().toLowerCase();
    final visible = categories.where((cat) {
      final title = cat.titleKey.tr().toLowerCase();
      return query.isEmpty || title.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('categories.title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'categories.search'.tr(),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'categories.filterAll'.tr(),
                selected: _selectedFilter == 0,
                onTap: () => setState(() => _selectedFilter = 0),
              ),
              _FilterChip(
                label: 'categories.filterInProgress'.tr(),
                selected: _selectedFilter == 1,
                onTap: () => setState(() => _selectedFilter = 1),
              ),
              _FilterChip(
                label: 'categories.filterCompleted'.tr(),
                selected: _selectedFilter == 2,
                onTap: () => setState(() => _selectedFilter = 2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final category = visible[index];
              return _CategoryCard(
                title: category.titleKey.tr(),
                subtitle: category.subtitleKey.tr(),
                color: _parseColor(category.colorHex),
                icon: _iconFor(category.iconName),
                total: category.totalQuestions,
                onTap: () => context.go('/practice?category=${category.id}'),
              );
            },
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String name) {
    switch (name) {
      case 'traffic':
        return Icons.traffic_outlined;
      case 'rules':
        return Icons.rule_outlined;
      case 'safety':
        return Icons.health_and_safety_outlined;
      case 'signals':
        return Icons.traffic_outlined;
      case 'markings':
        return Icons.linear_scale_outlined;
      case 'parking':
        return Icons.local_parking_outlined;
      case 'emergency':
        return Icons.warning_amber_outlined;
      case 'pedestrians':
        return Icons.directions_walk_outlined;
      case 'highway':
        return Icons.route_outlined;
      case 'weather':
        return Icons.cloud_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      case 'responsibilities':
        return Icons.assignment_ind_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  static Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withOpacity(0.2),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.total,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                'categories.totalQuestions'.tr(args: [total.toString()]),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
