import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/recording_controller.dart';
import 'core/saas_config.dart';
import 'modules/auth/auth_gate.dart';
import 'services/google_auth_service.dart';
import 'services/google_drive_service.dart';
import 'services/saas_auth_service.dart';
import 'services/upload_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SaasConfig.isConfigured) {
    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: SaasConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SaasConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SaasAuthService>(
          create: (context) => SaasAuthService()..init(),
        ),
        ChangeNotifierProvider(
          create: (context) => RecordingController(),
        ),
        ChangeNotifierProvider<GoogleAuthService>(
          create: (context) => GoogleAuthService(),
        ),
        ProxyProvider<GoogleAuthService, GoogleDriveService>(
          update: (context, authService, previous) =>
              GoogleDriveService(authService),
        ),
        ChangeNotifierProxyProvider<GoogleDriveService, UploadQueueService>(
          create: (context) =>
              UploadQueueService(context.read<GoogleDriveService>())..init(),
          update: (context, driveService, previous) {
            final service = previous ?? UploadQueueService(driveService);
            service.updateDriveService(driveService);
            return service;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PackProof',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF5A1F),
            primary: const Color(0xFFFF5A1F),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: IconThemeData(
              color: Color(0xFF111827),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A1F),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}
