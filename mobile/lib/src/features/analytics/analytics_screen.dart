import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Analytics',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Avg calories',
                  value: '1,920',
                  icon: Icons.local_fire_department,
                  color: NovaColors.mint,
                ),
              ),
              SizedBox(width: NovaSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Protein streak',
                  value: '5d',
                  icon: Icons.fitness_center,
                  color: NovaColors.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Macro split'),
                const SizedBox(height: NovaSpacing.lg),
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      sections: [
                        PieChartSectionData(
                          value: 30,
                          title: 'P',
                          color: NovaColors.coral,
                        ),
                        PieChartSectionData(
                          value: 45,
                          title: 'C',
                          color: NovaColors.gold,
                        ),
                        PieChartSectionData(
                          value: 25,
                          title: 'F',
                          color: NovaColors.violet,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          const NovaCard(
            child: Text(
              'Insight: weekend sodium intake is higher than weekdays. Try logging packaged foods by barcode for cleaner labels.',
            ),
          ),
        ],
      ),
    );
  }
}
