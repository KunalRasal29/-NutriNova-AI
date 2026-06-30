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

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      title: 'AI meal scan',
      body: ListView(
        padding: const EdgeInsets.all(NovaSpacing.lg),
        children: [
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
          const NovaCard(
            child: Text(
              'Photo nutrition is an estimate. You will review detected foods and portions before saving.',
            ),
          ),
          const SizedBox(height: NovaSpacing.lg),
          NovaButton.primary(
            label: _uploading ? 'Analyzing...' : 'Analyze photo',
            icon: Icons.auto_awesome,
            onPressed: _image == null || _uploading
                ? null
                : () async {
                    setState(() => _uploading = true);
                    try {
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
                        setState(() => _uploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) setState(() => _image = picked);
  }
}
