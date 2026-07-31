import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';

class FriendsBetaScreen extends ConsumerStatefulWidget {
  const FriendsBetaScreen({super.key});

  @override
  ConsumerState<FriendsBetaScreen> createState() => _FriendsBetaScreenState();
}

class _FriendsBetaScreenState extends ConsumerState<FriendsBetaScreen> {
  late Future<List<Map<String, dynamic>>> _groups;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _groups = ref.read(nutritionRepositoryProvider).friendGroups();
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Friends beta',
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _groups,
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
          final groups = snapshot.data ?? const [];
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
                  title: 'Small, private friend groups',
                  subtitle:
                      'Share challenges, recipes, and groceries - not meals or body data.',
                  icon: Icons.groups_2_outlined,
                ),
                const SizedBox(height: NovaSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: NovaButton.primary(
                        label: 'Create group',
                        icon: Icons.group_add_outlined,
                        onPressed: _busy ? null : _createGroup,
                      ),
                    ),
                    const SizedBox(width: NovaSpacing.md),
                    Expanded(
                      child: NovaButton.secondary(
                        label: 'Join code',
                        icon: Icons.key_outlined,
                        onPressed: _busy ? null : _joinGroup,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NovaSpacing.lg),
                if (groups.isEmpty)
                  const NovaCard(
                    child: EmptyState(
                      title: 'No friend group yet',
                      message:
                          'Create one and share its invite code, or join a friend.',
                      icon: Icons.groups_outlined,
                    ),
                  )
                else
                  for (final group in groups) ...[
                    _GroupCard(
                      group: group,
                      busy: _busy,
                      onChallenge: () => _setChallenge(group),
                      onChallengeCount: (count) =>
                          _setChallengeCount(group, count),
                      onAddGrocery: () => _addGrocery(group),
                      onToggleGrocery: (item, checked) =>
                          _toggleGrocery(item, checked),
                      onShareRecipe: () => _shareRecipe(group),
                    ),
                    const SizedBox(height: NovaSpacing.lg),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = await _textDialog(
      title: 'Create friend group',
      label: 'Group name',
      action: 'Create',
    );
    if (name == null || name.isEmpty) return;
    await _mutate(
        () => ref.read(nutritionRepositoryProvider).createFriendGroup(name));
  }

  Future<void> _joinGroup() async {
    final code = await _textDialog(
      title: 'Join friend group',
      label: 'Invite code',
      action: 'Join',
    );
    if (code == null || code.isEmpty) return;
    await _mutate(
      () => ref.read(nutritionRepositoryProvider).joinFriendGroup(code),
    );
  }

  Future<void> _setChallenge(Map<String, dynamic> group) async {
    final title = await _textDialog(
      title: 'Weekly challenge',
      label: 'Challenge, e.g. Log breakfast',
      action: 'Set challenge',
    );
    if (title == null || title.isEmpty) return;
    await _mutate(
      () => ref.read(nutritionRepositoryProvider).createGroupChallenge(
        group['id'].toString(),
        {
          'title': title,
          'week_start': _date(DateTime.now()),
          'target_count': 7,
        },
      ),
    );
  }

  Future<void> _setChallengeCount(
    Map<String, dynamic> group,
    int count,
  ) async {
    final challenge = group['challenge'] as Map?;
    if (challenge == null) return;
    await _mutate(
      () => ref.read(nutritionRepositoryProvider).checkGroupChallenge(
            group['id'].toString(),
            challenge['id'].toString(),
            count,
          ),
    );
  }

  Future<void> _addGrocery(Map<String, dynamic> group) async {
    final name = await _textDialog(
      title: 'Shared grocery list',
      label: 'Item name',
      action: 'Add',
    );
    if (name == null || name.isEmpty) return;
    await _mutate(
      () => ref.read(nutritionRepositoryProvider).addGroupGroceryItem(
        group['id'].toString(),
        {'name': name, 'quantity': 1, 'unit': 'item'},
      ),
    );
  }

  Future<void> _toggleGrocery(Map<String, dynamic> item, bool checked) async {
    await _mutate(
      () => ref.read(nutritionRepositoryProvider).updateGroupGroceryItem(
        item['id'].toString(),
        {'is_checked': checked},
      ),
    );
  }

  Future<void> _shareRecipe(Map<String, dynamic> group) async {
    try {
      final recipes = await ref.read(nutritionRepositoryProvider).recipes();
      if (!mounted) return;
      if (recipes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a recipe first.')),
        );
        return;
      }
      final recipeId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: NovaColors.panel,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(NovaSpacing.lg),
            children: [
              const SectionHeader(title: 'Share a recipe'),
              for (final recipe in recipes)
                ListTile(
                  title: Text(recipe['name']?.toString() ?? 'Recipe'),
                  subtitle: Text('${recipe['servings']} servings'),
                  trailing: const Icon(Icons.share_outlined),
                  onTap: () =>
                      Navigator.of(context).pop(recipe['id'].toString()),
                ),
            ],
          ),
        ),
      );
      if (recipeId == null) return;
      await _mutate(
        () => ref.read(nutritionRepositoryProvider).shareGroupRecipe(
              group['id'].toString(),
              recipeId,
            ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    }
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    required String action,
  }) async {
    var currentValue = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          onChanged: (value) => currentValue = value,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(currentValue.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<void> _mutate(Future<Object?> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
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
      _groups = ref.read(nutritionRepositoryProvider).friendGroups();
    });
    await _groups;
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.busy,
    required this.onChallenge,
    required this.onChallengeCount,
    required this.onAddGrocery,
    required this.onToggleGrocery,
    required this.onShareRecipe,
  });

  final Map<String, dynamic> group;
  final bool busy;
  final VoidCallback onChallenge;
  final ValueChanged<int> onChallengeCount;
  final VoidCallback onAddGrocery;
  final void Function(Map<String, dynamic>, bool) onToggleGrocery;
  final VoidCallback onShareRecipe;

  @override
  Widget build(BuildContext context) {
    final members = group['members'] as List<dynamic>? ?? const [];
    final challenge = group['challenge'] as Map?;
    final groceries = group['grocery_items'] as List<dynamic>? ?? const [];
    final recipes = group['recipes'] as List<dynamic>? ?? const [];
    final count = _int(challenge?['my_completed_count']);
    final target = _int(challenge?['target_count'], fallback: 7);
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: group['name']?.toString() ?? 'Friend group',
            action: NovaBadge(
              label: '${members.length} friends',
              color: NovaColors.blue,
            ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          SelectableText(
            'Invite code: ${group['invite_code']}',
            style: const TextStyle(
              color: NovaColors.mint,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: NovaSpacing.sm),
          Text(
            group['privacy_note']?.toString() ?? '',
            style: const TextStyle(color: NovaColors.graphite),
          ),
          const Divider(height: 32),
          SectionHeader(
            title: 'Weekly challenge',
            action: group['is_owner'] == true
                ? TextButton(
                    onPressed: busy ? null : onChallenge,
                    child: Text(challenge == null ? 'Create' : 'Change'),
                  )
                : null,
          ),
          if (challenge == null)
            const Text('The owner has not set a challenge yet.')
          else ...[
            Text(
              challenge['title']?.toString() ?? 'Challenge',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: NovaSpacing.sm),
            QuantityStepper(
              value: count.toDouble(),
              unit: 'times',
              isLoading: busy,
              onDecrement:
                  count <= 0 ? null : () => onChallengeCount(count - 1),
              onIncrement:
                  count >= target ? null : () => onChallengeCount(count + 1),
            ),
            if (group['leaderboard_enabled'] == true) ...[
              const SizedBox(height: NovaSpacing.md),
              for (final raw
                  in challenge['leaderboard'] as List<dynamic>? ?? const [])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text((raw as Map)['display_name'].toString()),
                  trailing: Text('${raw['completed_count']} / $target'),
                ),
            ],
          ],
          const Divider(height: 32),
          SectionHeader(
            title: 'Shared recipes',
            action: TextButton.icon(
              onPressed: busy ? null : onShareRecipe,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share'),
            ),
          ),
          if (recipes.isEmpty)
            const Text('No recipes shared yet.')
          else
            for (final raw in recipes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined),
                title: Text((raw as Map)['name'].toString()),
                subtitle: Text('${raw['servings']} servings'),
              ),
          const Divider(height: 32),
          SectionHeader(
            title: 'Shared grocery list',
            action: TextButton.icon(
              onPressed: busy ? null : onAddGrocery,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
          if (groceries.isEmpty)
            const Text('No grocery items yet.')
          else
            for (final raw in groceries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: (raw as Map)['is_checked'] == true,
                title: Text(raw['name'].toString()),
                subtitle: Text('${raw['quantity']} ${raw['unit']}'),
                onChanged: busy
                    ? null
                    : (value) => onToggleGrocery(
                          Map<String, dynamic>.from(raw),
                          value == true,
                        ),
              ),
        ],
      ),
    );
  }
}

int _int(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _date(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
