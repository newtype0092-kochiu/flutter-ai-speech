import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

// Web-specific imports (using modern web APIs)
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../widgets/waveform_widget.dart';
import '../services/google_auth_service.dart';
import '../services/drive_audio_upload_service.dart';

/// Live recording waveform viewer.
/// Uses record.startStream(encoder: pcm16bits) to receive PCM chunks and
/// updates the waveform in real time.
class LiveRecordViewer extends StatefulWidget {
  const LiveRecordViewer({super.key});

  @override
  State<LiveRecordViewer> createState() => _LiveRecordViewerState();
}

// Using InteractiveWaveformWidget from waveform_widget.dart for mirrored rendering

class _LiveRecordViewerState extends State<LiveRecordViewer> with AutomaticKeepAliveClientMixin {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _sub;
  List<double> _waveform = [];
  bool _isRecording = false;
  String? _error;
  String? _lastFilePath;
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  double? _lastAmpValue;
  String? _currentDeviceName;

  // we accumulate a sliding buffer of samples (downsampled) for display
  final int _maxPoints = 1000;

  @override
  bool get wantKeepAlive => true;

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
        _error = 'Microphone permission not granted';
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

      // Detect current audio device
      _detectCurrentAudioDevice();
    } catch (e) {
      setState(() {
        _error = 'Cannot start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      // update last file path if returned
      if (path != null) {
        _lastFilePath = path;
        if (kDebugMode) {
          print('Recording stopped. File path: $path');
          if (kIsWeb) {
            print('This is a blob URL that can be downloaded or played');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping recording: $e');
      }
    }
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _isRecording = false;
      // Can choose to keep device name display or clear it
      // _currentDeviceName = null; // If you want to hide device name after stopping recording
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

  // Download the recorded file (Web only)
  Future<void> _downloadRecording() async {
    if (_lastFilePath == null) return;
    
    if (kIsWeb) {
      try {
        // Generate a filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'recording_$timestamp.wav';
        
        // Create download link and trigger download using modern web API
        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
        anchor.href = _lastFilePath!;
        anchor.download = fileName;
        anchor.style.display = 'none';
        
        web.document.body!.appendChild(anchor);
        anchor.click();
        anchor.remove();
        
        setState(() {
          _error = 'Recording file downloaded: $fileName';
        });
        
        if (kDebugMode) {
          print('Downloaded recording: $fileName from blob: $_lastFilePath');
        }
      } catch (e) {
        setState(() {
          _error = 'Download failed: $e';
        });
        if (kDebugMode) {
          print('Download error: $e');
        }
      }
    } else {
      setState(() {
        _error = 'Download function is only available on Web platform';
      });
    }
  }

  // Copy blob URL to clipboard (for debugging)
  Future<void> _copyBlobUrl() async {
    if (_lastFilePath == null) return;
    
    if (kIsWeb) {
      try {
        // Use the clipboard API - writeText returns a Promise, convert to Future
        await web.window.navigator.clipboard.writeText(_lastFilePath!).toDart;
        setState(() {
          _error = 'Blob URL copied to clipboard';
        });
      } catch (e) {
        // Fallback: show the URL in error message for manual copy
        setState(() {
          _error = 'Blob URL: $_lastFilePath';
        });
      }
    }
  }

  // Upload recording to Google Drive AppData
  Future<void> _uploadToGoogleDrive() async {
    if (_lastFilePath == null) return;
    
    if (!kIsWeb) {
      setState(() {
        _error = 'Upload function is only available on Web platform';
      });
      return;
    }

    try {
      setState(() {
        _error = 'Uploading to Google Drive...';
      });

      // Check if user is signed in
      final authService = GoogleAuthService();
      if (!authService.isAuthorized) {
        setState(() {
          _error = 'Please sign in to Google account first';
        });
        return;
      }

      // Convert blob to bytes using fetch API
      final response = await web.window.fetch(_lastFilePath!.toJS).toDart;
      final blob = await response.blob().toDart;
      final arrayBuffer = await blob.arrayBuffer().toDart;
      final bytes = arrayBuffer.toDart.asUint8List();

      // Generate filename with device name and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceName = _currentDeviceName?.replaceAll(RegExp(r'[^\w\-_\.]'), '_') ?? 'unknown';
      final fileName = 'recording_${deviceName}_$timestamp.wav';

      // Upload to Google Drive using a custom method
      final uploadResult = await _uploadAudioToDrive(fileName, bytes);

      if (uploadResult != null && uploadResult['fileId'] != null) {
        setState(() {
          _error = 'Recording file uploaded to Google Drive AppData:\n'
                  'File name: $fileName\n'
                  'File ID: ${uploadResult['fileId']}\n'
                  'Size: ${bytes.length} bytes\n'
                  'Type: audio/wav';
        });
      } else {
        setState(() {
          _error = 'Upload successful but file ID not obtained';
        });
      }

      if (kDebugMode) {
        print('Successfully uploaded recording to Google Drive: $fileName');
      }
    } catch (e) {
      setState(() {
        _error = 'Upload failed: $e';
      });
      if (kDebugMode) {
        print('Upload error: $e');
      }
    }
  }

  // Upload audio file to Google Drive AppData
  Future<Map<String, dynamic>?> _uploadAudioToDrive(String fileName, List<int> bytes) async {
    try {
      final audioUploadService = DriveAudioUploadService();
      
      // Upload audio file metadata
      final uploadResult = await audioUploadService.uploadAudioFile(
        fileName, 
        Uint8List.fromList(bytes)
      );
      
      if (uploadResult != null) {
        if (kDebugMode) {
          print('Audio metadata uploaded successfully!');
          print('File ID: ${uploadResult['fileId']}');
          print('File Name: ${uploadResult['fileName']}');
          print('File Size: ${uploadResult['size']} bytes');
          print('Upload Time: ${uploadResult['uploadTime']}');
          print('Note: ${uploadResult['note']}');
        }
        
        // Return upload result for UI display
        return uploadResult;
      } else {
        throw Exception('Upload returned null result');
      }

    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  // Detect current audio device being used
  Future<void> _detectCurrentAudioDevice() async {
    if (!kIsWeb) return;
    
    try {
      // Get current audio stream to detect the device being used
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS)).toDart;
      
      final tracks = stream.getAudioTracks().toDart;
      if (tracks.isNotEmpty) {
        final track = tracks.first;
        
        // Get label directly from track, which usually contains device name
        String deviceName = track.label;
        if (deviceName.isEmpty) {
          deviceName = 'Default Audio Device';
        }
        
        setState(() {
          _currentDeviceName = deviceName;
        });
        
        if (kDebugMode) {
          print('Current audio device: $deviceName');
          print('Track ID: ${track.id}');
          print('Track kind: ${track.kind}');
        }
        
        // Stop temporary stream
        for (final track in tracks) {
          track.stop();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to detect audio device: $e');
      }
      setState(() {
        _currentDeviceName = 'Detection Failed';
      });
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
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Record Viewer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          // Main content
          _buildMainContent(),
          // Top-right device info display
          if (kIsWeb) _buildDeviceInfo(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _lastFilePath != null && !_isRecording ? _playLast : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                    const SizedBox(width: 12),
                    if (kIsWeb)
                      ElevatedButton.icon(
                        onPressed: _lastFilePath != null && !_isRecording ? _downloadRecording : null,
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                      ),
                    if (kIsWeb) const SizedBox(width: 12),
                    if (kIsWeb)
                      ElevatedButton.icon(
                        onPressed: _lastFilePath != null ? _copyBlobUrl : null,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy URL'),
                      ),
                    if (kIsWeb) const SizedBox(width: 12),
                    if (kIsWeb)
                      ElevatedButton.icon(
                        onPressed: _lastFilePath != null && !_isRecording ? _uploadToGoogleDrive : null,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lastFilePath != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File: ${_lastFilePath!.split(RegExp(r"[\\/]")).last}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Blob URL: ${_lastFilePath!.substring(0, 50)}...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  const Text('No recording yet'),
              ],
            ),
          ],
        ),
      );
  }

  // Build device info display component
  Widget _buildDeviceInfo() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(179),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic,
              color: _isRecording ? Colors.red : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _currentDeviceName ?? ' waiting...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


