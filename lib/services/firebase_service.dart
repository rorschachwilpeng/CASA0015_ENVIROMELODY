import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/music_item.dart';
import '../utils/device_id_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:typed_data';

class FirebaseService {
  // 单例模式
  static final FirebaseService _instance = FirebaseService._internal();
  
  factory FirebaseService() => _instance;
  
  FirebaseService._internal();
  
  // Firebase 实例
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // 设备ID管理器
  final DeviceIdManager _deviceIdManager = DeviceIdManager();
  
  // 设备ID缓存
  String? _deviceId;
  
  // 获取当前用户ID，如果未登录则使用匿名ID
  String get userId => _auth.currentUser?.uid ?? 'anonymous';
  
  // 获取设备ID
  Future<String> get deviceId async => _deviceId ??= await _deviceIdManager.getDeviceId();
  
  // 检查用户是否已登录
  bool get isLoggedIn => _auth.currentUser != null;
  
  // 获取音乐集合引用 - 修改为使用设备ID
  Future<CollectionReference> get musicCollection async => 
      _firestore.collection('devices').doc(await deviceId).collection('musicItems');
  
  // 添加到 FirebaseService 类中
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // 初始化 - 确保用户已登录（如果没有则匿名登录）
  // 并加载设备ID
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Firebase服务开始初始化...');
      // 初始化设备ID
      _deviceId = await _deviceIdManager.getDeviceId();
      print('设备ID: $_deviceId');
      
      // 仍然保留匿名登录，用于Firebase Storage权限
      if (_auth.currentUser == null) {
        try {
          await _auth.signInAnonymously();
          print('已创建匿名账户');
        } catch (e) {
          print('匿名登录失败: $e');
        }
      }
      
      // 确保设备数据存在
      await _ensureDeviceDocument();
      
