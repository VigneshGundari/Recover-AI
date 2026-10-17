import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'features/health_tracking/data/medication_task_collection.dart';
import 'features/health_tracking/data/daily_health_log_collection.dart';
import 'features/health_tracking/data/recovery_plan_collection.dart';
import 'features/health_tracking/data/recovery_task_log_collection.dart';
import 'features/health_tracking/data/smart_scan_history_collection.dart';
import 'features/health_tracking/data/local_health_repository.dart';
import 'core/services/notification_service.dart';
import 'package:local_notifier/local_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: "assets/.env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Stability Patch 8.5: Disable local cache on Windows to bypass sticky permission errors
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  String path = '';
  if (!kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();
    path = dir.path;
  }

  final isar = await Isar.open(
    [
      MedicationTaskSchema,
      HealthLogSchema,
      RecoveryPlanSchema,
      RecoveryTaskSchema,
      RecoveryTaskLogSchema,
      SmartScanHistorySchema,
    ],
    directory: path,
  );

  // Initialize Native Windows Notification API
  await localNotifier.setup(
    appName: 'Recover AI',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );
  
  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const RecoverApp(),
    ),
  );
}

class RecoverApp extends ConsumerWidget {
  const RecoverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Recover AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
