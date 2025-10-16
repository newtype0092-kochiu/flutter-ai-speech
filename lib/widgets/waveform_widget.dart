import 'package:flutter/material.dart';
import '../models/annotation_data.dart';

/// Audio waveform rendering component
class WaveformWidget extends StatelessWidget {
  final List<double> waveformData;
  final Color waveColor;
  final Color backgroundColor;
  final double strokeWidth;
  final double height;
  final bool showCenterLine;
  final WaveformStyle style;
  final AudioAnnotations? annotations;
  final bool showAnnotations;

  const WaveformWidget({
    super.key,
    required this.waveformData,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.strokeWidth = 1.0,
    this.height = 200.0,
    this.showCenterLine = true,
    this.style = WaveformStyle.line,
    this.annotations,
    this.showAnnotations = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // Waveform layer
          CustomPaint(
            painter: WaveformPainter(
              waveformData: waveformData,
              waveColor: waveColor,
              strokeWidth: strokeWidth,
              showCenterLine: showCenterLine,
              style: style,
            ),
            size: Size.infinite,
          ),
          // Annotations layer
          if (annotations != null && showAnnotations)
            CustomPaint(
              painter: AnnotationPainter(
                annotations: annotations!,
              ),
              size: Size.infinite,
            ),
        ],
      ),
    );
  }
}

/// Waveform style enumeration
enum WaveformStyle {
  line,    // Line style
  bars,    // Bar style
  filled,  // Filled style
}

/// Waveform painter
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final double strokeWidth;
  final bool showCenterLine;
  final WaveformStyle style;

  WaveformPainter({
    required this.waveformData,
    required this.waveColor,
    required this.strokeWidth,
    required this.showCenterLine,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    // Draw center line
    if (showCenterLine) {
      _drawCenterLine(canvas, size);
    }

    // Draw waveform according to style
    switch (style) {
      case WaveformStyle.line:
        _drawLineWaveform(canvas, size);
      case WaveformStyle.bars:
        _drawBarWaveform(canvas, size);
      case WaveformStyle.filled:
        _drawFilledWaveform(canvas, size);
    }
  }

  /// Draw empty state
  void _drawEmptyState(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0;

    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );

    // Draw hint text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'No audio data',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  /// Draw center line
  void _drawCenterLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );
  }

  /// Draw line style waveform
  void _drawLineWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final centerY = size.height / 2;
    final amplitude = size.height / 2 * 0.8; // Leave some margin

    for (int i = 0; i < waveformData.length; i++) {
      final x = (i / (waveformData.length - 1)) * size.width;
      final y = centerY - (waveformData[i] * amplitude);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  /// Draw bar style waveform
  void _drawBarWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final amplitude = size.height / 2 * 0.8;
    final barWidth = size.width / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final barHeight = waveformData[i].abs() * amplitude;
      
      // Draw upward bars
      if (waveformData[i] >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, centerY - barHeight, barWidth * 0.8, barHeight),
          paint,
        );
      }
      
      // Draw downward bars
      if (waveformData[i] <= 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, centerY, barWidth * 0.8, barHeight),
          paint,
        );
      }
    }
  }

  /// Draw filled style waveform
  void _drawFilledWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerY = size.height / 2;
    final amplitude = size.height / 2 * 0.8;

    // Start path
    path.moveTo(0, centerY);

    // Draw upper part
    for (int i = 0; i < waveformData.length; i++) {
      final x = (i / (waveformData.length - 1)) * size.width;
      final y = centerY - (waveformData[i].abs() * amplitude);
      path.lineTo(x, y);
    }

    // Draw lower part (mirrored)
    for (int i = waveformData.length - 1; i >= 0; i--) {
      final x = (i / (waveformData.length - 1)) * size.width;
      final y = centerY + (waveformData[i].abs() * amplitude);
      path.lineTo(x, y);
    }

    path.close();
    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = waveColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
           oldDelegate.waveColor != waveColor ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.showCenterLine != showCenterLine ||
           oldDelegate.style != style;
  }
}

