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
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'event_bus.dart';
import 'flutter_map_service.dart';

// 添加到文件顶部，类定义之前
typedef MusicDeletedCallback = void Function(String musicId);

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
  
  // 新增变量
  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _syncInterval = const Duration(minutes: 5); // 自动同步间隔
  
  // 记录本地修改的音乐ID
  Set<String> _locallyModifiedMusicIds = {};
  
  // 连接状态
  bool _isOnline = true;
  
  // 添加回调列表
  final List<MusicDeletedCallback> _musicDeletedCallbacks = [];

  // 添加注册回调的方法
  void addMusicDeletedCallback(MusicDeletedCallback callback) {
    _musicDeletedCallbacks.add(callback);
    print('音乐删除回调已注册，当前回调数量: ${_musicDeletedCallbacks.length}');
  }

  // 添加移除回调的方法
  void removeMusicDeletedCallback(MusicDeletedCallback callback) {
    _musicDeletedCallbacks.remove(callback);
    print('音乐删除回调已移除，当前回调数量: ${_musicDeletedCallbacks.length}');
  }
  
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
        
        // 启动定期同步
        _startPeriodicSync();
        
        // 监听网络状态
        _monitorConnectivity();
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
    
    // 在完成后，将这个ID添加到本地修改列表
    _locallyModifiedMusicIds.add(music.id);
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
    // 保存要删除的音乐信息，用于后续清理标记
    String? musicTitle;
    MusicItem? musicToDelete;  // 在 try 块外部声明
    try {
      musicToDelete = _musicLibrary.firstWhere((music) => music.id == id);
      musicTitle = musicToDelete.title;
    } catch (e) {
      // 音乐可能不存在，继续处理
    }
    
    final previousLength = _musicLibrary.length;
    
    // 找到要删除的音乐
    _musicLibrary.removeWhere((music) => music.id == id);
    
    // Check if the removal is successful
    final removed = previousLength > _musicLibrary.length;
    
    if (removed) {
      if (_useFirebase && musicToDelete != null && musicToDelete.id.isNotEmpty) {  // 添加 null 检查
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
      
      // 添加的代码: 通知所有注册的回调
      print('触发音乐删除回调，音乐ID: $id，回调数量: ${_musicDeletedCallbacks.length}');
      for (var callback in _musicDeletedCallbacks) {
        callback(id);
      }
      
      notifyListeners();
      
      // 添加清理地图标记的逻辑
      try {
        print('尝试清理地图标记，音乐ID: $id, 标题: $musicTitle');
        final mapService = FlutterMapService();
        mapService.cleanupFlagsByMusicInfo(id, musicTitle);
      } catch (e) {
        print('清理地图标记时出错: $e');
      }
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
      
      // 通知所有回调
      print('批量删除触发回调，音乐ID数量: ${ids.length}');
      for (String id in ids) {
        for (var callback in _musicDeletedCallbacks) {
          callback(id);
        }
      }
    } else {
      // 从本地列表删除
      for (String id in ids) {
        final previousLength = _musicLibrary.length;
        _musicLibrary.removeWhere((music) => music.id == id);
        
        // 检查是否删除成功
        if (previousLength > _musicLibrary.length) {
          removedCount++;
          
          // 通知所有回调
          print('单个删除触发回调，音乐ID: $id');
          for (var callback in _musicDeletedCallbacks) {
            callback(id);
          }
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

  // 监听网络连接状态
  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      // 当从离线变为在线状态时，尝试同步
      if (!wasOnline && _isOnline && _useFirebase) {
        print('网络已恢复，开始同步数据...');
        syncWithFirebase();
      }
      
      if (wasOnline != _isOnline) {
        print('网络状态变化: ${_isOnline ? "在线" : "离线"}');
        notifyListeners();
      }
    });
  }
  
  // 启动定期同步
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_useFirebase && _isOnline) {
        syncWithFirebase();
      }
    });
  }
  
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
  
  // 主同步方法
  Future<void> syncWithFirebase() async {
    if (!_useFirebase || _isSyncing || !_isOnline) return;
    
    try {
      _isSyncing = true;
      print('开始与 Firebase 同步数据...');
      
      // 1. 先将本地修改推送到Firebase
      await _pushLocalChangesToFirebase();
      
      // 2. 然后从Firebase获取最新数据
      await _pullChangesFromFirebase();
      
      _lastSyncTime = DateTime.now();
      print('数据同步完成，当前音乐库有 ${_musicLibrary.length} 首音乐');
    } catch (e) {
      print('数据同步失败: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  // 向Firebase推送本地更改
  Future<void> _pushLocalChangesToFirebase() async {
    if (_locallyModifiedMusicIds.isEmpty) {
      print('没有本地修改需要推送');
      return;
    }
    
    print('推送本地修改到 Firebase: ${_locallyModifiedMusicIds.length} 项');
    
    for (final id in _locallyModifiedMusicIds.toList()) {
      try {
        final musicIndex = _musicLibrary.indexWhere((item) => item.id == id);
        if (musicIndex >= 0) {
          final music = _musicLibrary[musicIndex];
          
          // 对于本地文件，上传到Firebase Storage
          if (music.audioUrl.startsWith('file://')) {
            await _uploadAudioToFirebase(music);
          } else {
            // 直接更新Firestore数据
            await _firebaseService.addMusic(music);
          }
          
          _locallyModifiedMusicIds.remove(id);
          print('已同步 "${music.title}" 到Firebase');
        }
      } catch (e) {
        print('同步音乐 $id 到Firebase失败: $e');
      }
    }
  }
  
  // 从Firebase拉取最新变更
  Future<void> _pullChangesFromFirebase() async {
    print('从 Firebase 拉取最新数据...');
    
    try {
      // 获取最新的音乐列表
      final List<MusicItem> cloudMusic = await _firebaseService.getAllMusic();
      
      // 创建本地和云端音乐的映射，用于快速查找
      final Map<String, MusicItem> localMusicMap = {
        for (var music in _musicLibrary) music.id: music
      };
      
      final Map<String, MusicItem> cloudMusicMap = {
        for (var music in cloudMusic) music.id: music
      };
      
      // 处理云端有但本地没有的音乐（新增）
      for (final cloudItem in cloudMusic) {
        final localItem = localMusicMap[cloudItem.id];
        
        if (localItem == null) {
          // 本地没有这首音乐，添加到本地
          _musicLibrary.add(cloudItem);
          print('添加云端音乐到本地: ${cloudItem.title}');
        } else {
          // 本地有这首音乐，检查是否需要更新
          // 如果本地版本没有被修改过，并且云端版本更新，则更新本地版本
          if (!_locallyModifiedMusicIds.contains(cloudItem.id) && 
              (cloudItem.createdAt.isAfter(localItem.createdAt) || 
               cloudItem.audioUrl != localItem.audioUrl)) {
            
            final index = _musicLibrary.indexOf(localItem);
            _musicLibrary[index] = cloudItem;
            print('更新本地音乐: ${cloudItem.title}');
          }
        }
      }
      
      // 本地有但云端没有的音乐，只在特定情况下处理
      // 例如：如果确认云端记录被删除，可以考虑删除本地记录
      // 但为了数据安全，这里暂不自动删除本地数据
      
      // 保存更新后的本地库
      await saveToStorage();
      notifyListeners();
      
    } catch (e) {
      print('从Firebase拉取数据失败: $e');
      throw e;
    }
  }
  
  // 增强的添加音乐方法
  Future<void> addMusicAndSync(MusicItem music) async {
    // 确保有ID
    final String id = music.id.isEmpty ? const Uuid().v4() : music.id;
    final musicWithId = music.id.isEmpty ? music.copyWith(id: id) : music;
    
    // 设置创建时间
    final now = DateTime.now();
    final musicWithTimestamp = musicWithId.copyWith(createdAt: now);
    
    // 添加到本地库
    await addMusic(musicWithTimestamp);
    
    // 标记为本地修改
    _locallyModifiedMusicIds.add(musicWithTimestamp.id);
    
    // 如果在线并启用Firebase，尝试立即同步
    if (_useFirebase && _isOnline) {
      try {
        // 同步到Firebase
        if (musicWithTimestamp.audioUrl.startsWith('file://')) {
          await _uploadAudioToFirebase(musicWithTimestamp);
        } else {
          await _firebaseService.addMusic(musicWithTimestamp);
        }
        
        // 同步成功，从本地修改列表中移除
        _locallyModifiedMusicIds.remove(musicWithTimestamp.id);
        print('音乐 "${musicWithTimestamp.title}" 已立即同步到Firebase');
      } catch (e) {
        print('立即同步音乐到Firebase失败: $e');
        print('将在下次同步时重试');
      }
    }
  }
  
  // 增强的删除音乐方法
  Future<bool> deleteMusicAndSync(String id) async {
    bool success = await removeMusic(id);
    
    if (success) {
      // 如果该ID在本地修改列表中，移除它
      _locallyModifiedMusicIds.remove(id);
      
      // 如果在线且启用Firebase，立即从Firebase删除
      if (_useFirebase && _isOnline) {
        try {
          await _firebaseService.deleteMusic(id);
          print('已从Firebase删除音乐: $id');
        } catch (e) {
          print('从Firebase删除音乐失败: $e');
        }
      }
    }
    
    return success;
  }
  
  // 手动触发同步的公共方法
  Future<void> forceSyncWithFirebase() async {
    if (!_useFirebase) {
      print('Firebase同步未启用');
      return;
    }
    
    if (!_isOnline) {
      print('设备当前处于离线状态，无法同步');
      return;
    }
    
    return syncWithFirebase();
  }
  
  // 获取同步状态
  bool get isSyncing => _isSyncing;
  
  // 获取上次同步时间
  DateTime get lastSyncTime => _lastSyncTime;
  
  // 获取网络状态
  bool get isOnline => _isOnline;
  
  // 获取待同步项数量
  int get pendingSyncItemsCount => _locallyModifiedMusicIds.length;
} 