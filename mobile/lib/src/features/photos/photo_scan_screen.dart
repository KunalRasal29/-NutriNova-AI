import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/repositories/providers.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/widgets/nova_widgets.dart';

class PhotoScanScreen extends ConsumerStatefulWidget {
  const PhotoScanScreen({super.key, this.initialMealType = 'lunch'});

  final String initialMealType;

  @override
  ConsumerState<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _PhotoScanScreenState extends ConsumerState<PhotoScanScreen> {
  XFile? _image;
  bool _uploading = false;
  String _progressLabel = '';
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'AI meal scan',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
          const PageIntro(
            title: 'Scan a meal',
            subtitle: 'Review the detected foods and portions before saving.',
            icon: Icons.camera_alt_outlined,
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaCard(
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: NovaColors.border.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _image == null
                        ? const Center(
                            child: Icon(Icons.camera_alt_outlined, size: 44),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_image!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: NovaSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: NovaButton.primary(
                        label: 'Camera',
                        icon: Icons.photo_camera_outlined,
                        onPressed: () => _pick(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: NovaSpacing.md),
                    Expanded(
                      child: NovaButton.secondary(
                        label: 'Gallery',
                        icon: Icons.photo_library_outlined,
                        onPressed: () => _pick(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          if (_uploading) ...[
            _ScanProgressCard(label: _progressLabel),
            const SizedBox(height: NovaSpacing.lg),
          ],
          if (_errorMessage.isNotEmpty) ...[
            ErrorBanner(message: _errorMessage),
            const SizedBox(height: NovaSpacing.lg),
          ],
          const _PhotoDisclaimerCard(),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _uploading ? 'Working...' : 'Upload and analyze',
            icon: Icons.auto_awesome,
            onPressed: _image == null || _uploading
                ? null
                : () async {
                    setState(() {
                      _uploading = true;
                      _progressLabel = 'Uploading photo';
                      _errorMessage = '';
                    });
                    try {
                      await Future<void>.delayed(
                        const Duration(milliseconds: 150),
                      );
                      if (mounted) {
                        setState(() => _progressLabel = 'Analyzing meal');
                      }
                      final review = await ref
                          .read(nutritionRepositoryProvider)
                          .uploadMealPhoto(_image!.path);
                      if (context.mounted) {
                        context.go(
                          Uri(
                            path: '/photos/review',
                            queryParameters: {
                              'analysis_id': review.analysisId,
                              'meal_type': widget.initialMealType,
                            },
                          ).toString(),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        setState(() {
                          _uploading = false;
                          _progressLabel = '';
                          _errorMessage = error.toString();
                        });
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    if (_uploading) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _image = picked;
        _errorMessage = '';
      });
    }
  }
}

class _ScanProgressCard extends StatelessWidget {
  const _ScanProgressCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      color: NovaColors.panelRaised,
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: NovaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.isEmpty ? 'Preparing scan' : label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: NovaSpacing.xs),
                const Text(
                  'This can take a few seconds.',
                  style: TextStyle(color: NovaColors.graphite),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoDisclaimerCard extends StatelessWidget {
  const _PhotoDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return const NovaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: NovaColors.gold),
          SizedBox(width: NovaSpacing.md),
          Expanded(
            child: Text(
              'Photo nutrition is an estimate. Confirm food and portion size for better accuracy.',
            ),
          ),
        ],
      ),
    );
  }
}
