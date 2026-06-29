import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  String? _barcode;

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'Barcode scan',
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final code = capture.barcodes.isEmpty
                    ? null
                    : capture.barcodes.first.rawValue;
                if (code != null) setState(() => _barcode = code);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(NovaSpacing.lg),
            child: NovaCard(
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                      child: Text(_barcode ?? 'Point camera at a barcode')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
