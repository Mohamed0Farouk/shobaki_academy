/// User-facing strings for the video player.
///
/// Centralised so the Arabic copy is asserted by unit tests and can be reviewed
/// in one place rather than scattered through the controller.
library;

class PlayerMessages {
  const PlayerMessages._();

  static const String autoQualityTitle = 'جودة الفيديو';
  static const String autoQualityBody =
      'جودة الفيديو تلقائية للحفاظ على سلاسة المشاهدة، يمكنك تثبيت الجودة التي تريدها من إعدادات المشغّل';

  static const String stalledLabel = 'جارٍ إعادة الاتصال…';
  static const String connectionLost =
      'انقطع الاتصال بالإنترنت، يرجى التحقق من الاتصال وإعادة المحاولة.';

  /// Label for the quality menu entry that hands control back to the app.
  static const String autoQualityLabel = 'تلقائي';

  /// Quality chip text while auto mode is managing the rendition.
  static String autoChipLabel(String effectiveLabel) =>
      '$autoQualityLabel · $effectiveLabel';

  /// Title of the quality picker.
  ///
  /// Separate from [autoQualityTitle] even though the two read identically:
  /// one is a transient notice and the other is a heading, and tying them
  /// together would break whenever either surface needs its own wording.
  static const String qualityMenuTitle = 'جودة الفيديو';

  static const String _autoQualityOptionBlurb =
      'يتكيف تلقائياً مع سرعة الاتصال';

  /// Subtitle beneath the `تلقائي` menu entry.
  ///
  /// [effectiveLabel] is the rendition auto mode is actually playing and is
  /// only passed while auto is in charge. Showing a resolution beside
  /// `تلقائي` while the student has pinned a different one would be
  /// describing a mode that is not active.
  static String autoQualityOptionSubtitle(String? effectiveLabel) =>
      effectiveLabel == null
      ? _autoQualityOptionBlurb
      : '$_autoQualityOptionBlurb · الحالي: $effectiveLabel';

  /// Explains that picking a concrete rendition is sticky, shown under the
  /// list.
  ///
  /// Without it a student who pins `480p` on a bad connection has no way to
  /// know that automatic recovery will not happen until they come back here.
  static const String pinQualityHint =
      'اختيار جودة محددة يثبّتها حتى تختار "$autoQualityLabel" من جديد';
}
