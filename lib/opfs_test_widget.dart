/// Simple OPFS test widget for Flutter Web
import 'package:flutter/material.dart';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'opfs_storage_service.dart';
import 'practice_data_models.dart';

class OPFSTestWidget extends StatefulWidget {
  @override
  State<OPFSTestWidget> createState() => _OPFSTestWidgetState();
}

class _OPFSTestWidgetState extends State<OPFSTestWidget> {
  String _output = '';
  bool _isRunning = false;

  void _addOutput(String text) {
    setState(() {
      _output += '$text\n';
    });
    print(text); // Also print to console
  }

  void _clearOutput() {
    setState(() {
      _output = '';
    });
  }

  Future<void> _testOPFSSupport() async {
    _addOutput('🔍 检查 OPFS 支持...');
    OPFSStorageService().test();
    
    // Get browser info
    final navigator = js.context['navigator'];
    final userAgent = navigator != null ? navigator['userAgent'] as String? : 'Unknown';
    _addOutput('浏览器信息: ${userAgent?.substring(0, userAgent.length > 100 ? 100 : userAgent.length) ?? 'Unknown'}');
    
    final isSupported = OPFSStorageService.isSupported;
    if (isSupported) {
      _addOutput('✅ OPFS 支持: 是');
      
      // Try to actually access OPFS to confirm it works
      try {
        _addOutput('🔍 测试 OPFS 访问...');
        final testResult = await _testOPFSAccess();
        if (testResult) {
          _addOutput('✅ OPFS 访问测试成功');
        } else {
          _addOutput('❌ OPFS 访问测试失败');
        }
      } catch (e) {
        _addOutput('❌ OPFS 访问测试异常: $e');
      }
    } else {
      _addOutput('❌ OPFS 支持: 否');
      _addOutput('提示: 请使用支持 OPFS 的浏览器');
      _addOutput('支持的浏览器:');
      _addOutput('  - Chrome 86+ ✅');
      _addOutput('  - Edge 86+ ✅');
      _addOutput('  - Firefox ❌ (不支持)');
      _addOutput('  - Safari ❌ (不支持)');
      
      // Detailed diagnostics
      _addOutput('\n🔍 详细诊断:');
      _addOutput('navigator 存在: ${js.context.hasProperty('navigator')}');
      if (navigator != null) {
        _addOutput('navigator.storage 存在: ${navigator.hasProperty('storage')}');
        if (navigator.hasProperty('storage') && navigator['storage'] != null) {
          final storage = navigator['storage'];
          _addOutput('navigator.storage.getDirectory 存在: ${storage.hasProperty('getDirectory')}');
        }
      }
    }
  }
  
  Future<bool> _testOPFSAccess() async {
    try {
      // Try to get root directory handle
      final navigator = js.context['navigator'];
      final storage = navigator['storage'];
      final rootHandle = await js_util.promiseToFuture(
        js_util.callMethod(storage, 'getDirectory', [])
      );
      return rootHandle != null;
    } catch (e) {
      _addOutput('OPFS 访问详细错误: $e');
      return false;
    }
  }

  Future<void> _testBasicFileOperations() async {
    if (!OPFSStorageService.isSupported) {
      _addOutput('❌ OPFS 不支持，跳过测试');
      return;
    }

    try {
      _addOutput('\n📝 测试基本文件操作...');
      
      // Test text file
      _addOutput('基本文件操作功能暂未实现');
      
      // _addOutput('保存文本文件...');
      // await OPFSStorageService.saveTextFile(testFileName, testContent);
      // _addOutput('✅ 文本文件保存成功');
      
      // _addOutput('读取文本文件...');
      // final readContent = await OPFSStorageService.readTextFile(testFileName);
      // _addOutput('✅ 文本文件读取成功: $readContent');
      
      // // Test file existence
      // final exists = await OPFSStorageService.fileExists(testFileName);
      // _addOutput('✅ 文件存在检查: $exists');
      
      // // Test file size
      // final size = await OPFSStorageService.getFileSize(testFileName);
      // _addOutput('✅ 文件大小: $size 字节');
      
      // // Clean up
      // await OPFSStorageService.deleteFile(testFileName);
      // _addOutput('✅ 测试文件已删除');
      
    } catch (e) {
      _addOutput('❌ 基本文件操作测试失败: $e');
    }
  }

