/// Example usage of OPFS storage with practice data models
import 'dart:typed_data';
import 'practice_data_models.dart';
import 'opfs_storage_service.dart';

/// Example class demonstrating OPFS storage usage
class OPFSStorageExample {
  
  static void Function(String)? _outputCallback;
  
  /// Check if OPFS is supported
  static Future<bool> checkOPFSSupport() async {
    final isSupported = OPFSStorageService.isSupported;
    print('OPFS Support: $isSupported');
    return isSupported;
  }

  /// Create and save a new practice group
  static Future<PracticeGroup> createAndSavePracticeGroup({
    required String title,
    required List<String> tags,
  }) async {
    // Generate new group ID
    final groupId = PracticeFileNaming.generateGroupId();
    final now = DateTime.now();

    // Create native practice item
    final nativeItem = PracticeFileNaming.createNativeItem(groupId);

    // Create practice group
    final group = PracticeGroup(
      id: groupId,
      title: title,
      createdAt: now,
      updatedAt: now,
      tags: tags,
      items: [nativeItem],
    );

    // Save to OPFS
    await group.saveToOPFS();
    
    print('Created and saved practice group: ${group.id}');
    return group;
  }

  /// Add a user practice item to existing group
  static Future<PracticeGroup> addUserPracticeItem(String groupId) async {
    // Load existing group
    final group = await PracticeGroup.loadFromOPFS(groupId);
    if (group == null) {
      throw Exception('Practice group $groupId not found');
    }

    // Create new user item
    final userItem = PracticeFileNaming.createUserItem(groupId, group.items);
    
    // Update group with new item
    final updatedGroup = group.copyWith(
      items: [...group.items, userItem],
      updatedAt: DateTime.now(),
    );

    // Save updated group
    await updatedGroup.saveToOPFS();
    
    print('Added user practice item: ${userItem.id}');
    return updatedGroup;
  }

  /// Save audio file and annotations
  static Future<void> saveAudioWithAnnotations({
    required String groupId,
    required String itemId,
    required Uint8List audioData,
    required String transcript,
    required List<WordAnnotation> annotations,
    required double duration,
    int sampleRate = 44100,
  }) async {
    // Generate file names
    final audioFileName = PracticeFileNaming.audioFile(groupId, itemId);
    final annotationFileName = PracticeFileNaming.annotationFile(groupId, itemId);

    // Save audio file
    await AudioAnnotations.saveAudioToOPFS(audioFileName, audioData);

    // Create and save annotations
    final audioAnnotations = AudioAnnotations(
      audioFile: audioFileName,
      duration: duration,
      sampleRate: sampleRate,
      transcript: transcript,
      annotations: annotations,
      processed: true,
    );

    await audioAnnotations.saveToOPFS(annotationFileName);
    
    print('Saved audio and annotations for $groupId.$itemId');
  }

  /// Load audio file and annotations
  static Future<Map<String, dynamic>?> loadAudioWithAnnotations({
    required String groupId,
    required String itemId,
  }) async {
    try {
      // Generate file names
      final audioFileName = PracticeFileNaming.audioFile(groupId, itemId);
      final annotationFileName = PracticeFileNaming.annotationFile(groupId, itemId);

      // Load audio data
      final audioData = await AudioAnnotations.loadAudioFromOPFS(audioFileName);
      if (audioData == null) {
        print('Audio file not found: $audioFileName');
        return null;
      }

      // Load annotations
      final annotations = await AudioAnnotations.loadFromOPFS(annotationFileName);
      if (annotations == null) {
        print('Annotations not found: $annotationFileName');
        return null;
      }

      return {
        'audioData': audioData,
        'annotations': annotations,
      };
    } catch (e) {
      print('Failed to load audio with annotations: $e');
      return null;
    }
  }

  /// List all practice groups with summary
  static Future<void> listAllPracticeGroups() async {
    try {
      final groups = await PracticeGroup.listAllFromOPFS();
      
      print('\n=== Practice Groups ===');
      print('Total groups: ${groups.length}');
      
      for (final group in groups) {
        print('\nGroup: ${group.title} (${group.id})');
        print('  Created: ${group.createdAt}');
        print('  Updated: ${group.updatedAt}');
        print('  Tags: ${group.tags.join(', ')}');
        print('  Items: ${group.items.length}');
        print('  Native item: ${group.nativeItem?.id ?? 'None'}');
        print('  User items: ${group.userItems.length}');
      }
    } catch (e) {
      print('Failed to list practice groups: $e');
    }
  }

  /// Get storage usage information
  static Future<void> showStorageInfo() async {
    try {
      final info = await OPFSStorageService.getStorageInfo();
      
      print('\n=== Storage Information ===');
      print('Total files: ${info['totalFiles']}');
      print('Total size: ${(info['totalSize'] / 1024).toStringAsFixed(2)} KB');
      
      print('\nFiles:');
      for (final fileInfo in info['files'] as List) {
        final name = fileInfo['name'] as String;
        final size = fileInfo['size'] as int;
        print('  $name: ${(size / 1024).toStringAsFixed(2)} KB');
      }
    } catch (e) {
      print('Failed to get storage info: $e');
    }
  }

  /// Delete a practice group and all related files
  static Future<void> deletePracticeGroup(String groupId) async {
    try {
      final group = await PracticeGroup.loadFromOPFS(groupId);
      if (group == null) {
        throw Exception('Practice group $groupId not found');
      }

      await group.deleteFromOPFS();
      print('Deleted practice group: $groupId');
    } catch (e) {
      print('Failed to delete practice group $groupId: $e');
    }
  }

  /// Clean up all storage (use with caution!)
  static Future<void> clearAllStorage() async {
    try {
      await OPFSStorageService.clearAllFiles();
      print('All storage cleared');
    } catch (e) {
      print('Failed to clear storage: $e');
    }
  }

  /// Example workflow: Create, use, and manage practice data
  static Future<void> exampleWorkflow() async {
    print('\n=== OPFS Storage Example Workflow ===');

    // Check support
    if (!await checkOPFSSupport()) {
      print('OPFS not supported, exiting...');
      return;
    }

    try {
      // Create a practice group
      final group = await createAndSavePracticeGroup(
        title: 'English Pronunciation Practice',
        tags: ['english', 'pronunciation', 'beginner'],
      );

      // Add user practice items
      await addUserPracticeItem(group.id);
      await addUserPracticeItem(group.id);

      // Create sample annotations
      final annotations = [
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
      ];

      // Save audio with annotations (using dummy data)
      final dummyAudioData = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      await saveAudioWithAnnotations(
        groupId: group.id,
        itemId: PracticeFileNaming.nativeItemId,
        audioData: dummyAudioData,
        transcript: 'Hello World',
        annotations: annotations,
        duration: 1.0,
      );

      // List all groups
      await listAllPracticeGroups();

      // Show storage info
      await showStorageInfo();

      // Load audio with annotations
      final loadedData = await loadAudioWithAnnotations(
        groupId: group.id,
        itemId: PracticeFileNaming.nativeItemId,
      );

      if (loadedData != null) {
        final audioData = loadedData['audioData'] as Uint8List;
        final annotations = loadedData['annotations'] as AudioAnnotations;
        print('\nLoaded audio data: ${audioData.length} bytes');
        print('Loaded annotations: ${annotations.annotations.length} words');
      }

    } catch (e) {
      print('Example workflow failed: $e');
    }
  }
}

/// Run the example
Future<void> main() async {
  await OPFSStorageExample.exampleWorkflow();
}