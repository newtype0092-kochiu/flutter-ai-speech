import 'dart:typed_data';
import 'dart:math';

class AudioDataProcessor {
  
  /// Extract audio sample data from byte data
  static Future<List<double>> extractWaveformDataFromBytes(List<int> bytesData) async {
    try {
      final bytes = Uint8List.fromList(bytesData);
      
      if (bytes.length < 44) {
        throw Exception('Invalid WAV file: too small');
      }
      
      // Parse WAV file header
      final header = _parseWavHeader(bytes);
      if (header == null) {
        // Try to display header information for debugging
        final riffId = bytes.length >= 4 ? String.fromCharCodes(bytes.sublist(0, 4)) : 'N/A';
        final waveId = bytes.length >= 12 ? String.fromCharCodes(bytes.sublist(8, 12)) : 'N/A';
        throw Exception('Invalid WAV file format. RIFF: $riffId, WAVE: $waveId, Size: ${bytes.length}');
      }
      
      // Extract audio data portion
      final dataOffset = header['dataOffset'] as int;
      final audioData = bytes.sublist(dataOffset);
      
      // Parse audio samples according to bit depth
      List<double> samples;
      if (header['bitsPerSample'] == 16) {
        samples = _parse16BitSamples(audioData);
      } else if (header['bitsPerSample'] == 8) {
        samples = _parse8BitSamples(audioData);
      } else if (header['bitsPerSample'] == 24) {
        samples = _parse24BitSamples(audioData);
      } else if (header['bitsPerSample'] == 32) {
        samples = _parse32BitSamples(audioData);
      } else {
        throw Exception('Unsupported bit depth: ${header['bitsPerSample']}');
      }
      
      // If stereo, convert to mono
      if (header['numChannels'] == 2) {
        samples = _stereoToMono(samples);
      }
      
      return samples;
    } catch (e) {
      throw Exception('Error processing audio data: $e');
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
  
  /// Parse 16-bit audio samples
  static List<double> _parse16BitSamples(Uint8List audioData) {
    final samples = <double>[];
    for (int i = 0; i < audioData.length - 1; i += 2) {
      final sample = _readLittleEndian16(audioData, i);
      // Convert to signed 16-bit integer
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      // Normalize to [-1, 1] range
      samples.add(signedSample / 32767.0);
    }
    return samples;
  }
  
  /// Parse 8-bit audio samples
  static List<double> _parse8BitSamples(Uint8List audioData) {
    final samples = <double>[];
    for (int i = 0; i < audioData.length; i++) {
      // 8-bit audio is usually unsigned, range [0, 255]
      final sample = audioData[i];
      // Convert to signed and normalize to [-1, 1] range
      samples.add((sample - 128) / 127.0);
    }
    return samples;
  }
  
  /// Parse 24-bit audio samples
  static List<double> _parse24BitSamples(Uint8List audioData) {
    final samples = <double>[];
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
      samples.add(sample / 8388607.0);
    }
    return samples;
  }
  
  /// Parse 32-bit audio samples
  static List<double> _parse32BitSamples(Uint8List audioData) {
    final samples = <double>[];
    for (int i = 0; i < audioData.length - 3; i += 4) {
      // Read 32-bit little-endian
      int sample = _readLittleEndian32(audioData, i);
      
      // Convert to signed 32-bit integer
      if (sample > 0x7FFFFFFF) {
        sample -= 0x100000000;
      }
      
      // Normalize to [-1, 1] range
      samples.add(sample / 2147483647.0);
    }
    return samples;
  }
  
  /// Convert stereo to mono
  static List<double> _stereoToMono(List<double> stereoSamples) {
    final monoSamples = <double>[];
    for (int i = 0; i < stereoSamples.length - 1; i += 2) {
      final left = stereoSamples[i];
      final right = stereoSamples[i + 1];
      monoSamples.add((left + right) / 2.0);
    }
    return monoSamples;
  }
  
  /// Downsample audio data to reduce data points and improve rendering performance
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
}