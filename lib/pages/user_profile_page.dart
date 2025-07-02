// filepath: lib/pages/user_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _username;
  String? _avatarPath; // 本地头像路径

  @override
  void initState() {
    super.initState();
    SessionManager.getUsername().then((value) {
      setState(() {
        _username = value ?? '';
      });
    });
  }

  Future<void> _changePassword() async {
    String oldPwd = '';
    String newPwd = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                obscureText: true,
                decoration: const InputDecoration(labelText: '原密码'),
                onChanged: (v) => oldPwd = v,
              ),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码'),
                onChanged: (v) => newPwd = v,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定')),
          ],
        );
      },
    );
    if (result == true && oldPwd.isNotEmpty && newPwd.isNotEmpty) {
      // 调用后端API修改密码
      final resp = await http.post(
        Uri.parse('http://127.0.0.1:9000/change_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _username,
          'old_password': oldPwd,
          'new_password': newPwd,
        }),
      );
      final data = jsonDecode(resp.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['msg'] ?? '未知错误')),
      );
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _avatarPath = picked.path;
      });
      // TODO: 可扩展上传头像到后端
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像选择成功（上传功能可扩展）')),
      );
    }
  }

  Future<void> _deleteUser() async {
    String pwd = '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('注销账号'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('您确定要注销账号吗？此操作不可逆！'),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(labelText: '请输入密码确认'),
                onChanged: (v) => pwd = v,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定')),
          ],
        );
      },
    );
    if (confirm == true && pwd.isNotEmpty) {
      // 调用后端API注销账号
      final resp = await http.post(
        Uri.parse('http://127.0.0.1:9000/delete_user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _username,
          'password': pwd, // 传递密码
        }),
      );
      final data = jsonDecode(resp.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['msg'] ?? '未知错误')),
      );
      if (data['code'] == 200) {
        // 注销成功，返回登录页
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 48,
                backgroundImage: _avatarPath != null
                    ? FileImage(File(_avatarPath!))
                    : const AssetImage('assets/default_avatar.png')
                        as ImageProvider,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('用户名'),
            subtitle: Text(_username ?? ''),
          ),
          ListTile(
            title: const Text('修改密码'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _changePassword,
          ),
          ListTile(
            title: const Text('注销账号', style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.delete, color: Colors.red),
            onTap: _deleteUser,
          ),
        ],
      ),
    );
  }
}
