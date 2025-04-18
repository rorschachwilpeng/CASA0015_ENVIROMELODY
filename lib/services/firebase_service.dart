import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/music_item.dart';

class FirebaseService {
  // 单例模式
  static final FirebaseService _instance = FirebaseService._internal();
  
  factory FirebaseService() => _instance;
  
  FirebaseService._internal();
  
  // Firebase 实例
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // 获取当前用户ID，如果未登录则使用匿名ID
  String get userId => _auth.currentUser?.uid ?? 'anonymous';
  
  // 检查用户是否已登录
  bool get isLoggedIn => _auth.currentUser != null;
  
  // 获取音乐集合引用
  CollectionReference get musicCollection => 
      _firestore.collection('users').doc(userId).collection('musicItems');
  
  // 初始化 - 确保用户已登录（如果没有则匿名登录）
  Future<void> initialize() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
        print('已创建匿名账户');
      } catch (e) {
        print('匿名登录失败: $e');
      }
    }
  }
  
  // 添加音乐到 Firestore
  Future<void> addMusic(MusicItem music) async {
    try {
      await musicCollection.doc(music.id).set(music.toJson());
      print('音乐已添加到 Firestore: ${music.id}');
    } catch (e) {
      print('添加音乐到 Firestore 失败: $e');
      rethrow;
    }
  }
  
  // 获取所有音乐列表
  Future<List<MusicItem>> getAllMusic() async {
    try {
      final snapshot = await musicCollection
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
  
  // 监听音乐列表变化
  Stream<List<MusicItem>> musicListStream() {
    return musicCollection
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return MusicItem.fromJson(doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }
  
  // 删除音乐
  Future<bool> deleteMusic(String musicId) async {
    try {
      await musicCollection.doc(musicId).delete();
      print('音乐已从 Firestore 删除: $musicId');
      return true;
    } catch (e) {
      print('删除音乐失败: $e');
      return false;
    }
  }
  
  // 上传音频文件到 Storage
  Future<String> uploadAudioFile(File audioFile, String fileName) async {
    try {
      final storageRef = _storage.ref().child('music/$userId/$fileName');
      final uploadTask = storageRef.putFile(audioFile);
      final snapshot = await uploadTask;
      
      // 获取下载 URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('音频文件已上传: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('上传音频文件失败: $e');
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
  
  // 批量删除音乐
  Future<int> deleteMultipleMusic(List<String> musicIds) async {
    int successCount = 0;
    
    for (final id in musicIds) {
      try {
        // 先获取音乐数据以获取音频URL
        final docSnap = await musicCollection.doc(id).get();
        if (docSnap.exists) {
          final data = docSnap.data() as Map<String, dynamic>;
          final audioUrl = data['audio_url'] as String?;
          
          // 删除 Firestore 文档
          await musicCollection.doc(id).delete();
          
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
} 