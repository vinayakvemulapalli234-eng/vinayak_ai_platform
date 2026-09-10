import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/language_select_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/my_products_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: KalaAIApp()));
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/language', builder: (context, state) => const LanguageSelectScreen()),
    GoRoute(path: '/role', builder: (context, state) => const RoleSelectScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/add-product', builder: (context, state) => const AddProductScreen()),
    GoRoute(path: '/my-products', builder: (context, state) => const MyProductsScreen()),
  ],
);

class KalaAIApp extends StatelessWidget {
  const KalaAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KalaAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E7A4C),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E7A4C)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}