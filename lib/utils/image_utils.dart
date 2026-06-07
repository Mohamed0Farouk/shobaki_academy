import 'package:flutter/material.dart';
import 'package:shobaki_academy/utils/responsive_utils.dart';

class ImageUtils {
  static Widget networkWithFallback(
    String? url, {
    double? height,
    double? width,
    BoxFit fit = BoxFit.fill,
    required BuildContext context,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (url == null || url.isEmpty) {
      return placeholder ?? _defaultPlaceholder(context);
    }

    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _shimmerPlaceholder(height: height);
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _errorPlaceholder(context, height: height);
      },
      cacheWidth: (MediaQuery.of(context).size.width * 2).toInt(),
    );
  }

  static Widget _shimmerPlaceholder({double? height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[200]!,
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
          begin: Alignment(-1.0, -0.3),
          end: Alignment(1.0, 0.3),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.grey[400]!,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _defaultPlaceholder(BuildContext context, {double? height}) {
    final defaultHeight = height ?? ResponsiveUtils.imageHeight(context);
    return Container(
      height: defaultHeight,
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey[400],
          size: 40,
        ),
      ),
    );
  }

  static Widget _errorPlaceholder(BuildContext context, {double? height}) {
    final defaultHeight = height ?? ResponsiveUtils.imageHeight(context);
    return Container(
      height: defaultHeight,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'تعذر تحميل الصورة',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget avatar({
    String? imageUrl,
    double size = 50,
    String? placeholderText,
  }) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarPlaceholder(size, placeholderText),
        ),
      );
    }
    return _avatarPlaceholder(size, placeholderText);
  }

  static Widget _avatarPlaceholder(double size, String? text) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: text != null
            ? Text(
                text.isNotEmpty ? text[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.5,
                color: Colors.grey[400],
              ),
      ),
    );
  }

  static Widget cachedNetworkImage({
    required String url,
    double? height,
    double? width,
    BoxFit fit = BoxFit.fill,
  }) {
    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      cacheWidth: width?.toInt(),
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: Colors.grey[200],
        child: Icon(Icons.image, color: Colors.grey[400]),
      ),
    );
  }
}