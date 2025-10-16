import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../audio_data_processor.dart';
import '../waveform_widget.dart';

/// Live recording waveform viewer.
/// Uses record.startStream(encoder: pcm16bits) to receive PCM chunks and
/// updates the waveform in real time.
class LiveRecordViewer extends StatefulWidget {
  const LiveRecordViewer({super.key});

  @override
  State<LiveRecordViewer> createState() => _LiveRecordViewerState();
}

class _LiveRecordViewerState extends State<LiveRecordViewer> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  List<double> _waveform = [];
  bool _isRecording = false;
  String? _error;

  // we accumulate a sliding buffer of samples (downsampled) for display
  final int _maxPoints = 1000;

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
    });

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      setState(() {
        _error = '麦克风权限未授予';
      });
      return;
    }

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
      );

      // stream will be returned when stream recording is supported

      // subscribe to byte chunks
      _sub = stream.listen((chunk) {
        _handleChunk(chunk);
      }, onError: (e) {
        setState(() => _error = '流错误: $e');
      }, onDone: () {
        // stream ended
      });

      setState(() {
        _isRecording = true;
        _waveform = [];
      });
    } catch (e) {
      setState(() {
        _error = '无法开始录音: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _isRecording = false;
    });
  }

  void _handleChunk(Uint8List chunk) {
    // Convert little-endian PCM16 bytes to normalized [-1,1] samples
    final samples = <double>[];
    for (int i = 0; i + 1 < chunk.length; i += 2) {
      final low = chunk[i];
      final high = chunk[i + 1];
      final v = low | (high << 8);
      final signed = v > 32767 ? v - 65536 : v;
      samples.add(signed / 32767.0);
    }

    // Downsample the samples to a reasonable number for display
    final down = AudioDataProcessor.downsample(samples, 100);

    // Append to waveform with sliding window
    setState(() {
      _waveform.addAll(down);
      if (_waveform.length > _maxPoints) {
        _waveform.removeRange(0, _waveform.length - _maxPoints);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Record Viewer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isRecording ? null : _startRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('Start'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isRecording ? _stopRecording : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                const SizedBox(width: 12),
                if (_error != null)
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _waveform.isEmpty
                    ? const Center(child: Text('No live waveform'))
                    : InteractiveWaveformWidget(
                        waveformData: _waveform,
                        height: double.infinity,
                        style: WaveformStyle.line,
                        progress: 0.0,
                        showAnnotations: false,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
