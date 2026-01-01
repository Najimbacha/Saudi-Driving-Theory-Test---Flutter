import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TrafficViolationPointsScreen extends StatelessWidget {
  const TrafficViolationPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('violationPoints.title'.tr()),
          bottom: TabBar(
            tabs: [
              Tab(text: 'violationPoints.severeTab'.tr()),
              Tab(text: 'violationPoints.majorTab'.tr()),
              Tab(text: 'violationPoints.minorTab'.tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ViolationList(
              title: 'violationPoints.severeTitle'.tr(),
              items: _severeViolations,
            ),
            _ViolationList(
              title: 'violationPoints.majorTitle'.tr(),
              items: _majorViolations,
            ),
            _ViolationList(
              title: 'violationPoints.minorTitle'.tr(),
              items: _minorViolations,
            ),
          ],
        ),
      ),
    );
  }
}

class _ViolationList extends StatelessWidget {
  const _ViolationList({required this.title, required this.items});

  final String title;
  final List<_ViolationItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('violationPoints.summaryTitle'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('violationPoints.summaryLine1'.tr()),
                Text('violationPoints.summaryLine2'.tr()),
                Text('violationPoints.summaryLine3'.tr()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Card(
            child: ListTile(
              title: Text('violations.${item.id}'.tr()),
              subtitle: Text(
                'violationPoints.pointsLabel'.tr(args: [item.points.toString()]),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('violationPoints.tipBody'.tr(),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ViolationItem {
  const _ViolationItem({required this.id, required this.points});

  final String id;
  final int points;
}

const _severeViolations = [
  _ViolationItem(id: 'v01', points: 24),
  _ViolationItem(id: 'v02', points: 24),
  _ViolationItem(id: 'v03', points: 12),
  _ViolationItem(id: 'v04', points: 12),
];

const _majorViolations = [
  _ViolationItem(id: 'v05', points: 8),
  _ViolationItem(id: 'v06', points: 6),
  _ViolationItem(id: 'v07', points: 6),
  _ViolationItem(id: 'v08', points: 6),
];

const _minorViolations = [
  _ViolationItem(id: 'v09', points: 4),
  _ViolationItem(id: 'v10', points: 4),
  _ViolationItem(id: 'v11', points: 4),
  _ViolationItem(id: 'v12', points: 2),
  _ViolationItem(id: 'v13', points: 2),
];
