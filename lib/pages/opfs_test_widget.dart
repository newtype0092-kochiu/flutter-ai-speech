import 'package:flutter/material.dart';
import 'dart:js_interop';
import '../services/opfs_storage_service.dart';
import '../models/practice_data_models.dart';

// JS interop definitions for browser APIs
@JS()
external JSObject get window;

extension type JSWindow(JSObject _) implements JSObject {
  external JSNavigator get navigator;
}

extension type JSNavigator(JSObject _) implements JSObject {
  external JSString get userAgent;
  external JSStorageManager? get storage;
}

extension type JSStorageManager(JSObject _) implements JSObject {
  external JSPromise<JSFileSystemDirectoryHandle> getDirectory();
}

extension type JSFileSystemDirectoryHandle(JSObject _) implements JSObject {}

// Helper to get global context
JSWindow get globalContext => window as JSWindow;

/// Widget for testing OPFS storage functionality on Flutter Web.
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
    _addOutput('🔍 Checking OPFS support...');
    OPFSStorageService().test();
    
    // Get browser info
    final navigator = globalContext.navigator;
    final userAgent = navigator.userAgent.toDart;
    _addOutput('Browser info: ${userAgent.substring(0, userAgent.length > 100 ? 100 : userAgent.length)}');
    
    final isSupported = OPFSStorageService.isSupported;
    if (isSupported) {
      _addOutput('✅ OPFS support: Yes');
      
      // Try to actually access OPFS to confirm it works
      try {
        _addOutput('🔍 Testing OPFS access...');
        final testResult = await _testOPFSAccess();
        if (testResult) {
          _addOutput('✅ OPFS access test successful');
        } else {
          _addOutput('❌ OPFS access test failed');
        }
      } catch (e) {
        _addOutput('❌ OPFS access test exception: $e');
      }
    } else {
      _addOutput('❌ OPFS support: No');
      _addOutput('Hint: Please use a browser that supports OPFS');
      _addOutput('Supported browsers:');
      _addOutput('  - Chrome 86+ ✅');
      _addOutput('  - Edge 86+ ✅');
      _addOutput('  - Firefox ❌ (not supported)');
      _addOutput('  - Safari ❌ (not supported)');
      
      // Detailed diagnostics
      _addOutput('\n🔍 Detailed diagnostics:');
      _addOutput('navigator exists: true');
      final storage = navigator.storage;
      _addOutput('navigator.storage exists: ${storage != null}');
      if (storage != null) {
        _addOutput('navigator.storage.getDirectory exists: true');
      }
    }
  }
  
  Future<bool> _testOPFSAccess() async {
    try {
      // Try to get root directory handle
      final navigator = globalContext.navigator;
      final storage = navigator.storage;
      if (storage == null) {
        return false;
      }
      await storage.getDirectory().toDart;
      return true;
    } catch (e) {
      _addOutput('OPFS access detailed error: $e');
      return false;
    }
  }

  Future<void> _testPracticeDataModel() async {
    if (!OPFSStorageService.isSupported) {
      _addOutput('❌ OPFS not supported, skipping test');
      return;
    }

    try {
      _addOutput('\n🎯 Testing practice data model...');
      
      // Create practice group
      final groupId = PracticeFileNaming.generateGroupId();
      final now = DateTime.now();
      final nativeItem = PracticeFileNaming.createNativeItem(groupId);
      
      final group = PracticeGroup(
        id: groupId,
        title: 'English Pronunciation Practice Test',
        createdAt: now,
        updatedAt: now,
        tags: ['english', 'test'],
        items: [nativeItem],
      );
      
      _addOutput('Created practice group: ${group.title} (${group.id})');
      
      // Save group
      await group.saveToOPFS();
      _addOutput('✅ Practice group saved successfully');
      
      // Load group
      final loadedGroup = await PracticeGroup.loadFromOPFS(groupId);
      if (loadedGroup != null) {
        _addOutput('✅ Practice group loaded successfully: ${loadedGroup.title}');
        _addOutput('  - Created at: ${loadedGroup.createdAt}');
        _addOutput('  - Tags: ${loadedGroup.tags.join(', ')}');
        _addOutput('  - Item count: ${loadedGroup.items.length}');
      } else {
        _addOutput('❌ Practice group loading failed');
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
      _addOutput('✅ Audio annotation saved successfully');
      
      final loadedAnnotations = await AudioAnnotations.loadFromOPFS(annotationFile);
      if (loadedAnnotations != null) {
        _addOutput('✅ Audio annotation loaded successfully');
        _addOutput('  - Duration: ${loadedAnnotations.duration}s');
        _addOutput('  - Word count: ${loadedAnnotations.annotations.length}');
      }
      
      // Clean up
      await group.deleteFromOPFS();
      await OPFSStorageService.deleteFile(annotationFile);
      _addOutput('✅ Test data cleaned up');
      
    } catch (e) {
      _addOutput('❌ Practice data model test failed: $e');
    }
  }

  Future<void> _testStorageInfo() async {
    if (!OPFSStorageService.isSupported) {
      _addOutput('❌ OPFS not supported, skipping test');
      return;
    }

    try {
      _addOutput('\n📊 Getting storage info...');
      
      final info = await OPFSStorageService.getStorageInfo();
      final totalFiles = info['totalFiles'] as int;
      final totalSize = info['totalSize'] as int;
      final files = info['files'] as List;
      
      _addOutput('Storage statistics:');
      _addOutput('  - Total files: $totalFiles');
      _addOutput('  - Total size: ${(totalSize / 1024).toStringAsFixed(2)} KB');
      
      if (files.isNotEmpty) {
        _addOutput('File list:');
        for (final fileInfo in files) {
          final name = fileInfo['name'] as String;
          final size = fileInfo['size'] as int;
          _addOutput('  - $name: ${(size / 1024).toStringAsFixed(2)} KB');
        }
      } else {
        _addOutput('  - No stored files');
      }
      
    } catch (e) {
      _addOutput('❌ Failed to get storage info: $e');
    }
  }

  Future<void> _runAllTests() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
    });
    
    _clearOutput();
    _addOutput('🚀 Starting OPFS storage tests');
    _addOutput('=' * 50);
    
    try {
      await _testOPFSSupport();
      await _testPracticeDataModel();
      await _testStorageInfo();
      
      _addOutput('\n${'=' * 50}');
      _addOutput('✅ All tests completed!');
      
    } catch (e) {
      _addOutput('❌ Error occurred during testing: $e');
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
            'OPFS Storage Test',
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
                label: Text('Run All Tests'),
              ),
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _testOPFSSupport,
                icon: Icon(Icons.support),
                label: Text('Check Support'),
              ),
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _testStorageInfo,
                icon: Icon(Icons.info),
                label: Text('Storage Info'),
              ),
              ElevatedButton.icon(
                onPressed: _clearOutput,
                icon: Icon(Icons.clear),
                label: Text('Clear Output'),
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
                  _output.isEmpty ? 'Click button to start testing...\n\nNote: OPFS is only available in supported browsers (Chrome 86+, Edge 86+)' : _output,
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