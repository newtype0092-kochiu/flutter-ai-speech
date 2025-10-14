/// OPFS (Origin Private File System) storage service for Flutter Web
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// Service class for handling OPFS operations
class OPFSStorageService {
  static const String _rootDirectoryName = 'flutter_ai_speech';
  
  /// Check if OPFS is supported in current browser
  static bool get isSupported {
    try {
      return js.context.hasProperty('navigator') &&
             js.context['navigator'] != null &&
             js.context['navigator'].hasProperty('storage') &&
             js.context['navigator']['storage'] != null &&
             js.context['navigator']['storage'].hasProperty('getDirectory');
    } catch (e) {
      return false;
    }
  }

  /// Get the OPFS root directory handle
  static Future<dynamic> _getRootDirectoryHandle() async {
    if (!isSupported) {
      throw UnsupportedError('OPFS is not supported in this browser');
    }

    try {
      final navigator = js.context['navigator'];
      final storage = navigator['storage'];
      
      // Get the origin private file system directory
      final rootHandle = await js_util.promiseToFuture(
        js_util.callMethod(storage, 'getDirectory', [])
      );

      // Create or get our app directory
      final appHandle = await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'getDirectoryHandle', [
          _rootDirectoryName,
          js_util.jsify({'create': true})
        ])
      );

      return appHandle;
    } catch (e) {
      throw Exception('Failed to get OPFS root directory: $e');
    }
  }

  /// Save text content to a file
  static Future<void> saveTextFile(String fileName, String content) async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      
      // Create or get file handle
      final fileHandle = await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'getFileHandle', [
          fileName,
          js_util.jsify({'create': true})
        ])
      );

      // Create writable stream
      final writable = await js_util.promiseToFuture(
        js_util.callMethod(fileHandle, 'createWritable', [])
      );

      // Write content
      await js_util.promiseToFuture(
        js_util.callMethod(writable, 'write', [content])
      );

      // Close the stream
      await js_util.promiseToFuture(
        js_util.callMethod(writable, 'close', [])
      );
      
      print('Successfully saved text file: $fileName');
    } catch (e) {
      throw Exception('Failed to save text file $fileName: $e');
    }
  }

  /// Save binary data to a file
  static Future<void> saveBinaryFile(String fileName, Uint8List data) async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      
      // Create or get file handle
      final fileHandle = await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'getFileHandle', [
          fileName,
          js_util.jsify({'create': true})
        ])
      );

      // Create writable stream
      final writable = await js_util.promiseToFuture(
        js_util.callMethod(fileHandle, 'createWritable', [])
      );

      // Write binary data
      await js_util.promiseToFuture(
        js_util.callMethod(writable, 'write', [data])
      );

      // Close the stream
      await js_util.promiseToFuture(
        js_util.callMethod(writable, 'close', [])
      );
      
      print('Successfully saved binary file: $fileName');
    } catch (e) {
      throw Exception('Failed to save binary file $fileName: $e');
    }
  }

  /// Read text content from a file
  static Future<String> readTextFile(String fileName) async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      
      // Get file handle
      final fileHandle = await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'getFileHandle', [fileName])
      );

      // Get file
      final file = await js_util.promiseToFuture(
        js_util.callMethod(fileHandle, 'getFile', [])
      );

      // Read as text
      final content = await js_util.promiseToFuture(
        js_util.callMethod(file, 'text', [])
      );

      return content as String;
    } catch (e) {
      throw Exception('Failed to read text file $fileName: $e');
    }
  }

  /// Read binary data from a file
  static Future<Uint8List> readBinaryFile(String fileName) async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      
      // Get file handle
      final fileHandle = await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'getFileHandle', [fileName])
      );

      // Get file
      final file = await js_util.promiseToFuture(
        js_util.callMethod(fileHandle, 'getFile', [])
      );

      // Read as array buffer
      final arrayBuffer = await js_util.promiseToFuture(
        js_util.callMethod(file, 'arrayBuffer', [])
      );

      // Convert to Uint8List
      final uint8List = Uint8List.fromList(
        (js_util.dartify(arrayBuffer) as List).cast<int>()
      );

      return uint8List;
    } catch (e) {
      throw Exception('Failed to read binary file $fileName: $e');
    }
  }

  /// Check if a file exists
  static Future<bool> fileExists(String fileName) async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      
      // Try to get file handle
      await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'getFileHandle', [fileName])
      );
      
      return true;
    } catch (e) {
      // File doesn't exist or other error
      return false;
    }
  }

  /// Delete a file
  static Future<void> deleteFile(String fileName) async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      
      // Remove the file
      await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'removeEntry', [fileName])
      );
      
      print('Successfully deleted file: $fileName');
    } catch (e) {
      throw Exception('Failed to delete file $fileName: $e');
    }
  }

  /// List all files in the root directory
  static Future<List<String>> listFiles() async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      final fileNames = <String>[];
      
      // Get async iterator for entries
      final entries = js_util.callMethod(rootHandle, 'entries', []);
      
      // Iterate through entries
      while (true) {
        final result = await js_util.promiseToFuture(
          js_util.callMethod(entries, 'next', [])
        );
        
        final done = js_util.getProperty(result, 'done') as bool;
        if (done) break;
        
        final value = js_util.getProperty(result, 'value');
        final name = js_util.getProperty(value, '0') as String;
        final handle = js_util.getProperty(value, '1');
        
        // Check if it's a file (not directory)
        final kind = js_util.getProperty(handle, 'kind') as String;
        if (kind == 'file') {
          fileNames.add(name);
        }
      }
      
      return fileNames;
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }

  /// Get file size
  static Future<int> getFileSize(String fileName) async {
    try {
      final rootHandle = await _getRootDirectoryHandle();
      
      // Get file handle
      final fileHandle = await js_util.promiseToFuture(
        js_util.callMethod(rootHandle, 'getFileHandle', [fileName])
      );

      // Get file
      final file = await js_util.promiseToFuture(
        js_util.callMethod(fileHandle, 'getFile', [])
      );

      // Get size
      final size = js_util.getProperty(file, 'size') as int;
      return size;
    } catch (e) {
      throw Exception('Failed to get file size for $fileName: $e');
    }
  }

  /// Save JSON data to file
  static Future<void> saveJsonFile(String fileName, Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data);
    await saveTextFile(fileName, jsonString);
  }

  /// Read JSON data from file
  static Future<Map<String, dynamic>> readJsonFile(String fileName) async {
    final jsonString = await readTextFile(fileName);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Clear all files (use with caution!)
  static Future<void> clearAllFiles() async {
    try {
      final fileNames = await listFiles();
      for (final fileName in fileNames) {
        await deleteFile(fileName);
      }
      print('Successfully cleared all files');
    } catch (e) {
      throw Exception('Failed to clear all files: $e');
    }
  }

  /// Get storage usage information
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final fileNames = await listFiles();
      int totalSize = 0;
      final fileInfo = <Map<String, dynamic>>[];

      for (final fileName in fileNames) {
        final size = await getFileSize(fileName);
        totalSize += size;
        fileInfo.add({
          'name': fileName,
          'size': size,
        });
      }

      return {
        'totalFiles': fileNames.length,
        'totalSize': totalSize,
        'files': fileInfo,
      };
    } catch (e) {
      throw Exception('Failed to get storage info: $e');
    }
  }
}