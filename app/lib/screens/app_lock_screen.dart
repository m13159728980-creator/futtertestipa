import 'package:flutter/material.dart';

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用锁')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Icon(Icons.lock_outline, size: 56),
          SizedBox(height: 16),
          Text(
            'PIN 码',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text('设置 4-6 位 PIN 码保护本地消息。'),
          SizedBox(height: 24),
          Text(
            '生物识别',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text('预留指纹和面容识别入口，本阶段暂不接入系统能力。'),
          SizedBox(height: 24),
          Text(
            '隐藏预览 / 安全窗口',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text('后续可复用设置页的安全窗口能力隐藏任务切换预览。'),
        ],
      ),
    );
  }
}
