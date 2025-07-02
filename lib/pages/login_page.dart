import 'package:flutter/material.dart';
import '../services/task_storage.dart'; // 替换为阿里云接口
import '../services/session_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String msg = '';
      if (_isLogin) {
        msg = await aliyunLogin(_username, _password);
      } else {
        msg = await aliyunRegister(_username, _password);
      }
      // 保存 session（这里只保存用户名，token可选）
      await SessionManager.saveSession('', _username);
      if (mounted) Navigator.pop(context, true); // 登录成功返回
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? '登录' : '注册'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLogin ? '智能待办日历 登录' : '智能待办日历 注册',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      decoration: const InputDecoration(labelText: '用户名'),
                      onSaved: (v) => _username = v!.trim(),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请输入用户名' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: '密码'),
                      obscureText: true,
                      onSaved: (v) => _password = v!.trim(),
                      validator: (v) =>
                          v == null || v.length < 6 ? '密码至少6位' : null,
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : Text(
                                _isLogin ? '登录' : '注册',
                                style: const TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin ? '没有账号？注册' : '已有账号？登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
// 新增：阿里云注册/登录适配

  Future<String> aliyunRegister(String username, String password) async {
    final response = await register(username, password);
    final data = jsonDecode(response.body);
    if (data['code'] == 200) {
      return data['msg'];
    } else {
      throw Exception(data['msg'] ?? '注册失败');
    }
  }

  Future<String> aliyunLogin(String username, String password) async {
    final response = await login(username, password);
    final data = jsonDecode(response.body);
    if (data['code'] == 200) {
      return data['msg'];
    } else {
      throw Exception(data['msg'] ?? '登录失败');
    }
  }
}
