import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';
import '../dashboard/dashboard_controller.dart';

class DailyTrackingScreen extends ConsumerStatefulWidget {
  const DailyTrackingScreen({super.key});

  @override
  ConsumerState<DailyTrackingScreen> createState() =>
      _DailyTrackingScreenState();
}

class _DailyTrackingScreenState extends ConsumerState<DailyTrackingScreen> {
  late Future<Map<String, dynamic>> _tracking;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tracking = ref.read(nutritionRepositoryProvider).dailyTracking();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Daily tracking',
      actions: [
        IconButton(
          tooltip: 'Reminder settings',
          icon: const Icon(Icons.notifications_active_outlined),
          onPressed: _openReminders,
        ),
      ],
      body: FutureBuilder<Map<String, dynamic>>(
        future: _tracking,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorPanel(
              message: friendlyErrorMessage(snapshot.error!),
              onRetry: _reload,
            );
          }
          final data = snapshot.data ?? const {};
          final water = _number(data['water_ml']);
          final waterTarget = _number(data['water_target_ml'], fallback: 2500);
          final steps = _number(data['steps']).round();
          final minutes = _number(data['duration_minutes']).round();
          final calories = _number(data['calories_burned']);
          final activities = data['activities'] as List<dynamic>? ?? const [];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NovaSpacing.lg,
                NovaSpacing.lg,
                NovaSpacing.lg,
                120,
              ),
              children: [
                const PageIntro(
                  title: 'Keep today in one place',
                  subtitle: 'Water, steps, and workouts update your dashboard.',
                  icon: Icons.track_changes_outlined,
                ),
                const SizedBox(height: NovaSpacing.lg),
                NovaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Water',
                        action: Text(
                          '${water.toStringAsFixed(0)} / ${waterTarget.toStringAsFixed(0)} ml',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: NovaSpacing.md),
                      LinearProgressIndicator(
                        minHeight: 10,
                        value: waterTarget <= 0
                            ? 0
                            : (water / waterTarget).clamp(0, 1),
                        color: NovaColors.blue,
                        backgroundColor: NovaColors.panelSoft,
                      ),
                      const SizedBox(height: NovaSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: NovaButton.secondary(
                              label: '+250 ml',
                              icon: Icons.water_drop_outlined,
                              onPressed: _busy ? null : () => _addWater(250),
                            ),
                          ),
                          const SizedBox(width: NovaSpacing.md),
                          Expanded(
                            child: NovaButton.primary(
                              label: '+500 ml',
                              icon: Icons.water_drop,
                              onPressed: _busy ? null : () => _addWater(500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NovaSpacing.lg),
                NutritionMetricGrid(
                  items: [
                    NutritionMetricItem(
                      label: 'Steps',
                      value: '$steps',
                      icon: Icons.directions_walk,
                      color: NovaColors.mint,
                    ),
                    NutritionMetricItem(
                      label: 'Workout',
                      value: '$minutes min',
                      icon: Icons.fitness_center,
                      color: NovaColors.coral,
                    ),
                    NutritionMetricItem(
                      label: 'Exercise',
                      value: '${calories.toStringAsFixed(0)} kcal',
                      icon: Icons.local_fire_department_outlined,
                      color: NovaColors.gold,
                    ),
                  ],
                ),
                const SizedBox(height: NovaSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: NovaButton.secondary(
                        label: 'Log steps',
                        icon: Icons.directions_walk,
                        onPressed: _busy ? null : () => _openActivity('steps'),
                      ),
                    ),
                    const SizedBox(width: NovaSpacing.md),
                    Expanded(
                      child: NovaButton.primary(
                        label: 'Log workout',
                        icon: Icons.fitness_center,
                        onPressed:
                            _busy ? null : () => _openActivity('workout'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NovaSpacing.lg),
                NovaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Today activity'),
                      const SizedBox(height: NovaSpacing.sm),
                      if (activities.isEmpty)
                        const EmptyState(
                          title: 'Nothing logged yet',
                          message: 'Add steps or a workout when you are ready.',
                          icon: Icons.fitness_center_outlined,
                        )
                      else
                        for (final raw in activities)
                          _ActivityRow(
                            item: Map<String, dynamic>.from(raw as Map),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addWater(int amount) async {
    await _mutate(() => ref.read(nutritionRepositoryProvider).addWater(amount));
  }

  Future<void> _openActivity(String type) async {
    final title = TextEditingController();
    final value = TextEditingController();
    final calories = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NovaColors.panel,
      builder: (context) {
        final inset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, inset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: type == 'steps' ? 'Log steps' : 'Log workout',
              ),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText:
                      type == 'steps' ? 'Walk name (optional)' : 'Workout',
                ),
              ),
              const SizedBox(height: NovaSpacing.md),
              TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: type == 'steps' ? 'Steps' : 'Duration minutes',
                ),
              ),
              if (type == 'workout') ...[
                const SizedBox(height: NovaSpacing.md),
                TextField(
                  controller: calories,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calories burned (optional)',
                  ),
                ),
              ],
              const SizedBox(height: NovaSpacing.lg),
              NovaButton.primary(
                label: 'Save',
                icon: Icons.check,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true) return;
    final number = int.tryParse(value.text) ?? 0;
    if (number <= 0) return;
    await _mutate(
      () => ref.read(nutritionRepositoryProvider).addActivity({
        'activity_type': type,
        'title': title.text.trim(),
        if (type == 'steps') 'steps': number,
        if (type == 'workout') 'duration_minutes': number,
        if (type == 'workout')
          'calories_burned': double.tryParse(calories.text) ?? 0,
      }),
    );
    title.dispose();
    value.dispose();
    calories.dispose();
  }

  Future<void> _openReminders() async {
    try {
      final current =
          await ref.read(nutritionRepositoryProvider).reminderPreferences();
      if (!mounted) return;
      var meals = current['meal_reminders'] == true;
      var water = current['water_reminders'] == true;
      var habits = current['habit_reminders'] == true;
      var weight = current['weight_reminders'] == true;
      var weekly = current['weekly_report'] != false;
      final payload = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        backgroundColor: NovaColors.panel,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SectionHeader(title: 'Reminder plan'),
                  SwitchListTile(
                    value: meals,
                    onChanged: (value) => setModalState(() => meals = value),
                    title: const Text('Meal reminders'),
                  ),
                  SwitchListTile(
                    value: water,
                    onChanged: (value) => setModalState(() => water = value),
                    title: const Text('Water reminders'),
                  ),
                  SwitchListTile(
                    value: habits,
                    onChanged: (value) => setModalState(() => habits = value),
                    title: const Text('Habit reminders'),
                  ),
                  SwitchListTile(
                    value: weight,
                    onChanged: (value) => setModalState(() => weight = value),
                    title: const Text('Weekly weight reminder'),
                  ),
                  SwitchListTile(
                    value: weekly,
                    onChanged: (value) => setModalState(() => weekly = value),
                    title: const Text('Weekly report'),
                  ),
                  NovaButton.primary(
                    label: 'Save preferences',
                    icon: Icons.check,
                    onPressed: () => Navigator.of(context).pop({
                      'meal_reminders': meals,
                      'water_reminders': water,
                      'habit_reminders': habits,
                      'weight_reminders': weight,
                      'weekly_report': weekly,
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (payload != null) {
        await ref
            .read(nutritionRepositoryProvider)
            .updateReminderPreferences(payload);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(dashboardProvider);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _tracking = ref.read(nutritionRepositoryProvider).dailyTracking();
    });
    await _tracking;
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final isSteps = item['activity_type'] == 'steps';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSteps ? Icons.directions_walk : Icons.fitness_center,
        color: isSteps ? NovaColors.mint : NovaColors.coral,
      ),
      title: Text(
        item['title']?.toString().isNotEmpty == true
            ? item['title'].toString()
            : isSteps
                ? 'Steps'
                : 'Workout',
      ),
      subtitle: Text(
        isSteps
            ? '${item['steps']} steps'
            : '${item['duration_minutes']} minutes - ${item['calories_burned']} kcal',
      ),
    );
  }
}

double _number(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
