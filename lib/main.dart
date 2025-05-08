// main

import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';
import 'package:todo_apppp/pages/home_page.dart';
import 'package:todo_apppp/pages/screen_pages.dart';
import 'package:todo_apppp/themes/ThemeProvider.dart';
import 'screens/LoginScreen.dart';
import 'screens/RegisterScreen.dart';
import 'screens/voice_input_screen.dart';
import 'data/models/todo_model.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(TodoModelAdapter());
  await Hive.openBox<TodoModel>('todoBox');
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Provider.of<ThemeProvider>(context).currentTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => SignInScreen(),
        '/register': (context) => SignUpScreen(),
        '/settingspage': (context) => SettingsPage(),
        '/home': (context) => HomePage(),
        '/voice': (context) => const VoiceInputScreen(),
      },
    );
  }
}
