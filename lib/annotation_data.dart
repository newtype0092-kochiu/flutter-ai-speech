/// Data model for word and phoneme annotations on audio waveform
class WordAnnotation {
  final String word;
  final String phoneme;
  final double startTime; // in seconds
  final double endTime;   // in seconds

  const WordAnnotation({
    required this.word,
    required this.phoneme,
    required this.startTime,
    required this.endTime,
  });

  /// Get the duration of this annotation
  double get duration => endTime - startTime;

  /// Check if a given time falls within this annotation
  bool containsTime(double time) {
    return time >= startTime && time <= endTime;
  }

  /// Convert time position to relative position [0.0, 1.0] within this annotation
  double getRelativePosition(double time) {
    if (duration == 0) return 0.0;
    return ((time - startTime) / duration).clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'WordAnnotation(word: $word, phoneme: $phoneme, start: ${startTime.toStringAsFixed(2)}s, end: ${endTime.toStringAsFixed(2)}s)';
  }
}

/// Collection of word annotations for an audio file
class AudioAnnotations {
  final List<WordAnnotation> annotations;
  final double totalDuration; // in seconds

  const AudioAnnotations({
    required this.annotations,
    required this.totalDuration,
  });

  /// Get annotation at a specific time
  WordAnnotation? getAnnotationAtTime(double time) {
    for (final annotation in annotations) {
      if (annotation.containsTime(time)) {
        return annotation;
      }
    }
    return null;
  }

  /// Get all annotations that overlap with a time range
  List<WordAnnotation> getAnnotationsInRange(double startTime, double endTime) {
    return annotations.where((annotation) {
      return annotation.startTime < endTime && annotation.endTime > startTime;
    }).toList();
  }

  /// Convert time to relative position [0.0, 1.0] in the total duration
  double timeToRelativePosition(double time) {
    if (totalDuration == 0) return 0.0;
    return (time / totalDuration).clamp(0.0, 1.0);
  }

  /// Convert relative position [0.0, 1.0] to time
  double relativePositionToTime(double position) {
    return (position * totalDuration).clamp(0.0, totalDuration);
  }



  /// Create annotations from actual alignment data (similar to Python function)
  static AudioAnnotations fromAlignmentData({
    required List<(String word, String phoneme, double startTime, double endTime)> alignmentData,
    required double totalDuration,
  }) {
    final annotations = alignmentData.map((data) {
      return WordAnnotation(
        word: data.$1,
        phoneme: data.$2,
        startTime: data.$3,
        endTime: data.$4,
      );
    }).toList();

    return AudioAnnotations(
      annotations: annotations,
      totalDuration: totalDuration,
    );
  }
}