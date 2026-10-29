import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'manager/routes_manger.dart';
import 'providers/arrangement_provider.dart';
import 'providers/transfer_intern_provider.dart';
import 'providers/transfer_validation_provider.dart';
import 'providers/user_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        // 1. Initialize UserProvider first
        ChangeNotifierProvider(create: (context) => UserProvider()),

        // 2. Inject UserProvider into TransferValidationProvider
        ChangeNotifierProvider(
          create: (context) => TransferValidationProvider(
            userProvider: context.read<UserProvider>(), // ✅ Read from context
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ArrangementProvider(
            userProvider: context.read<UserProvider>(), // ✅ Read from context
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => TransferInternProvider(
            userProvider: context.read<UserProvider>(), // ✅ Read from context
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Grand Stock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      ),
      initialRoute: Routes.splashRoute,
      onGenerateRoute: RouteGenerator.getRoute,
      onUnknownRoute: RouteGenerator.undefinedRoute,
    );
  }
}
