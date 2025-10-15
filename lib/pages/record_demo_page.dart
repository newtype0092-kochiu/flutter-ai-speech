import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class RecordDemoPage extends StatefulWidget {
  const RecordDemoPage({super.key});

  @override
  State<RecordDemoPage> createState() => _RecordDemoPageState();
}

class _RecordDemoPageState extends State<RecordDemoPage> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  String? _path;                // 录音生成的路径（Web 为 blob URL）
  bool _isRecording = false;    // 是否正在录音
  final _watch = Stopwatch();   // 仅用于在 UI 上显示录音时长
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _watch.stop();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // 申请权限（Web/桌面/移动各自处理）
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('麦克风权限未授予')),
        );
      }
      return;
    }

    // Web 上推荐 wav，兼容最好
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: 'record_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    setState(() {
      _isRecording = true;
      _path = null; // 新录音开始时重置
    });

    _watch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stop() async {
    final path = await _recorder.stop();
    _watch.stop();
    _ticker?.cancel();

    setState(() {
      _isRecording = false;
      _path = path; // Web: blob:xxxx ；非 Web：文件路径
    });
  }

  String _formatElapsed() {
    final ms = _watch.elapsedMilliseconds;
    final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$hundredths';
    // 如需更简洁：'$minutes:$seconds'
  }

  Future<void> _play() async {
    if (_path == null) return;

    // Web: blob: URL 用 UrlSource；原生平台用 DeviceFileSource
    if (kIsWeb) {
      await _player.stop();
      await _player.play(UrlSource(_path!));
    } else {
      await _player.stop();
      await _player.play(DeviceFileSource(_path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStop = _isRecording;
    final canPlay = !_isRecording && _path != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Web Demo (page)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isRecording ? '录音中… ${_formatElapsed()}' : '未录音',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRecording ? null : _start,
                    icon: const Icon(Icons.mic),
                    label: const Text('开始录音'),
                  ),
                  ElevatedButton.icon(
                    onPressed: canStop ? _stop : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
                  ),
                  ElevatedButton.icon(
                    onPressed: canPlay ? _play : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('播放'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_path != null) ...[
                const Text('录音已生成（Web 为 blob URL）：'),
                SelectableText(
                  _path!,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              const _Tips(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Divider(),
        Text(
          '提示：\n'
          '1) Web 必须在 HTTPS 或 localhost 下访问才能获取麦克风权限；\n'
          '2) Web 上推荐使用 wav 编码，兼容性最好；\n'
          '3) 播放时 Web 使用 UrlSource(blob:URL)，原生使用文件路径；\n'
          '4) 如果权限被拒绝，请到浏览器地址栏重新授权。',
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}