/// Waveform component with playback progress indicator
class InteractiveWaveformWidget extends StatefulWidget {
  final List<double> waveformData;
  final Color waveColor;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  final double height;
  final bool showCenterLine;
  final WaveformStyle style;
  final double progress; // Playback progress [0.0, 1.0]
  final Function(double)? onSeek; // Click to seek callback
  final AudioAnnotations? annotations;
  final bool showAnnotations;

  const InteractiveWaveformWidget({
    super.key,
    required this.waveformData,
    this.waveColor = Colors.blue,
    this.progressColor = Colors.red,
    this.backgroundColor = Colors.transparent,
    this.strokeWidth = 1.0,
    this.height = 200.0,
    this.showCenterLine = true,
    this.style = WaveformStyle.line,
    this.progress = 0.0,
    this.onSeek,
    this.annotations,
    this.showAnnotations = true,
  });

  @override
  State<InteractiveWaveformWidget> createState() => _InteractiveWaveformWidgetState();
}

class _InteractiveWaveformWidgetState extends State<InteractiveWaveformWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (widget.onSeek != null) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final position = details.localPosition.dx / renderBox.size.width;
          widget.onSeek!(position.clamp(0.0, 1.0));
        }
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            // Waveform layer
            CustomPaint(
              painter: InteractiveWaveformPainter(
                waveformData: widget.waveformData,
                waveColor: widget.waveColor,
                progressColor: widget.progressColor,
                strokeWidth: widget.strokeWidth,
                showCenterLine: widget.showCenterLine,
                style: widget.style,
                progress: widget.progress,
              ),
              size: Size.infinite,
            ),
            // Annotations layer
            if (widget.annotations != null && widget.showAnnotations)
              CustomPaint(
                painter: AnnotationPainter(
                  annotations: widget.annotations!,
                ),
                size: Size.infinite,
              ),
          ],
        ),
      ),
    );
  }
}

/// Interactive waveform painter
class InteractiveWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final Color progressColor;
  final double strokeWidth;
  final bool showCenterLine;
  final WaveformStyle style;
  final double progress;

  InteractiveWaveformPainter({
    required this.waveformData,
    required this.waveColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.showCenterLine,
    required this.style,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    // Draw center line
    if (showCenterLine) {
      _drawCenterLine(canvas, size);
    }

    // Calculate progress position
    final progressX = size.width * progress;

    // Draw unplayed part
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(progressX, 0, size.width - progressX, size.height));
    _drawWaveform(canvas, size, waveColor);
    canvas.restore();

    // Draw played part
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, progressX, size.height));
    _drawWaveform(canvas, size, progressColor);
    canvas.restore();

    // Draw progress indicator line
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(progressX, 0),
      Offset(progressX, size.height),
      progressPaint,
    );
  }

  void _drawCenterLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );
  }

  void _drawWaveform(Canvas canvas, Size size, Color color) {
    // Draw waveform according to style
    switch (style) {
      case WaveformStyle.line:
        _drawLineWaveformWithColor(canvas, size, color);
      case WaveformStyle.bars:
        _drawBarWaveformWithColor(canvas, size, color);
      case WaveformStyle.filled:
        _drawFilledWaveformWithColor(canvas, size, color);
    }
  }

  void _drawLineWaveformWithColor(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final centerY = size.height / 2;
    final amplitude = size.height / 2 * 0.8;

    for (int i = 0; i < waveformData.length; i++) {
      final x = (i / (waveformData.length - 1)) * size.width;
      final y = centerY - (waveformData[i] * amplitude);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawBarWaveformWithColor(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final amplitude = size.height / 2 * 0.8;
    final barWidth = size.width / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final barHeight = waveformData[i].abs() * amplitude;
      
      // Draw upward bars
      if (waveformData[i] >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, centerY - barHeight, barWidth * 0.8, barHeight),
          paint,
        );
      }
      
      // Draw downward bars
      if (waveformData[i] <= 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, centerY, barWidth * 0.8, barHeight),
          paint,
        );
      }
    }
  }

  void _drawFilledWaveformWithColor(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerY = size.height / 2;
    final amplitude = size.height / 2 * 0.8;

    // Start path
    path.moveTo(0, centerY);

    // Draw upper part
    for (int i = 0; i < waveformData.length; i++) {
      final x = (i / (waveformData.length - 1)) * size.width;
      final y = centerY - (waveformData[i].abs() * amplitude);
      path.lineTo(x, y);
    }

    // Draw lower part (mirrored)
    for (int i = waveformData.length - 1; i >= 0; i--) {
      final x = (i / (waveformData.length - 1)) * size.width;
      final y = centerY + (waveformData[i].abs() * amplitude);
      path.lineTo(x, y);
    }

    path.close();
    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant InteractiveWaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
           oldDelegate.waveColor != waveColor ||
           oldDelegate.progressColor != progressColor ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.showCenterLine != showCenterLine ||
           oldDelegate.style != style ||
           oldDelegate.progress != progress;
  }
}