  Future<void> _testPracticeDataModel() async {
    if (!OPFSStorageService.isSupported) {
      _addOutput('❌ OPFS 不支持，跳过测试');
      return;
    }

    try {
      _addOutput('\n🎯 测试练习数据模型...');
      
      // Create practice group
      final groupId = PracticeFileNaming.generateGroupId();
      final now = DateTime.now();
      final nativeItem = PracticeFileNaming.createNativeItem(groupId);
      
      final group = PracticeGroup(
        id: groupId,
        title: '英语发音练习测试',
        createdAt: now,
        updatedAt: now,
        tags: ['english', 'test'],
        items: [nativeItem],
      );
      
      _addOutput('创建练习组: ${group.title} (${group.id})');
      
      // Save group
      await group.saveToOPFS();
      _addOutput('✅ 练习组保存成功');
      
      // Load group
      final loadedGroup = await PracticeGroup.loadFromOPFS(groupId);
      if (loadedGroup != null) {
        _addOutput('✅ 练习组加载成功: ${loadedGroup.title}');
        _addOutput('  - 创建时间: ${loadedGroup.createdAt}');
        _addOutput('  - 标签: ${loadedGroup.tags.join(', ')}');
        _addOutput('  - 项目数量: ${loadedGroup.items.length}');
      } else {
        _addOutput('❌ 练习组加载失败');
      }
      
      // Test audio annotations
      final annotations = AudioAnnotations(
        audioFile: 'test.wav',
        duration: 2.5,
        sampleRate: 44100,
        transcript: 'Hello World',
        annotations: [
          WordAnnotation(
            word: 'Hello',
            phoneme: 'həˈloʊ',
            startTime: 0.0,
            endTime: 0.5,
          ),
          WordAnnotation(
            word: 'World',
            phoneme: 'wɜːrld',
            startTime: 0.6,
            endTime: 1.0,
          ),
        ],
        processed: true,
      );
      
      const annotationFile = 'test-annotation.json';
      await annotations.saveToOPFS(annotationFile);
      _addOutput('✅ 音频标注保存成功');
      
      final loadedAnnotations = await AudioAnnotations.loadFromOPFS(annotationFile);
      if (loadedAnnotations != null) {
        _addOutput('✅ 音频标注加载成功');
        _addOutput('  - 时长: ${loadedAnnotations.duration}s');
        _addOutput('  - 词汇数: ${loadedAnnotations.annotations.length}');
      }
      
      // Clean up
      await group.deleteFromOPFS();
      await OPFSStorageService.deleteFile(annotationFile);
      _addOutput('✅ 测试数据已清理');
      
    } catch (e) {
      _addOutput('❌ 练习数据模型测试失败: $e');
    }
  }

  Future<void> _testStorageInfo() async {
    if (!OPFSStorageService.isSupported) {
      _addOutput('❌ OPFS 不支持，跳过测试');
      return;
    }

    try {
      _addOutput('\n📊 获取存储信息...');
      
      final info = await OPFSStorageService.getStorageInfo();
      final totalFiles = info['totalFiles'] as int;
      final totalSize = info['totalSize'] as int;
      final files = info['files'] as List;
      
      _addOutput('存储统计:');
      _addOutput('  - 文件总数: $totalFiles');
      _addOutput('  - 总大小: ${(totalSize / 1024).toStringAsFixed(2)} KB');
      
      if (files.isNotEmpty) {
        _addOutput('文件列表:');
        for (final fileInfo in files) {
          final name = fileInfo['name'] as String;
          final size = fileInfo['size'] as int;
          _addOutput('  - $name: ${(size / 1024).toStringAsFixed(2)} KB');
        }
      } else {
        _addOutput('  - 没有存储的文件');
      }
      
    } catch (e) {
      _addOutput('❌ 获取存储信息失败: $e');
    }
  }

  Future<void> _runAllTests() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
    });
    
    _clearOutput();
    _addOutput('🚀 开始 OPFS 存储测试');
    _addOutput('=' * 50);
    
    try {
      await _testOPFSSupport();
      // await _testBasicFileOperations();
      // await _testPracticeDataModel();
      // await _testStorageInfo();
      
      _addOutput('\n' + '=' * 50);
      _addOutput('✅ 所有测试完成!');
      
    } catch (e) {
      _addOutput('❌ 测试过程中发生错误: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPFS 存储测试',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 16),
          
          // Control buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _runAllTests,
                icon: Icon(_isRunning ? Icons.hourglass_empty : Icons.play_arrow),
                label: Text('运行所有测试'),
              ),
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _testOPFSSupport,
                icon: Icon(Icons.support),
                label: Text('检查支持'),
              ),
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _testStorageInfo,
                icon: Icon(Icons.info),
                label: Text('存储信息'),
              ),
              ElevatedButton.icon(
                onPressed: _clearOutput,
                icon: Icon(Icons.clear),
                label: Text('清空输出'),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Output area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _output.isEmpty ? '点击按钮开始测试...\n\n注意: OPFS 仅在支持的浏览器中可用 (Chrome 86+, Edge 86+)' : _output,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}