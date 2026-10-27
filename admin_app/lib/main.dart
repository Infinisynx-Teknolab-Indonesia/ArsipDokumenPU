import 'package:flutter/material.dart';
import 'api.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'ui.dart';

/// Arsip Dokumen PU — Admin Server.
/// Aplikasi khusus admin untuk: menyetujui/menolak PC baru, mengelola member
/// (staf & admin), mengatur email SMTP, keamanan, dan melihat log aktivitas.
void main() => runApp(const AdminApp());

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  AdminApi? _api;
  Map<String, dynamic>? _user;

  void _logout() => setState(() {
        _api = null;
        _user = null;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arsip PU — Admin Server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: C.accent, primary: C.accent),
        scaffoldBackgroundColor: C.bg,
        fontFamily: 'Segoe UI',
      ),
      home: _api == null
          ? LoginScreen(onLoggedIn: (api, user) => setState(() {
                _api = api;
                _user = user;
              }))
          : Shell(api: _api!, user: _user!, onLogout: _logout),
    );
  }
}
