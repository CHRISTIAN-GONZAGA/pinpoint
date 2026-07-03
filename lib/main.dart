import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/core/local/local_seed_service.dart';
import 'package:pinpoint/features/map/data/transport_local_datasource.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final seedService = LocalSeedService(transportLocal: TransportLocalDataSource());
  await seedService.seedIfNeeded();

  runApp(
    const AppProviderScope(
      child: PinpointApp(),
    ),
  );
}
