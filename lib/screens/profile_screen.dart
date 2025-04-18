import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'dart:async';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock user data
    const String username = "Music Lover";
    const String email = "music_lover@example.com";
    const int createdMusicCount = 15;
    const int favoriteMusicCount = 8;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue,
              child: Icon(
                Icons.person,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              username,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('My Created Music'),
              trailing: Text(
                '$createdMusicCount',
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () {
                // TODO: Navigate to user created music list
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('My Favorite Music'),
              trailing: Text(
                '$favoriteMusicCount',
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () {
                // TODO: Navigate to user favorite music list
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // TODO: Navigate to settings page
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('测试 Firebase 连接'),
              onTap: () {
                _testFirebaseConnection(context);
              },
            ),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement logout functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
  
  // 测试 Firebase 连接的方法
  void _testFirebaseConnection(BuildContext context) async {
    // 显示加载对话框
    BuildContext? dialogContext;
    
    // 设置超时
    Timer? timeoutTimer;
    
    // 显示加载对话框的函数
    void showLoadingDialog() {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) {
          dialogContext = ctx;
          return const WillPopScope(
            onWillPop: null,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    }
    
    // 安全关闭对话框的函数
    void closeLoadingDialog() {
      if (dialogContext != null) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        dialogContext = null;
      }
    }
    
    // 显示加载对话框
    showLoadingDialog();
    
    // 设置超时
    timeoutTimer = Timer(const Duration(seconds: 15), () {
      print('Firebase 连接测试超时');
      timeoutTimer = null;
      closeLoadingDialog();
      
      if (context.mounted) {
        _showResultDialog(
          context,
          '连接超时',
          'Firebase 操作超时，请检查网络连接并重试。',
          false
        );
      }
    });
    
    try {
      // 检查 Firebase 是否初始化
      print('开始测试 Firebase 连接...');
      final apps = Firebase.apps;
      print('Firebase 应用数量: ${apps.length}');
      if (apps.isEmpty) {
        print('没有 Firebase 应用被初始化');
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          print('在 Profile 页面中成功初始化 Firebase');
        } catch (e) {
          print('在 Profile 页面中初始化 Firebase 失败: $e');
          throw Exception('Firebase 未初始化: $e');
        }
      } else {
        for (var app in apps) {
          print('Firebase 应用名称: ${app.name}, 选项: ${app.options.projectId}');
        }
      }
      
      // 获取 Firestore 实例
      final firestore = FirebaseFirestore.instance;
      print('获取到 Firestore 实例');
      
      try {
        // 创建测试文档
        print('尝试写入测试文档...');
        await firestore.collection('test').doc('connection-test').set({
          'timestamp': DateTime.now().toIso8601String(),
          'message': '连接测试成功',
          'device': '${MediaQuery.of(context).size.width.toInt()}x${MediaQuery.of(context).size.height.toInt()}'
        }, SetOptions(merge: true));
        print('测试文档写入成功');
        
        // 读取测试文档
        print('尝试读取测试文档...');
        final doc = await firestore.collection('test').doc('connection-test').get();
        print('测试文档读取成功: ${doc.exists}');
        
        // 取消超时定时器
        timeoutTimer?.cancel();
        timeoutTimer = null;
        
        // 关闭加载对话框
        closeLoadingDialog();
        
        if (doc.exists) {
          // 显示成功消息
          if (context.mounted) {
            _showResultDialog(
              context, 
              '连接成功', 
              'Firebase 连接正常！\n\n数据: ${doc.data()}',
              true
            );
          }
          print('Firebase 连接测试成功: ${doc.data()}');
        } else {
          if (context.mounted) {
            _showResultDialog(
              context, 
              '连接异常', 
              '文档存在但数据为空',
              false
            );
          }
        }
      } catch (firestoreError) {
        print('Firestore 操作失败: $firestoreError');
        
        // 取消超时定时器
        timeoutTimer?.cancel();
        timeoutTimer = null;
        
        // 关闭加载对话框
        closeLoadingDialog();
        
        if (context.mounted) {
          _showResultDialog(
            context, 
            'Firestore 错误', 
            '无法写入或读取测试数据，请检查 Firestore 规则设置。\n\n错误信息: $firestoreError',
            false
          );
        }
      }
    } catch (e) {
      // 取消超时定时器
      timeoutTimer?.cancel();
      timeoutTimer = null;
      
      // 关闭加载对话框
      closeLoadingDialog();
      
      // 显示错误消息
      if (context.mounted) {
        _showResultDialog(
          context, 
          '连接失败', 
          'Firebase 连接出错: $e\n\nFirebase 应用数量: ${Firebase.apps.length}',
          false
        );
      }
      print('Firebase 连接测试失败: $e');
    }
  }
  
  // 显示结果对话框
  void _showResultDialog(BuildContext context, String title, String message, bool success) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        icon: Icon(
          success ? Icons.check_circle : Icons.error,
          color: success ? Colors.green : Colors.red,
          size: 48,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
} 