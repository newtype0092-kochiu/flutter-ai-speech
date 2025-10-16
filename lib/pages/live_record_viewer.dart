import 'dart:async';
import 'dart:math';
// dart:io not used to keep web compatibility

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../waveform_widget.dart';

/// Live recording waveform viewer.
/// Uses record.startStream(encoder: pcm16bits) to receive PCM chunks and
/// updates the waveform in real time.
class LiveRecordViewer extends StatefulWidget {
  const LiveRecordViewer({super.key});

  @override
  State<LiveRecordViewer> createState() => _LiveRecordViewerState();
}

// Using InteractiveWaveformWidget from waveform_widget.dart for mirrored rendering

class _LiveRecordViewerState extends State<LiveRecordViewer> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _sub;
  List<double> _waveform = [];
  bool _isRecording = false;
  String? _error;
  String? _lastFilePath;
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  double? _lastAmpValue;

  // we accumulate a sliding buffer of samples (downsampled) for display
  final int _maxPoints = 1000;

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    _player.dispose();
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
      // start recording to a file (recorder will decide path on web/native)
      final filename = 'rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: filename,
      );

      // also subscribe to amplitude changes for lightweight waveform
      _sub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        // amp.current is dBFS-like; convert to linear approx for display
          final linear = dbfsToLinear(amp.current);
          _lastAmpValue = amp.current;
          setState(() {
            _waveform.add(linear);
            if (_waveform.length > _maxPoints) {
              _waveform.removeRange(0, _waveform.length - _maxPoints);
            }
          });
          // auto-scroll to end next frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
              );
            }
          });
      }, onError: (e) {
        setState(() => _error = 'Amplitude stream error: $e');
      });

      setState(() {
        _isRecording = true;
        _waveform = [];
        _lastFilePath = null;
      });
    } catch (e) {
      setState(() {
        _error = '无法开始录音: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      // update last file path if returned
      if (path != null) _lastFilePath = path;
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _isRecording = false;
    });
  }

  // Playback the last recorded file
  Future<void> _playLast() async {
    if (_lastFilePath == null) return;
    await _player.stop();
    if (kIsWeb) {
      // web: path is a blob URL
      await _player.play(UrlSource(_lastFilePath!));
    } else {
      await _player.play(DeviceFileSource(_lastFilePath!));
    }
  }

  double dbfsToLinear(double db) {
    // Convert dBFS to linear amplitude using standard formula:
    // linear = 10^(db/20). db is negative (e.g., -70 dB) -> tiny linear value.
    // Amplify slightly for visualization and clamp to [0,1].
    final d = db.isFinite ? db : -100.0;
    final linear = pow(10.0, d / 20.0) as double; // in (0,1]
    // amplify small signals for visualization
    final amplified = (linear * 8.0).clamp(0.0, 1.0);
    return amplified;
  }

  // previously used when consuming raw PCM stream; now we use amplitude stream

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
                const SizedBox(width: 8),
                if (_lastAmpValue != null)
                  Text('Amp: ${_lastAmpValue!.toStringAsFixed(2)}'),
                const SizedBox(width: 12),
                Text('Points: ${_waveform.length}'),
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
                    : SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          // increase horizontal scale so points are spaced out
                          width: max(400, _waveform.length * 4.0),
                          height: 220,
                            child: InteractiveWaveformWidget(
                              waveformData: List<double>.from(_waveform),
                              height: 220,
                              style: WaveformStyle.line,
                              progress: 0.0,
                              showAnnotations: false,
                              waveColor: Colors.blue,
                              strokeWidth: 1.0,
                            ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _lastFilePath != null && !_isRecording ? _playLast : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Last'),
                ),
                const SizedBox(width: 12),
                if (_lastFilePath != null)
                  Expanded(child: Text('Saved: ${_lastFilePath!.split(RegExp(r"[\\/]")).last}'))
                else
                  const Expanded(child: Text('No recording yet')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


