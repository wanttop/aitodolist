import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme_provider.dart';
import 'services/notification_service.dart';
import 'pages/home_page.dart'; // 改成 home_page.dart
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await initializeDateFormatting('zh_CN', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: '智能待办日历',
          theme: ThemeData(primarySwatch: Colors.blue),
          darkTheme: ThemeData.dark(),
          themeMode: themeProvider.currentMode,
          debugShowCheckedModeBanner: false,
          home: const HomePage(), // 主页就是 HomePage
        );
      },
    );
  }
}
