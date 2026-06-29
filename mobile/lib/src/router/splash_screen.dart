import 'package:flutter/material.dart';

import '../core/theme/nova_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 56, color: NovaColors.mint),
              SizedBox(height: NovaSpacing.lg),
              Text(
                'NutriNova AI',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: NovaSpacing.sm),
              Text('Wellness tracking. Not medical advice.'),
              SizedBox(height: NovaSpacing.xl),
              LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
