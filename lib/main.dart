import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';

import 'package:provider/provider.dart';
import 'package:todo_apppp/pages/home_page.dart';
import 'package:todo_apppp/pages/screen_pages.dart';
import 'package:todo_apppp/themes/ThemeProvider.dart';
import 'Screens/LoginScreen.dart';
import 'Screens/RegisterScreen.dart';
import 'data/models/todo_model.dart';


void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(TodoModelAdapter());
  await Hive.openBox<TodoModel>('todoBox');
  runApp(ChangeNotifierProvider(
    create: (context) => ThemeProvider(),
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override

  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Provider.of<ThemeProvider>(context).currentTheme,

      debugShowCheckedModeBanner: false,
      //home: LoginScreen(),    // ****************   i will return to it
      // theme: ThemeData(    // ****************
      //   primarySwatch: Colors.blue,
      // ),   // ***********************************************************
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/settingspage': (context) => SettingsPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}