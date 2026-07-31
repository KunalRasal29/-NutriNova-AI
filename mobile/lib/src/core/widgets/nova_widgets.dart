import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/nova_theme.dart';
import '../network/network_status.dart';

class NovaScaffold extends StatelessWidget {
  const NovaScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.showBottomNavigation = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool showBottomNavigation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _NovaTopBar(title: title, actions: actions),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: NovaColors.backgroundGradient,
        ),
        child: SafeArea(
          child: _MobileFrame(
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: NetworkStatus.instance.isOffline,
                  builder: (context, isOffline, _) => isOffline
                      ? Container(
                          width: double.infinity,
                          color: NovaColors.gold,
                          padding: const EdgeInsets.symmetric(
                            horizontal: NovaSpacing.md,
                            vertical: NovaSpacing.sm,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_outlined, size: 18),
                              SizedBox(width: NovaSpacing.sm),
                              Flexible(
                                child: Text(
                                  'Offline - your form is kept. Reconnect and try again.',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar ??
          (showBottomNavigation ? const _NovaBottomBar() : null),
      floatingActionButton: floatingActionButton,
    );
  }
}

class NovaAuthScaffold extends StatelessWidget {
  const NovaAuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
    this.eyebrow = 'NUTRINOVA AI',
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NovaColors.ink,
              NovaColors.surface,
              Color(0xFF101C31),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 520
                    ? NovaSpacing.lg
                    : NovaSpacing.xxl,
                vertical: NovaSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (NovaSpacing.xl * 2),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [NovaColors.mint, NovaColors.blue],
                              ),
                              borderRadius:
                                  BorderRadius.circular(NovaRadius.lg),
                              boxShadow: [
                                BoxShadow(
                                  color: NovaColors.mint.withValues(alpha: 0.2),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const SizedBox.square(
                              dimension: 68,
                              child: Icon(
                                Icons.bolt_rounded,
                                color: NovaColors.ink,
                                size: 38,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: NovaSpacing.xl),
                        Text(
                          eyebrow,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: NovaColors.mint,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: NovaSpacing.sm),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: NovaSpacing.sm),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: NovaColors.graphite,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: NovaSpacing.xl),
                        NovaCard(
                          padding: const EdgeInsets.all(NovaSpacing.xl),
                          child: child,
                        ),
                        if (footer != null) ...[
                          const SizedBox(height: NovaSpacing.lg),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NovaTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _NovaTopBar({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final routeCanPop = ModalRoute.of(context)?.canPop ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.ink.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(
            color: NovaColors.border.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              height: 62,
              child: IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ) ??
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                  child: NavigationToolbar(
                    centerMiddle: true,
                    leading: routeCanPop ? const BackButton() : null,
                    middle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!routeCanPop) ...[
                          const _PremiumMark(size: 28),
                          const SizedBox(width: NovaSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: actions == null
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileFrame extends StatelessWidget {
  const _MobileFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 620) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: NovaColors.backgroundGradient,
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: NovaColors.border.withValues(alpha: 0.8),
                  ),
                ),
                boxShadow: NovaShadows.card,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _NovaBottomBar extends StatelessWidget {
  const _NovaBottomBar();

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          height: 96,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: BottomAppBar(
                      height: 76,
                      color: NovaColors.ink.withValues(alpha: 0.90),
                      elevation: 0,
                      child: Row(
                        children: [
                          Expanded(
                            child: _NovaNavItem(
                              label: 'Home',
                              icon: Icons.dashboard_outlined,
                              selectedIcon: Icons.dashboard,
                              selected: path == '/home',
                              onTap: () => context.go('/home'),
                            ),
                          ),
                          Expanded(
                            child: _NovaNavItem(
                              label: 'Diary',
                              icon: Icons.menu_book_outlined,
                              selectedIcon: Icons.menu_book,
                              selected: path.startsWith('/meals') ||
                                  path.startsWith('/foods'),
                              onTap: () => context.go('/meals'),
                            ),
                          ),
                          const SizedBox(width: 72),
                          Expanded(
                            child: _NovaNavItem(
                              label: 'Progress',
                              icon: Icons.bar_chart_outlined,
                              selectedIcon: Icons.bar_chart,
                              selected: path == '/analytics',
                              onTap: () => context.go('/analytics'),
                            ),
                          ),
                          Expanded(
                            child: _NovaNavItem(
                              label: 'More',
                              icon: Icons.more_horiz,
                              selectedIcon: Icons.more_horiz,
                              selected: path == '/profile' ||
                                  path == '/habits' ||
                                  path == '/recipes',
                              onTap: () => context.go('/profile'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(top: 0, child: _NovaAddButton()),
            ],
          ),
        ),
      ),
    );
  }
}

class _NovaNavItem extends StatelessWidget {
  const _NovaNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : NovaColors.graphite;
    return InkWell(
      borderRadius: BorderRadius.circular(NovaRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 64,
        decoration: BoxDecoration(
          color: selected
              ? NovaColors.blue.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(NovaRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovaAddButton extends StatelessWidget {
  const _NovaAddButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: NovaColors.premiumGradient,
        boxShadow: NovaShadows.glow(NovaColors.blue),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: FloatingActionButton.large(
        tooltip: 'Add',
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: NovaColors.panel,
          builder: (_) => const FractionallySizedBox(
            heightFactor: 0.86,
            child: _NovaAddSheet(),
          ),
        ),
        child: const Icon(Icons.add_rounded, size: 36),
      ),
    );
  }
}

class _NovaAddSheet extends StatelessWidget {
  const _NovaAddSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to today',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: NovaSpacing.md),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: NovaSpacing.md,
                crossAxisSpacing: NovaSpacing.md,
                childAspectRatio: 2.35,
                children: [
                  _AddSheetTile(
                    icon: Icons.search,
                    label: 'Log food',
                    color: NovaColors.blue,
                    onTap: () => _go(context, _withMealType('/foods/search')),
                  ),
                  _AddSheetTile(
                    icon: Icons.flash_on_outlined,
                    label: 'Quick add',
                    color: NovaColors.gold,
                    onTap: () =>
                        _go(context, _withMealType('/meals/quick-add')),
                  ),
                  _AddSheetTile(
                    icon: Icons.qr_code_scanner,
                    label: 'Barcode',
                    color: NovaColors.coral,
                    onTap: () => _go(context, _withMealType('/barcode')),
                  ),
                  _AddSheetTile(
                    icon: Icons.camera_alt_outlined,
                    label: 'Meal scan',
                    color: NovaColors.mint,
                    onTap: () => _go(context, _withMealType('/photos/scan')),
                  ),
                  _AddSheetTile(
                    icon: Icons.add_circle_outline,
                    label: 'Custom food',
                    color: NovaColors.violet,
                    onTap: () => _go(context, _withMealType('/foods/custom')),
                  ),
                  _AddSheetTile(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight',
                    color: NovaColors.lime,
                    onTap: () => _go(context, '/weight/log'),
                  ),
                  _AddSheetTile(
                    icon: Icons.add_task_outlined,
                    label: 'Checklist',
                    color: NovaColors.mint,
                    onTap: () => _go(context, '/habits'),
                  ),
                  _AddSheetTile(
                    icon: Icons.track_changes_outlined,
                    label: 'Daily tracking',
                    color: NovaColors.blue,
                    onTap: () => _go(context, '/tracking'),
                  ),
                  _AddSheetTile(
                    icon: Icons.document_scanner_outlined,
                    label: 'Label scan',
                    color: NovaColors.gold,
                    onTap: () => _go(context, '/labels/scan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String path) {
    Navigator.of(context).pop();
    context.push(path);
  }
}

String _withMealType(String path, {String mealType = 'lunch'}) {
  return Uri(path: path, queryParameters: {'meal_type': mealType}).toString();
}

class _AddSheetTile extends StatelessWidget {
  const _AddSheetTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NovaColors.panelRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NovaColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NovaSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NutritionMetricItem {
  const NutritionMetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class NutritionMetricGrid extends StatelessWidget {
  const NutritionMetricGrid({required this.items, super.key});

  final List<NutritionMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: NovaSpacing.md,
      crossAxisSpacing: NovaSpacing.md,
      childAspectRatio: 2.35,
      children: [
        for (final item in items)
          DecoratedBox(
            decoration: BoxDecoration(
              color: NovaColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NovaColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(NovaSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: item.color.withValues(alpha: 0.16),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NovaColors.graphite,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class NutrientProgressRow extends StatelessWidget {
  const NutrientProgressRow({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    super.key,
  });

  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress =
        target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${value.toStringAsFixed(value >= 10 ? 0 : 1)} / '
              '${target.toStringAsFixed(target >= 10 ? 0 : 1)} $unit',
              style: const TextStyle(
                color: NovaColors.graphite,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: NovaSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: NovaColors.ink,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      gradient: NovaColors.heroGradient,
      accentColor: NovaColors.mint,
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -34,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NovaColors.mint.withValues(alpha: 0.07),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumMark(icon: icon, size: 46),
              const SizedBox(width: NovaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.35,
                          ),
                    ),
                    const SizedBox(height: NovaSpacing.xs),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: NovaColors.graphite,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NovaCard extends StatelessWidget {
  const NovaCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(NovaSpacing.lg),
    this.color,
    this.gradient,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(NovaRadius.lg);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? NovaColors.panel) : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: (accentColor ?? NovaColors.border).withValues(
            alpha: accentColor == null ? 0.82 : 0.40,
          ),
        ),
        boxShadow: NovaShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class NovaButton extends StatelessWidget {
  const NovaButton.primary({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  }) : outlined = false;

  const NovaButton.secondary({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  }) : outlined = true;

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: NovaSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    if (outlined) {
      return OutlinedButton(onPressed: onPressed, child: child);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(
                colors: [NovaColors.border, NovaColors.panelRaised],
              )
            : NovaColors.premiumGradient,
        borderRadius: BorderRadius.circular(NovaRadius.md),
        boxShadow: onPressed == null ? null : NovaShadows.glow(NovaColors.blue),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

class _PremiumMark extends StatelessWidget {
  const _PremiumMark({this.icon = Icons.bolt_rounded, this.size = 34});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: NovaColors.premiumGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: NovaShadows.glow(NovaColors.mint),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

String friendlyErrorMessage(Object error) {
  final raw = error.toString().trim();
  var message = raw
      .replaceFirst(RegExp(r'^ApiException:\s*'), '')
      .replaceFirst(RegExp(r'^Exception:\s*'), '');
  message = message
      .replaceAll(RegExp(r'\bnon_field_errors:\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bdetail:\s*', caseSensitive: false), '')
      .replaceAll('_', ' ')
      .trim();
  final lower = message.toLowerCase();
  if (lower.contains('invalid email or password') ||
      lower.contains('no active account found') ||
      lower.contains('incorrect credentials')) {
    return 'The email or password is incorrect. Please try again.';
  }
  if (lower.contains('authentication credentials were not provided') ||
      lower.contains('token is invalid') ||
      lower.contains('token not valid')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (message.contains('XMLHttpRequest') ||
      lower.contains('connection errored') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup')) {
    return 'We could not connect to LaPulgaFit. Check your connection and try again.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('connection timeout') ||
      lower.contains('receive timeout')) {
    return 'The connection is taking too long. Check your Wi-Fi and try again.';
  }
  if (message.isEmpty) {
    return 'Something went wrong. Please try again.';
  }
  return message;
}

class MealTypeSelector extends StatelessWidget {
  const MealTypeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const options = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.lunch_dining_outlined,
    'dinner': Icons.dinner_dining_outlined,
    'snack': Icons.cookie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: NovaSpacing.sm,
      runSpacing: NovaSpacing.sm,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            avatar: Icon(entry.value, size: 16),
            label: Text(_label(entry.key)),
            selected: value == entry.key,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }

  String _label(String value) {
    return value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.value,
    required this.unit,
    required this.onDecrement,
    required this.onIncrement,
    super.key,
    this.isLoading = false,
  });

  final double value;
  final String unit;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease',
            icon: const Icon(Icons.remove),
            onPressed: isLoading ? null : onDecrement,
          ),
          SizedBox(
            width: 86,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} $unit',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
          IconButton(
            tooltip: 'Increase',
            icon: const Icon(Icons.add),
            onPressed: isLoading ? null : onIncrement,
          ),
        ],
      ),
    );
  }
}

class NovaBadge extends StatelessWidget {
  const NovaBadge({
    required this.label,
    super.key,
    this.color = NovaColors.mint,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SourceConfidenceBadges extends StatelessWidget {
  const SourceConfidenceBadges({
    required this.source,
    required this.confidence,
    required this.verified,
    super.key,
    this.classification,
  });

  final String source;
  final double confidence;
  final bool verified;
  final String? classification;

  @override
  Widget build(BuildContext context) {
    final isTrustedSeed = classification == 'trusted_seeded';
    final label = classification == 'user_custom'
        ? 'USER_CUSTOM'
        : isTrustedSeed
            ? 'Local database'
            : source.isEmpty
                ? 'Source pending'
                : source;
    final trustLabel = isTrustedSeed
        ? 'Trusted'
        : verified
            ? 'Verified'
            : 'Unverified';
    return Wrap(
      spacing: NovaSpacing.xs,
      runSpacing: NovaSpacing.xs,
      children: [
        NovaBadge(
          label: label,
          icon: classification == 'user_custom'
              ? Icons.person_outline
              : isTrustedSeed
                  ? Icons.library_books_outlined
                  : Icons.dataset_outlined,
          color: classification == 'ai_estimate'
              ? NovaColors.gold
              : classification == 'user_custom'
                  ? NovaColors.violet
                  : NovaColors.mint,
        ),
        NovaBadge(
          label: confidence <= 0
              ? 'Confidence pending'
              : '${(confidence * 100).toStringAsFixed(0)}% confidence',
          icon: Icons.speed_outlined,
          color: confidence >= 0.8 ? NovaColors.mint : NovaColors.gold,
        ),
        NovaBadge(
          label: trustLabel,
          icon: verified ? Icons.verified_outlined : Icons.warning_amber,
          color: verified ? NovaColors.mint : NovaColors.gold,
        ),
      ],
    );
  }
}

class NutritionPreviewBar extends StatelessWidget {
  const NutritionPreviewBar({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    super.key,
    this.compact = false,
  });

  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badges = [
      NovaBadge(
        label: '${caloriesKcal.toStringAsFixed(0)} kcal',
        icon: Icons.local_fire_department,
        color: NovaColors.mint,
      ),
      NovaBadge(
        label: 'P ${proteinG.toStringAsFixed(1)}g',
        color: NovaColors.coral,
      ),
      NovaBadge(
        label: 'C ${carbsG.toStringAsFixed(1)}g',
        color: NovaColors.gold,
      ),
      NovaBadge(
        label: 'F ${fatG.toStringAsFixed(1)}g',
        color: NovaColors.violet,
      ),
    ];
    if (compact) {
      return Wrap(
        spacing: NovaSpacing.xs,
        runSpacing: NovaSpacing.xs,
        children: badges,
      );
    }
    return NovaCard(
      child: Wrap(
        spacing: NovaSpacing.sm,
        runSpacing: NovaSpacing.sm,
        children: badges,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: NovaColors.premiumGradient,
            borderRadius: BorderRadius.circular(NovaRadius.pill),
          ),
        ),
        const SizedBox(width: NovaSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: NovaColors.graphite),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: NovaColors.graphite)),
          if (caption != null) ...[
            const SizedBox(height: NovaSpacing.xs),
            Text(
              caption!,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(NovaSpacing.lg),
      itemBuilder: (_, index) => const NovaCard(
        child: SizedBox(height: 72, child: LinearProgressIndicator()),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: NovaSpacing.md),
      itemCount: 4,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: NovaColors.graphite),
            const SizedBox(height: NovaSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: NovaSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NovaColors.graphite),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xl),
        child: NovaCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: NovaColors.danger, size: 32),
              const SizedBox(height: NovaSpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: NovaSpacing.lg),
              NovaButton.secondary(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NovaColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.danger.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: NovaColors.danger),
            const SizedBox(width: NovaSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: NovaColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
