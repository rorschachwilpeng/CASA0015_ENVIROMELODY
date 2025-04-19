import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/music_item.dart';
import 'dart:developer' as developer;
import 'firebase_service.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class MusicLibraryManager extends ChangeNotifier {
  // Singleton instance
  static final MusicLibraryManager _instance = MusicLibraryManager._internal();
  
  // Factory constructor to get the singleton instance
  factory MusicLibraryManager() => _instance;
  
  // Firebase 服务
  final FirebaseService _firebaseService = FirebaseService();
  
  // Music library list
  List<MusicItem> _musicLibrary = [];
  
  // Whether it has been initialized
  bool _initialized = false;
  
  // SharedPreferences的key
  final String _storageKey = 'music_library';
  
  // 是否使用 Firebase
  bool _useFirebase = true;
  
  // 获取是否使用 Firebase
  bool get useFirebase => _useFirebase;
  
  // 设置是否使用 Firebase
  set useFirebase(bool value) {
    _useFirebase = value;
    notifyListeners();
  }
  
  // Internal constructor
  MusicLibraryManager._internal();
  
  // Get all music
  List<MusicItem> get allMusic => List.unmodifiable(_musicLibrary);
  
  // Initialize and load from storage
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // 初始化 Firebase
      if (_useFirebase) {
        await _firebaseService.initialize();
        print('Firebase 服务初始化成功');
        
        // 从 Firebase 加载音乐
        await _loadFromFirebase();
      } else {
        // 从本地存储加载
        await loadFromStorage();
      }
      
      // Fix invalid URLs
      await fixInvalidUrls();
      
      _initialized = true;
      notifyListeners();
      print('音乐库初始化完成: ${_musicLibrary.length} 首音乐');
    } catch (e) {
      print('音乐库初始化失败: $e');
    }
  }
  
  // 从 Firebase 加载音乐
  Future<void> _loadFromFirebase() async {
    try {
      _musicLibrary = await _firebaseService.getAllMusic();
      print('从 Firebase 加载音乐库: ${_musicLibrary.length} 首音乐');
    } catch (e) {
      print('从 Firebase 加载音乐库失败: $e');
      // 失败时回退到本地存储
      await loadFromStorage();
    }
  }
  
  // 监听 Firebase 音乐变更
  Stream<List<MusicItem>> get musicListStream {
    if (_useFirebase) {
      return _firebaseService.musicListStream();
    } else {
      // 如果不使用 Firebase，返回一个空流
      return Stream.value(_musicLibrary);
    }
  }
  
  // Add music
  Future<void> addMusic(MusicItem music) async {
    // 检查音乐是否有有效的 ID
    final String id = music.id.isEmpty ? const Uuid().v4() : music.id;
    final musicWithId = music.id.isEmpty ? music.copyWith(id: id) : music;
    
    // 检查是否已经存在相同 ID 的音乐
    final existingIndex = _musicLibrary.indexWhere((item) => item.id == musicWithId.id);
    
    if (existingIndex >= 0) {
      // Update existing music
      _musicLibrary[existingIndex] = musicWithId;
    } else {
      // Add new music
      _musicLibrary.add(musicWithId);
    }
    
    if (_useFirebase) {
      // 检查音频是否是本地文件，如果是则上传到 Firebase Storage
      if (musicWithId.audioUrl.startsWith('file://')) {
        await _uploadAudioToFirebase(musicWithId);
      } else {
        // 直接添加到 Firestore
        await _firebaseService.addMusic(musicWithId);
      }
    } else {
      // Save to local storage
      await saveToStorage();
    }
    
    debugPrint('音乐已添加到库: ${musicWithId.title}');
    notifyListeners();
  }
  
  // 上传音频到 Firebase Storage
  Future<void> _uploadAudioToFirebase(MusicItem music) async {
    print('===== 开始上传音频到Firebase =====');
    try {
      // 检查 URL 是否是本地文件
      if (!music.audioUrl.startsWith('file://')) {
        print('不是本地文件路径，直接添加到Firestore: ${music.audioUrl}');
        await _firebaseService.addMusic(music);
        return;
      }
      
      // 提取文件路径
      final filePath = music.audioUrl.replaceFirst('file://', '');
      print('本地文件路径: $filePath');
      final file = File(filePath);
      
      if (await file.exists()) {
        print('文件存在，大小: ${await file.length()} 字节');
        
        // 生成文件名
        final fileName = '${music.id}${path.extension(filePath)}';
        print('上传文件名: $fileName');
        
        // 上传文件
        print('开始上传文件到Firebase Storage...');
        final downloadUrl = await _firebaseService.uploadAudioFile(file, fileName);
        print('文件上传成功，下载URL: $downloadUrl');
        
        // 创建带有新 URL 的音乐对象
        final updatedMusic = music.copyWith(audioUrl: downloadUrl);
        print('已更新音乐对象的音频URL');
        
        // 更新本地列表
        final index = _musicLibrary.indexWhere((item) => item.id == music.id);
        if (index >= 0) {
          _musicLibrary[index] = updatedMusic;
          print('已更新本地库中的音乐对象');
        }
        
        // 保存到 Firestore
        print('保存更新后的音乐元数据到Firestore...');
        await _firebaseService.addMusic(updatedMusic);
        print('音频文件已上传并保存到Firestore: ${updatedMusic.id}');
      } else {
        print('文件不存在: $filePath');
        // 仍然保存元数据
        print('文件不存在，仅保存元数据到Firestore');
        await _firebaseService.addMusic(music);
      }
    } catch (e) {
      print('上传音频到Firebase失败: $e');
      print('异常类型: ${e.runtimeType}');
      if (e is Error) {
        print('异常堆栈: ${e.stackTrace}');
      }
      throw Exception('上传音频到Firebase失败: $e');
    } finally {
      print('===== 上传音频到Firebase结束 =====');
    }
  }
  
  // Remove music
  Future<bool> removeMusic(String id) async {
    final previousLength = _musicLibrary.length;
    
    // 找到要删除的音乐
    final musicToDelete = _musicLibrary.firstWhere(
      (music) => music.id == id,
      orElse: () => MusicItem.empty(),
    );
    
    _musicLibrary.removeWhere((music) => music.id == id);
    
    // Check if the removal is successful
    final removed = previousLength > _musicLibrary.length;
    
    if (removed) {
      if (_useFirebase && musicToDelete.id.isNotEmpty) {
        // 从 Firebase 删除
        await _firebaseService.deleteMusic(id);
        
        // 如果是 Firebase Storage URL，也删除文件
        if (musicToDelete.audioUrl.startsWith('https://firebasestorage.googleapis.com')) {
          await _firebaseService.deleteAudioFile(musicToDelete.audioUrl);
        }
      } else {
        // 仅保存到本地存储
        await saveToStorage();
      }
      
      debugPrint('音乐已从库中删除: $id');
      notifyListeners();
    }
    
    return removed;
  }
  
  // Get music details
  MusicItem? getMusicById(String id) {
    try {
      return _musicLibrary.firstWhere((music) => music.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // Save to storage
  Future<void> saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert the music library to a JSON string list
      final jsonList = _musicLibrary.map((music) => jsonEncode(music.toJson())).toList();
      
      // Save the string list
      await prefs.setStringList(_storageKey, jsonList);
      
      debugPrint('音乐库已保存到本地存储: ${_musicLibrary.length} 首音乐');
    } catch (e) {
      debugPrint('保存音乐库失败: $e');
    }
  }
  
  // Load from storage
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the string list
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      
      // Convert to MusicItem list
      _musicLibrary = jsonList.map((jsonStr) {
        try {
          final json = jsonDecode(jsonStr);
          return MusicItem.fromJson(json);
        } catch (e) {
          debugPrint('解析音乐项失败: $e');
          return null;
        }
      }).whereType<MusicItem>().toList();
      
      debugPrint('从本地存储加载音乐库: ${_musicLibrary.length} 首音乐');
    } catch (e) {
      debugPrint('加载音乐库失败: $e');
      _musicLibrary = [];
    }
  }
  
  // Clear the library
  Future<void> clearLibrary() async {
    _musicLibrary.clear();
    
    if (_useFirebase) {
      // Firebase 清除库的功能需谨慎实现
      print('警告: 不支持从 Firebase 批量清除所有音乐');
    } else {
      await saveToStorage();
    }
    
    debugPrint('音乐库已清空');
    notifyListeners();
  }
  
  // Add a fix method
  Future<void> fixInvalidUrls() async {
    bool hasChanges = false;
    
    for (int i = 0; i < _musicLibrary.length; i++) {
      final music = _musicLibrary[i];
      
      // Check if it contains placeholder URL
      if (music.audioUrl.contains('your-api-base-url.com')) {
        // Extract the actual file path
        String originalUrl = music.audioUrl;
        String newUrl = '';
        
        // Try to extract the local path part
        final pathMatch = RegExp(r'/Users/.+\.mp3').firstMatch(originalUrl);
        if (pathMatch != null) {
          newUrl = pathMatch.group(0) ?? '';
          if (!newUrl.startsWith('file://')) {
            newUrl = 'file://$newUrl';
          }
        }
        
        if (newUrl.isNotEmpty) {
          _musicLibrary[i] = music.copyWith(audioUrl: newUrl);
          hasChanges = true;
          
          developer.log('已修复音频 URL: $originalUrl -> $newUrl', name: 'MusicLibraryManager');
        }
      }
    }
    
    if (hasChanges) {
      if (_useFirebase) {
        // 为每个修复的项更新 Firebase
        for (final music in _musicLibrary) {
          if (music.audioUrl.startsWith('file://')) {
            await _uploadAudioToFirebase(music);
          }
        }
      } else {
        await saveToStorage();
      }
      
      developer.log('已修复无效的音频 URL', name: 'MusicLibraryManager');
      notifyListeners();
    }
  }
  
  // Delete multiple music
  Future<int> removeMultipleMusic(List<String> ids) async {
    int removedCount = 0;
    
    if (_useFirebase) {
      // 使用 Firebase 批量删除
      removedCount = await _firebaseService.deleteMultipleMusic(ids);
      
      // 同步删除本地列表中的音乐
      _musicLibrary.removeWhere((music) => ids.contains(music.id));
    } else {
      // 从本地列表删除
      for (String id in ids) {
        final previousLength = _musicLibrary.length;
        _musicLibrary.removeWhere((music) => music.id == id);
        
        // 检查是否删除成功
        if (previousLength > _musicLibrary.length) {
          removedCount++;
        }
      }
      
      // 保存到本地存储
      await saveToStorage();
    }
    
    if (removedCount > 0) {
      debugPrint('已从库中删除 $removedCount 首音乐');
      notifyListeners();
    }
    
    return removedCount;
  }
  
  // 从远程 URL 下载音频并上传到 Firebase
  Future<MusicItem> downloadAndUploadAudio(MusicItem music) async {
    if (!_useFirebase) {
      return music; // 如果不使用 Firebase，直接返回
    }
    
    try {
      // 检查 URL 是否已经是 Firebase URL
      if (music.audioUrl.startsWith('https://firebasestorage.googleapis.com')) {
        return music;
      }
      
      // 确保 URL 有效
      if (!music.audioUrl.startsWith('http')) {
        print('无效的音频 URL: ${music.audioUrl}');
        return music;
      }
      
      // 从远程下载文件
      final response = await http.get(Uri.parse(music.audioUrl));
      if (response.statusCode != 200) {
        throw Exception('下载音频文件失败: ${response.statusCode}');
      }
      
      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${music.id}.mp3');
      await tempFile.writeAsBytes(response.bodyBytes);
      
      // 上传到 Firebase Storage
      final fileName = '${music.id}.mp3';
      final downloadUrl = await _firebaseService.uploadAudioFile(tempFile, fileName);
      
      // 更新音乐项
      final updatedMusic = music.copyWith(audioUrl: downloadUrl);
      
      // 保存到 Firestore
      await _firebaseService.addMusic(updatedMusic);
      
      // 删除临时文件
      await tempFile.delete();
      
      print('已下载并上传音频到 Firebase: ${music.id}');
      return updatedMusic;
    } catch (e) {
      print('下载并上传音频失败: $e');
      return music; // 出错时返回原始音乐项
    }
  }

  // 添加一个集成了同步功能的音乐添加方法
  Future<void> addMusicAndSync(MusicItem music) async {
    print('===== 开始添加并同步音乐 =====');
    print('音乐ID: ${music.id}, 标题: ${music.title}');
    print('音频URL: ${music.audioUrl}');
    
    // 确保有ID
    final String id = music.id.isEmpty ? const Uuid().v4() : music.id;
    final musicWithId = music.id.isEmpty ? music.copyWith(id: id) : music;
    
    if (music.id.isEmpty) {
      print('生成了新的音乐ID: $id');
    }
    
    // 先添加到本地库
    try {
      await addMusic(musicWithId);
      print('音乐已成功添加到本地库');
    } catch (e) {
      print('添加音乐到本地库失败: $e');
      rethrow; // 重新抛出异常
    }
    
    // 检查Firebase是否启用
    print('Firebase 同步功能状态: ${_useFirebase ? "已启用" : "未启用"}');
    
    // 如果未启用Firebase，无需进一步操作
    if (!_useFirebase) {
      print('Firebase同步未启用，跳过同步步骤');
      return;
    }
    
    try {
      print('准备同步到Firebase...');
      
      // 检查Firebase服务是否初始化
      print('检查Firebase服务初始化状态...');
      if (!_firebaseService.isInitialized) {
        print('Firebase服务尚未初始化，尝试初始化...');
        await _firebaseService.initialize();
        print('Firebase服务初始化完成');
      }
      
      // 如果是本地文件，上传到Firebase Storage
      if (musicWithId.audioUrl.startsWith('file://')) {
        print('检测到本地音频文件，准备上传到Firebase Storage');
        await _uploadAudioToFirebase(musicWithId);
      } else {
        // 否则直接添加到Firestore
        print('添加音乐元数据到Firestore');
        await _firebaseService.addMusic(musicWithId);
      }
      print('音乐已成功同步到Firebase: ${musicWithId.title}');
    } catch (e) {
      print('同步音乐到Firebase失败: $e');
      print('异常类型: ${e.runtimeType}');
      if (e is Error) {
        print('异常堆栈: ${e.stackTrace}');
      }
      // 继续运行，至少本地添加成功了
    } finally {
      print('===== 添加并同步音乐完成 =====');
    }
  }

  // 添加删除并同步方法
  Future<bool> deleteMusicAndSync(String id) async {
    bool success = await removeMusic(id);
    
    if (success && _useFirebase) {
      try {
        // 从Firebase中删除
        await _firebaseService.deleteMusic(id);
        print('音乐已从Firebase删除: $id');
      } catch (e) {
        print('从Firebase删除音乐失败: $e');
        // 我们仍然认为操作成功，因为本地删除成功了
      }
    }
    
    return success;
  }

  // 添加从Firebase加载音乐的方法
  Future<void> loadMusicFromFirebase() async {
    if (!_useFirebase) return;
    
    try {
      final firebaseMusicList = await _firebaseService.getAllMusic();
      print('从Firebase加载了 ${firebaseMusicList.length} 首音乐');
      
      // 将Firebase中的音乐合并到本地库
      for (final music in firebaseMusicList) {
        final existingIndex = _musicLibrary.indexWhere((item) => item.id == music.id);
        
        if (existingIndex >= 0) {
          // 更新现有音乐
          _musicLibrary[existingIndex] = music;
        } else {
          // 添加新音乐
          _musicLibrary.add(music);
        }
      }
      
      // 保存到本地存储作为备份
      await saveToStorage();
      notifyListeners();
    } catch (e) {
      print('从Firebase加载音乐失败: $e');
      throw e;
    }
  }
} 