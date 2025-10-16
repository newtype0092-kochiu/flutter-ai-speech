import 'audio_data_processor.dart';

/// 流式音频处理示例
class StreamAudioExample {
  
  /// 示例1: 基本流式处理
  static Future<void> basicStreamProcessing(List<int> audioBytes) async {
    print('开始流式处理音频数据...');
    
    int sampleCount = 0;
    double maxAmplitude = 0.0;
    double minAmplitude = 0.0;
    
    await for (final sample in AudioDataProcessor.extractWaveformDataFromBytesStream(audioBytes)) {
      // 实时处理每个样本
      maxAmplitude = sample > maxAmplitude ? sample : maxAmplitude;
      minAmplitude = sample < minAmplitude ? sample : minAmplitude;
      sampleCount++;
      
      // 每1000个样本输出一次进度
      if (sampleCount % 1000 == 0) {
        print('已处理 $sampleCount 个样本，当前振幅范围: [$minAmplitude, $maxAmplitude]');
      }
    }
    
    print('处理完成！总样本数: $sampleCount，最终振幅范围: [$minAmplitude, $maxAmplitude]');
  }
  
  /// 示例2: 分块处理
  static Future<void> chunkedProcessing(List<int> audioBytes) async {
    print('开始分块流式处理...');
    
    final result = await AudioDataProcessor.processAudioFileStream(
      audioBytes,
      targetLength: 500, // 降采样到500个点
      chunkSize: 50,     // 每50个样本为一块
      onSample: (sample, index) {
        // 可以在这里做实时分析
        if (index % 100 == 0) {
          print('样本 $index: $sample');
        }
      },
      onChunk: (chunk, startIndex) {
        // 处理每一块数据
        final rms = _calculateChunkRMS(chunk);
        print('块 ${startIndex}-${startIndex + chunk.length - 1}: RMS = ${rms.toStringAsFixed(4)}');
      },
    );
    
    print('分块处理完成！最终样本数: ${result.length}');
  }
  
  /// 示例3: 实时波形检测
  static Future<void> realtimeWaveformDetection(List<int> audioBytes) async {
    print('开始实时波形检测...');
    
    double runningAverage = 0.0;
    int windowSize = 100;
    final recentSamples = <double>[];
    
    await for (final sample in AudioDataProcessor.extractWaveformDataFromBytesStream(audioBytes)) {
      recentSamples.add(sample);
      
      // 保持滑动窗口大小
      if (recentSamples.length > windowSize) {
        recentSamples.removeAt(0);
      }
      
      // 计算当前窗口的平均值
      runningAverage = recentSamples.reduce((a, b) => a + b) / recentSamples.length;
      
      // 检测异常振幅
      if (sample.abs() > 0.8) {
        print('检测到高振幅信号: ${sample.toStringAsFixed(4)} (平均值: ${runningAverage.toStringAsFixed(4)})');
      }
      
      // 检测静音段
      if (recentSamples.length == windowSize && 
          recentSamples.every((s) => s.abs() < 0.01)) {
        print('检测到静音段 (窗口平均: ${runningAverage.toStringAsFixed(6)})');
      }
    }
  }
  
  /// 示例4: 内存使用对比
  static Future<void> memoryUsageComparison(List<int> audioBytes) async {
    print('=== 内存使用对比 ===');
    
    // 传统方式：一次性加载所有数据
    print('传统方式处理...');
    final stopwatch1 = Stopwatch()..start();
    final allSamples = await AudioDataProcessor.extractWaveformDataFromBytes(audioBytes);
    final downsampled1 = AudioDataProcessor.downsample(allSamples, 1000);
    stopwatch1.stop();
    
    print('传统方式: ${stopwatch1.elapsedMilliseconds}ms, 内存峰值: ${allSamples.length} 样本');
    
    // 流式方式：逐步处理
    print('流式方式处理...');
    final stopwatch2 = Stopwatch()..start();
    final streamResult = <double>[];
    await for (final sample in AudioDataProcessor.downsampleStream(
      AudioDataProcessor.extractWaveformDataFromBytesStream(audioBytes),
      1000,
      allSamples.length,
    )) {
      streamResult.add(sample);
    }
    stopwatch2.stop();
    
    print('流式方式: ${stopwatch2.elapsedMilliseconds}ms, 内存峰值: 约 ${streamResult.length} 样本');
    print('结果一致性: ${_compareLists(downsampled1, streamResult) ? "✓" : "✗"}');
  }
  
  /// 计算块的RMS值
  static double _calculateChunkRMS(List<double> chunk) {
    if (chunk.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in chunk) {
      sum += sample * sample;
    }
    
    return (sum / chunk.length).abs(); // 使用sqrt的简化版本
  }
  
  /// 比较两个列表是否近似相等
  static bool _compareLists(List<double> list1, List<double> list2, {double tolerance = 1e-6}) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if ((list1[i] - list2[i]).abs() > tolerance) {
        return false;
      }
    }
    
    return true;
  }
}