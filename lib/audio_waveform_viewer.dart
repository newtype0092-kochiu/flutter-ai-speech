import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:typed_data';
import 'audio_data_processor.dart';
import 'waveform_widget.dart';
import 'annotation_data.dart';

/// Complete audio waveform viewer component
class AudioWaveformViewer extends StatefulWidget {
  const AudioWaveformViewer({super.key});

  @override
  State<AudioWaveformViewer> createState() => _AudioWaveformViewerState();
}

class _AudioWaveformViewerState extends State<AudioWaveformViewer> {
  List<double> _waveformData = [];
  bool _isLoading = false;
  String? _fileName;
  String? _errorMessage;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  WaveformStyle _selectedStyle = WaveformStyle.line;
  Uint8List? _currentFileBytes; // Store file byte data
  AudioAnnotations? _annotations;
  bool _showAnnotations = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudioPlayer();
  }

  void _initializeAudioPlayer() {
    _durationSubscription = _audioPlayer?.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _positionSubscription = _audioPlayer?.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _playerStateSubscription = _audioPlayer?.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Pick audio file
  Future<void> _pickAudioFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'aac', 'm4a'],
        allowMultiple: false,
        withData: true, // Web platform requires file data
      );

      if (result != null) {
        final platformFile = result.files.single;
        final fileName = platformFile.name;
        
        setState(() {
          _fileName = fileName;
          _currentFileBytes = platformFile.bytes != null 
              ? Uint8List.fromList(platformFile.bytes!) 
              : null;
        });

        if (platformFile.bytes != null) {
          if (fileName.toLowerCase().endsWith('.wav')) {
            await _processAudioBytes(platformFile.bytes!, fileName);
          } else {
            setState(() {
              _waveformData = [];
              _errorMessage = 'Only WAV files support waveform display, but other formats can be played';
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Unable to read file data';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Process audio byte data using streaming approach
  Future<void> _processAudioBytes(List<int> bytes, String fileName) async {
    try {
      // Load annotations first
      final annotations = _loadAnnotationsForFile(fileName);
      
      // Use the new streaming API with progress callback
      final samples = await AudioDataProcessor.processAudioFileStream(
        bytes,
        targetLength: 1000, // Downsample to 1000 points for performance
        onChunk: (chunk, startIndex) {
          // Optional: Update UI with processing progress
          // This could show a progress bar during processing
          if (mounted && startIndex % 100 == 0) {
            print('Processing chunk starting at index $startIndex');
          }
        },
      );

      setState(() {
        _waveformData = samples;
        _annotations = annotations;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing audio data: $e';
        _waveformData = [];
      });
    }
  }

  /// Load annotations for the given audio file
  /// In production, this would load from a database or alignment file
  /// For now, it returns test data for demonstration
  AudioAnnotations? _loadAnnotationsForFile(String fileName) {
    // In a real application, you would:
    // 1. Check if alignment data exists for this file
    // 2. Load from database/file system
    // 3. Return null if no annotations available
    
    // For demonstration, return test data
    return _getTestAlignmentData();
  }

  /// Get test alignment data similar to Python example
  /// This simulates the get_test_native() function from your Python code
  AudioAnnotations? _getTestAlignmentData() {
    // Get audio duration, default to 3.0 seconds if not available
    final audioDuration = _duration.inMilliseconds > 0 
        ? _duration.inMilliseconds / 1000.0 
        : 3.0;
    
    // Simulate the Python test_alignment data structure
    // Original Python: (word, phoneme, start * ratio / rate, end * ratio / rate)
    const testAlignment = [
      ("TURN", "tɚn", 2, 10),
      ("OFF", "ʌf", 10.5, 19),
      ("THE", "ðʌ", 21, 25),
      ("LIGHT", "laɪt", 27, 40),
      ("PLEASE", "pliːz", 47, 63),
    ];
    
    return AudioAnnotations.fromAlignmentData(
      alignmentData: testAlignment.map((data) {
        // Convert frame positions to time (similar to Python's ratio calculation)
        const totalFrames = 67.0; // From Python example
        final startTime = (data.$3 / totalFrames) * audioDuration;
        final endTime = (data.$4 / totalFrames) * audioDuration;
        
        return (data.$1, data.$2, startTime, endTime);
      }).toList(),
      totalDuration: audioDuration,
    );
  }

  /// Toggle audio playback
  Future<void> _togglePlayback() async {
    if (_currentFileBytes == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer?.pause();
      } else {
        // Play using byte data
        await _audioPlayer?.play(BytesSource(_currentFileBytes!));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error playing audio: $e';
      });
    }
  }

  /// Stop playback
  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer?.stop();
      setState(() {
        _position = Duration.zero;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error stopping playback: $e';
      });
    }
  }

  /// Seek to specified position
  Future<void> _seekTo(double progress) async {
    if (_duration.inMilliseconds > 0) {
      final position = Duration(
        milliseconds: (_duration.inMilliseconds * progress).round(),
      );
      await _audioPlayer?.seek(position);
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Get playback progress
  double get _playbackProgress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Waveform Viewer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File picker button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickAudioFile,
              icon: const Icon(Icons.file_open),
              label: Text(_fileName ?? 'Select Audio File'),
            ),
            
            const SizedBox(height: 16),
            
            // Error message display
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Loading indicator
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Processing audio file...'),
                  ],
                ),
              ),
            
            // Waveform style selection
            if (_waveformData.isNotEmpty) ...[
              Text(
                'Waveform Style:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final style in WaveformStyle.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_getStyleName(style)),
                        selected: _selectedStyle == style,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedStyle = style;
                            });
                          }
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Annotation controls
              Row(
                children: [
                  Text(
                    'Show Annotations:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _showAnnotations,
                    onChanged: (value) {
                      setState(() {
                        _showAnnotations = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Waveform display area
            if (_waveformData.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    // File information
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'File: $_fileName',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Samples: ${_waveformData.length}'),
                          if (_duration.inMilliseconds > 0)
                            Text('Duration: ${_formatDuration(_duration)}'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Waveform chart
                    Expanded(
                      child: InteractiveWaveformWidget(
                        waveformData: _waveformData,
                        waveColor: Colors.blue,
                        progressColor: Colors.red,
                        style: _selectedStyle,
                        progress: _playbackProgress,
                        onSeek: _seekTo,
                        height: double.infinity,
                        annotations: _annotations,
                        showAnnotations: _showAnnotations,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Playback controls
            if (_currentFileBytes != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    // Time display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position)),
                        Text(_formatDuration(_duration)),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Progress bar
                    LinearProgressIndicator(
                      value: _playbackProgress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Playback control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _stopPlayback,
                          icon: const Icon(Icons.stop),
                          iconSize: 32,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _togglePlayback,
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          iconSize: 48,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStyleName(WaveformStyle style) {
    switch (style) {
      case WaveformStyle.line:
        return 'Line';
      case WaveformStyle.bars:
        return 'Bars';
      case WaveformStyle.filled:
        return 'Filled';
    }
  }
}