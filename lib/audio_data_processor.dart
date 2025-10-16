import 'dart:typed_data';
import 'dart:math';
import 'dart:async';

class AudioDataProcessor {
  
  /// Extract audio sample data from byte data (legacy method for backward compatibility)
  static Future<List<double>> extractWaveformDataFromBytes(List<int> bytesData) async {
    final samples = <double>[];
    
    await for (final sample in extractWaveformDataFromBytesStream(bytesData)) {
      samples.add(sample);
    }
    
    return samples;
  }
  
  /// Stream-based audio sample extraction - more memory efficient
  static Stream<double> extractWaveformDataFromBytesStream(List<int> bytesData) async* {
    final bytes = Uint8List.fromList(bytesData);
    
    if (bytes.length < 44) {
      throw Exception('Invalid WAV file: too small');
    }
    
    // Parse WAV file header
    final header = _parseWavHeader(bytes);
    if (header == null) {
      final riffId = bytes.length >= 4 ? String.fromCharCodes(bytes.sublist(0, 4)) : 'N/A';
      final waveId = bytes.length >= 12 ? String.fromCharCodes(bytes.sublist(8, 12)) : 'N/A';
      throw Exception('Invalid WAV file format. RIFF: $riffId, WAVE: $waveId, Size: ${bytes.length}');
    }
    
    // Extract audio data portion
    final dataOffset = header['dataOffset'] as int;
    final audioData = bytes.sublist(dataOffset);
    final bitsPerSample = header['bitsPerSample'] as int;
    final numChannels = header['numChannels'] as int;
    
    // Create sample parser based on bit depth
    Stream<double> sampleStream;
    switch (bitsPerSample) {
      case 8:
        sampleStream = _parse8BitSamplesStream(audioData);
        break;
      case 16:
        sampleStream = _parse16BitSamplesStream(audioData);
        break;
      case 24:
        sampleStream = _parse24BitSamplesStream(audioData);
        break;
      case 32:
        sampleStream = _parse32BitSamplesStream(audioData);
        break;
      default:
        throw Exception('Unsupported bit depth: $bitsPerSample');
    }
    
    // Convert stereo to mono if needed
    if (numChannels == 2) {
      await for (final monoSample in _stereoToMonoStream(sampleStream)) {
        yield monoSample;
      }
    } else {
      await for (final sample in sampleStream) {
        yield sample;
      }
    }
  }
  
  /// Parse WAV file header
  static Map<String, dynamic>? _parseWavHeader(Uint8List bytes) {
    try {
      // Check RIFF identifier
      final riffId = String.fromCharCodes(bytes.sublist(0, 4));
      if (riffId != 'RIFF') return null;
      
      // Check WAVE identifier
      final waveId = String.fromCharCodes(bytes.sublist(8, 12));
      if (waveId != 'WAVE') return null;
      
      // Find fmt chunk
      int offset = 12; // Start after WAVE identifier
      Map<String, int>? fmtInfo;
      int dataOffset = -1;
      
      while (offset < bytes.length - 8) {
        final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final chunkSize = _readLittleEndian32(bytes, offset + 4);
        
        if (chunkId == 'fmt ') {
          // Parse fmt chunk
          if (offset + 8 + 16 <= bytes.length) {
            final numChannels = _readLittleEndian16(bytes, offset + 8 + 2);
            final sampleRate = _readLittleEndian32(bytes, offset + 8 + 4);
            final bitsPerSample = _readLittleEndian16(bytes, offset + 8 + 14);
            
            fmtInfo = {
              'numChannels': numChannels,
              'sampleRate': sampleRate,
              'bitsPerSample': bitsPerSample,
            };
          }
        } else if (chunkId == 'data') {
          // Found data chunk
          dataOffset = offset + 8;
          break;
        }
        
        // Move to next chunk (note alignment)
        offset += 8 + ((chunkSize + 1) & ~1);
      }
      
      if (fmtInfo != null && dataOffset > 0) {
        return {
          ...fmtInfo,
          'dataOffset': dataOffset,
        };
      }
      
      return null;
    } catch (e) {
      print('WAV header parsing error: $e');
      return null;
    }
  }
  
  /// Read little-endian 16-bit integer
  static int _readLittleEndian16(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }
  
  /// Read little-endian 32-bit integer
  static int _readLittleEndian32(Uint8List bytes, int offset) {
    return bytes[offset] | 
           (bytes[offset + 1] << 8) |
           (bytes[offset + 2] << 16) |
           (bytes[offset + 3] << 24);
  }
  
  /// Parse 16-bit audio samples as stream
  static Stream<double> _parse16BitSamplesStream(Uint8List audioData) async* {
    for (int i = 0; i < audioData.length - 1; i += 2) {
      final sample = _readLittleEndian16(audioData, i);
      // Convert to signed 16-bit integer
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      // Normalize to [-1, 1] range
      yield signedSample / 32767.0;
    }
  }
  
  /// Parse 8-bit audio samples as stream
  static Stream<double> _parse8BitSamplesStream(Uint8List audioData) async* {
    for (int i = 0; i < audioData.length; i++) {
      // 8-bit audio is usually unsigned, range [0, 255]
      final sample = audioData[i];
      // Convert to signed and normalize to [-1, 1] range
      yield (sample - 128) / 127.0;
    }
  }
  
