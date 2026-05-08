import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/utils/image_utils.dart';

class ZoomableImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final dynamic minScale;
  final dynamic maxScale;
  final bool allowRotation;

  const ZoomableImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.minScale,
    this.maxScale,
    this.allowRotation = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showZoomableDialog(context);
      },
      child: ImageUtils.networkWithFallback(
        imageUrl,
        fit: fit,
        context: context,
      ),
    );
  }

  void _showZoomableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black87,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              PhotoView(
                imageProvider: NetworkImage(imageUrl),
                minScale: minScale ?? PhotoViewComputedScale.contained * 0.8,
                maxScale: maxScale ?? PhotoViewComputedScale.covered * 2.0,
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                loadingBuilder: (context, event) =>
                    Center(child: loading(context)),
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
                enableRotation: allowRotation,
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
