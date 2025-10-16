import 'dart:convert';
import 'dart:typed_data';

/// Service class for handling OPFS (Origin Private File System) operations on Flutter Web.
class OPFSStorageService {
  Future<void> test() async {
  }


  /// Check if OPFS is supported in current browser
  static bool get isSupported {
    return false;
  }

  /// Save text content to a file
  static Future<void> saveTextFile(String fileName, String content) async {
    print('Mock: Saved text file $fileName');
  }

  /// Save binary data to a file
  static Future<void> saveBinaryFile(String fileName, Uint8List data) async {
    print('Mock: Saved binary file $fileName with ${data.length} bytes');
  }

  /// Read text content from a file
  static Future<String> readTextFile(String fileName) async {
    return 'Mock content for $fileName';
  }

  /// Read binary data from a file
  static Future<Uint8List> readBinaryFile(String fileName) async {
    return Uint8List.fromList([0, 1, 2, 3, 4]); // Mock data
  }

  /// Check if a file exists
  static Future<bool> fileExists(String fileName) async {
    return false;
  }

  /// Delete a file
  static Future<void> deleteFile(String fileName) async {
    print('Mock: Deleted file $fileName');
  }

  /// List all files in the root directory
  static Future<List<String>> listFiles() async {
    return <String>[]; // Empty list
  }

  /// Get file size
  static Future<int> getFileSize(String fileName) async {
    return 0;
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
    print('Mock: All files cleared');
  }

  /// Get storage usage information
  static Future<Map<String, dynamic>> getStorageInfo() async {
    return {
      'totalFiles': 0,
      'totalSize': 0,
      'files': <Map<String, dynamic>>[],
    };
  }
}