  /// Parse 24-bit audio samples as stream
  static Stream<double> _parse24BitSamplesStream(Uint8List audioData) async* {
    for (int i = 0; i < audioData.length - 2; i += 3) {
      // Read 24-bit little-endian
      int sample = audioData[i] | 
                   (audioData[i + 1] << 8) | 
                   (audioData[i + 2] << 16);
      
      // Convert to signed 24-bit integer
      if (sample > 0x7FFFFF) {
        sample -= 0x1000000;
      }
      
      // Normalize to [-1, 1] range
      yield sample / 8388607.0;
    }
  }
  
  /// Parse 32-bit audio samples as stream
  static Stream<double> _parse32BitSamplesStream(Uint8List audioData) async* {
    for (int i = 0; i < audioData.length - 3; i += 4) {
      // Read 32-bit little-endian
      int sample = _readLittleEndian32(audioData, i);
      
      // Convert to signed 32-bit integer
      if (sample > 0x7FFFFFFF) {
        sample -= 0x100000000;
      }
      
      // Normalize to [-1, 1] range
      yield sample / 2147483647.0;
    }
  }
  
  /// Convert stereo to mono stream
  static Stream<double> _stereoToMonoStream(Stream<double> stereoSamples) async* {
    double? leftSample;
    
    await for (final sample in stereoSamples) {
      if (leftSample == null) {
        leftSample = sample; // Store left channel
      } else {
        // We have both left and right, yield the average
        yield (leftSample + sample) / 2.0;
        leftSample = null; // Reset for next pair
      }
    }
  }
  
  /// Downsample audio data to reduce data points and improve rendering performance (legacy)
  static List<double> downsample(List<double> samples, int targetLength) {
    if (samples.length <= targetLength) {
      return samples;
    }
    
    final downsampledSamples = <double>[];
    final ratio = samples.length / targetLength;
    
    for (int i = 0; i < targetLength; i++) {
      final startIndex = (i * ratio).floor();
      final endIndex = ((i + 1) * ratio).floor().clamp(0, samples.length);
      
      // Calculate RMS value for this interval
      double sum = 0;
      int count = 0;
      for (int j = startIndex; j < endIndex; j++) {
        sum += samples[j] * samples[j];
        count++;
      }
      
      if (count > 0) {
        final rms = sqrt(sum / count);
        // Preserve the sign of the original signal
        final avgSign = samples.skip(startIndex).take(endIndex - startIndex)
            .map((s) => s.sign).reduce((a, b) => a + b) / count;
        downsampledSamples.add(rms * avgSign.sign);
      } else {
        downsampledSamples.add(0.0);
      }
    }
    
    return downsampledSamples;
  }
  
  /// Stream-based downsampling - more memory efficient
  static Stream<double> downsampleStream(Stream<double> sampleStream, int targetLength, int originalLength) async* {
    if (originalLength <= targetLength) {
      await for (final sample in sampleStream) {
        yield sample;
      }
      return;
    }
    
    final ratio = originalLength / targetLength;
    final buffer = <double>[];
    int currentTargetIndex = 0;
    int sampleIndex = 0;
    
    await for (final sample in sampleStream) {
      final targetIndexForThisSample = (sampleIndex / ratio).floor();
      
      if (targetIndexForThisSample == currentTargetIndex) {
        // This sample belongs to current target bucket
        buffer.add(sample);
      } else {
        // Process previous bucket if we have data
        if (buffer.isNotEmpty) {
          yield _calculateRMSFromBuffer(buffer);
          buffer.clear();
        }
        
        // Move to next target index
        currentTargetIndex = targetIndexForThisSample;
        buffer.add(sample);
      }
      
      sampleIndex++;
    }
    
    // Process final bucket
    if (buffer.isNotEmpty) {
      yield _calculateRMSFromBuffer(buffer);
    }
  }
  
  /// Calculate RMS value preserving signal sign
  static double _calculateRMSFromBuffer(List<double> buffer) {
    double sum = 0;
    double signSum = 0;
    
    for (final sample in buffer) {
      sum += sample * sample;
      signSum += sample.sign;
    }
    
    final rms = sqrt(sum / buffer.length);
    final avgSign = signSum / buffer.length;
    return rms * avgSign.sign;
  }
  
  /// Process audio file with streaming and optional chunked callback
  static Future<List<double>> processAudioFileStream(
    List<int> bytesData, {
    int? targetLength,
    void Function(double sample, int index)? onSample,
    void Function(List<double> chunk, int startIndex)? onChunk,
    int chunkSize = 1024,
  }) async {
    final samples = <double>[];
    final chunk = <double>[];
    int sampleIndex = 0;
    
    // Get original sample count for downsampling calculation
    int? originalLength;
    if (targetLength != null) {
      final tempSamples = await extractWaveformDataFromBytes(bytesData);
      originalLength = tempSamples.length;
    }
    
    Stream<double> stream = extractWaveformDataFromBytesStream(bytesData);
    
    // Apply downsampling if requested
    if (targetLength != null && originalLength != null) {
      stream = downsampleStream(stream, targetLength, originalLength);
    }
    
    await for (final sample in stream) {
      samples.add(sample);
      chunk.add(sample);
      
      // Call per-sample callback
      onSample?.call(sample, sampleIndex);
      
      // Call chunk callback when chunk is full
      if (chunk.length >= chunkSize) {
        onChunk?.call(List.from(chunk), sampleIndex - chunk.length + 1);
        chunk.clear();
      }
      
      sampleIndex++;
    }
    
    // Process final chunk if any
    if (chunk.isNotEmpty) {
      onChunk?.call(List.from(chunk), sampleIndex - chunk.length);
    }
    
    return samples;
  }
}