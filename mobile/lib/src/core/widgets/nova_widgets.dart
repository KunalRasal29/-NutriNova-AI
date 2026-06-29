import 'package:flutter/material.dart';

import '../theme/nova_theme.dart';

class NovaScaffold extends StatelessWidget {
  const NovaScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class NovaCard extends StatelessWidget {
  const NovaCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(NovaSpacing.lg),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(padding: padding, child: child),
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
    return ElevatedButton(onPressed: onPressed, child: child);
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
    final label = classification == 'user_custom'
        ? 'USER_CUSTOM'
        : source.isEmpty
            ? 'Source pending'
            : source;
    return Wrap(
      spacing: NovaSpacing.xs,
      runSpacing: NovaSpacing.xs,
      children: [
        NovaBadge(
          label: label,
          icon: classification == 'user_custom'
              ? Icons.person_outline
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
          label: verified ? 'Verified' : 'Unverified',
          icon: verified ? Icons.verified_outlined : Icons.warning_amber,
          color: verified ? NovaColors.mint : NovaColors.gold,
        ),
      ],
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