      _isInitialized = true;
      print('Firebase服务初始化成功');
    } catch (e) {
      print('Firebase服务初始化失败: $e');
      rethrow;
    }
  }
  
  // 确保设备文档存在
  Future<void> _ensureDeviceDocument() async {
    try {
      final docRef = _firestore.collection('devices').doc(await deviceId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        // 创建设备数据文档
        await docRef.set({
          'created_at': FieldValue.serverTimestamp(),
          'last_seen': FieldValue.serverTimestamp(),
          'device_id': await deviceId,
        });
        print('创建设备文档: ${await deviceId}');
      } else {
        // 更新设备最后活动时间
        await docRef.update({
          'last_seen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('确保设备文档存在失败: $e');
    }
  }
  
  // 添加音乐到 Firestore - 修改为使用设备ID
  Future<void> addMusic(MusicItem music) async {
    try {
      final collection = await musicCollection;
      await collection.doc(music.id).set(music.toJson());
      print('音乐已添加到 Firestore: ${music.id}');
    } catch (e) {
      print('添加音乐到 Firestore 失败: $e');
      rethrow;
    }
  }
  
  // 获取所有音乐列表 - 修改为使用设备ID
  Future<List<MusicItem>> getAllMusic() async {
    try {
      final collection = await musicCollection;
      final snapshot = await collection
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MusicItem.fromJson(data);
      }).toList();
    } catch (e) {
      print('获取音乐列表失败: $e');
      return [];
    }
  }
  
  // 监听音乐列表变化 - 修改为使用设备ID
  Stream<List<MusicItem>> musicListStream() async* {
    try {
      final collection = await musicCollection;
      
      await for (final snapshot in collection
          .orderBy('created_at', descending: true)
          .snapshots()) {
        yield snapshot.docs.map((doc) {
          return MusicItem.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
      }
    } catch (e) {
      print('监听音乐列表失败: $e');
      yield [];
    }
  }
  
  // 删除音乐 - 修改为使用设备ID
  Future<bool> deleteMusic(String musicId) async {
    try {
      final collection = await musicCollection;
      await collection.doc(musicId).delete();
      print('音乐已从 Firestore 删除: $musicId');
      return true;
    } catch (e) {
      print('删除音乐失败: $e');
      return false;
    }
  }
  
  // 上传音频文件到 Storage - 修改路径包含设备ID
  Future<String> uploadAudioFile(File file, String fileName) async {
    try {
      print('准备上传文件到 Firebase Storage...');
      print('文件路径: ${file.path}');
      print('目标文件名: $fileName');
      
      // 读取文件数据
      final Uint8List fileData = await file.readAsBytes();
      print('读取文件数据成功，大小: ${fileData.length} 字节');
      
      // 确保 Firebase Storage 已初始化
      final FirebaseStorage storage = FirebaseStorage.instance;
      print('Firebase Storage 实例已获取');
      
      // 创建存储引用路径 - 使用与测试相同的方式
      // 不使用嵌套目录，直接使用根路径或简单路径
      final storageRef = storage.ref().child(fileName);
      print('创建存储引用: $fileName');
      
      // 上传文件数据而不是文件对象
      print('开始上传文件数据...');
      final uploadTask = storageRef.putData(
        fileData,
        SettableMetadata(contentType: 'audio/mp3') // 添加元数据
      );
      
      // 监听上传进度
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('上传进度: ${progress.toStringAsFixed(2)}%');
      });
      
      // 等待上传完成
      final TaskSnapshot snapshot = await uploadTask;
      print('文件上传成功');
      
      // 获取下载URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('获取到下载URL: $downloadUrl');
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase Storage 错误: [${e.code}] ${e.message}');
      
      // 更多的错误处理...
      rethrow;
    }
  }
  
  // 删除 Storage 中的音频文件
  Future<void> deleteAudioFile(String audioUrl) async {
    try {
      // 从 URL 中提取文件路径
      final ref = _storage.refFromURL(audioUrl);
      await ref.delete();
      print('音频文件已从 Storage 删除');
    } catch (e) {
      print('删除音频文件失败: $e');
    }
  }
  
  // 批量删除音乐 - 修改为使用设备ID
  Future<int> deleteMultipleMusic(List<String> musicIds) async {
    int successCount = 0;
    final collection = await musicCollection;
    
    for (final id in musicIds) {
      try {
        // 先获取音乐数据以获取音频URL
        final docSnap = await collection.doc(id).get();
        if (docSnap.exists) {
          final data = docSnap.data() as Map<String, dynamic>;
          final audioUrl = data['audio_url'] as String?;
          
          // 删除 Firestore 文档
          await collection.doc(id).delete();
          
          // 如果有音频URL并且是 Storage URL，则删除文件
          if (audioUrl != null && audioUrl.startsWith('https://firebasestorage.googleapis.com')) {
            await deleteAudioFile(audioUrl);
          }
          
          successCount++;
        }
      } catch (e) {
        print('删除音乐 $id 失败: $e');
      }
    }
    
    return successCount;
  }
  
  // 添加这个测试方法到 FirebaseService 类中
  Future<bool> testStorageConnection() async {
    try {
      print('===== 测试 Firebase Storage 连接 =====');
      
      // 获取存储引用信息
      final storageRef = _storage.ref();
      print('存储桶名称: ${storageRef.bucket}');
      
      // 创建测试引用路径
      final testRef = storageRef.child('test-connection');
      print('测试引用路径: ${testRef.fullPath}');
      
      // 创建一个小的测试文件
      final testContent = 'Test content ${DateTime.now()}';
      final testBytes = utf8.encode(testContent);
      
      // 尝试上传
      print('尝试上传测试数据...');
      await testRef.putData(Uint8List.fromList(testBytes));
      print('测试数据上传成功');
      
      // 尝试下载
      final url = await testRef.getDownloadURL();
      print('获取测试数据URL成功: $url');
      
      // 可选：删除测试文件
      await testRef.delete();
      print('测试数据已清理');
      
      print('✓ Storage连接测试成功');
      print('===== 测试完成 =====');
      return true;
    } on FirebaseException catch (e) {
      print('✗ Storage连接测试失败: [${e.code}] ${e.message}');
      
      // 详细诊断信息
      if (e.code == 'object-not-found') {
        print('提示: Storage可能未正确配置或路径不存在');
      } else if (e.code == 'unauthorized') {
        print('提示: 权限不足，请检查Storage安全规则');
        print('建议临时设置为: allow read, write: if true');
      } else if (e.code == 'storage/bucket-not-found') {
        print('提示: 存储桶不存在，请在Firebase控制台创建Storage');
      }
      
      print('===== 测试完成 =====');
      return false;
    } catch (e) {
      print('✗ Storage连接测试发生未知错误: $e');
      print('===== 测试完成 =====');
      return false;
    }
  }
} 