/// Custom painter for drawing word and phoneme annotations
class AnnotationPainter extends CustomPainter {
  final AudioAnnotations annotations;

  AnnotationPainter({
    required this.annotations,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (annotations.annotations.isEmpty) return;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw annotation regions and labels
    for (int i = 0; i < annotations.annotations.length; i++) {
      final annotation = annotations.annotations[i];
      _drawAnnotationRegion(canvas, size, annotation, i);
      _drawAnnotationLabels(canvas, size, annotation, textPainter, i);
    }
  }

  void _drawAnnotationRegion(Canvas canvas, Size size, WordAnnotation annotation, int index) {
    final startX = annotations.timeToRelativePosition(annotation.startTime) * size.width;
    final endX = annotations.timeToRelativePosition(annotation.endTime) * size.width;
    final width = endX - startX;

    // Alternating colors for different annotations
    final colors = [
      Colors.blue.withValues(alpha: 0.2),
      Colors.green.withValues(alpha: 0.2),
      Colors.orange.withValues(alpha: 0.2),
      Colors.purple.withValues(alpha: 0.2),
      Colors.red.withValues(alpha: 0.2),
    ];
    final color = colors[index % colors.length];

    // Draw background region
    final regionPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(startX, 0, width, size.height),
      regionPaint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(startX, 0, width, size.height),
      borderPaint,
    );
  }

  void _drawAnnotationLabels(Canvas canvas, Size size, WordAnnotation annotation, 
                           TextPainter textPainter, int index) {
    final startX = annotations.timeToRelativePosition(annotation.startTime) * size.width;
    final endX = annotations.timeToRelativePosition(annotation.endTime) * size.width;
    final centerX = (startX + endX) / 2;
    final width = endX - startX;

    // Skip drawing text if region is too narrow
    if (width < 40) return;

    // Word label (top)
    textPainter.text = TextSpan(
      text: annotation.word,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    
    final wordOffset = Offset(
      centerX - (textPainter.width / 2),
      8.0,
    );
    textPainter.paint(canvas, wordOffset);

    // Phoneme label (bottom)
    textPainter.text = TextSpan(
      text: annotation.phoneme,
      style: TextStyle(
        color: Colors.grey[700],
        fontSize: 10,
        fontStyle: FontStyle.italic,
      ),
    );
    textPainter.layout();
    
    final phonemeOffset = Offset(
      centerX - (textPainter.width / 2),
      size.height - textPainter.height - 8.0,
    );
    textPainter.paint(canvas, phonemeOffset);

    // Time labels (if there's enough space)
    if (width > 80) {
      // Start time
      textPainter.text = TextSpan(
        text: '${annotation.startTime.toStringAsFixed(1)}s',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 8,
        ),
      );
      textPainter.layout();
      
      final startTimeOffset = Offset(
        startX + 2,
        size.height / 2 - textPainter.height / 2,
      );
      textPainter.paint(canvas, startTimeOffset);

      // End time
      textPainter.text = TextSpan(
        text: '${annotation.endTime.toStringAsFixed(1)}s',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 8,
        ),
      );
      textPainter.layout();
      
      final endTimeOffset = Offset(
        endX - textPainter.width - 2,
        size.height / 2 - textPainter.height / 2,
      );
      textPainter.paint(canvas, endTimeOffset);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return oldDelegate.annotations != annotations;
  }
}