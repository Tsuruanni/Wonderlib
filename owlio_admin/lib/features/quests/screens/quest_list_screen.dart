import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tabs/daily_quests_tab.dart';
import 'tabs/monthly_quests_tab.dart';

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshCurrentTab() {
    if (_tabController.index == 0) {
      ref.invalidate(dailyQuestsProvider);
      ref.invalidate(dailyQuestStatsProvider);
    } else {
      ref.invalidate(monthlyQuestsProvider);
      ref.invalidate(tierBadgesByQuestProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _refreshCurrentTab,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Daily Quests'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Monthly Quests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DailyQuestsTab(),
          MonthlyQuestsTab(),
        ],
      ),
    );
  }
}
