import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/plan_service.dart';
import 'services/auth_service.dart';
import 'services/friend_service.dart';
import 'services/collaborative_plan_service.dart';
import 'services/favorites_service.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/create_plan_screen.dart';
import 'screens/plan_details_screen.dart';
import 'screens/explore_details_screen.dart';
import 'screens/my_plans_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/map_screen.dart';
import 'screens/add_place_screen.dart';
import 'screens/route_options_screen.dart';
import 'screens/favorites_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Initialize all services
  await AuthService.initialize();
  await PlanService.initialize();
  await FriendService.initialize();
  await CollaborativePlanService.initialize();
  await FavoritesService.initialize();

  runApp(const HalaPhApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainNavigation(),
    ),
    GoRoute(
      path: '/my-plans',
      builder: (context, state) => const MainNavigation(initialIndex: 2),
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      path: '/explore-details',
      builder: (context, state) {
        final destinationId = state.uri.queryParameters['destinationId'] ?? '';
        final source = state.uri.queryParameters['source'];
        final destination = state.extra;
        return ExploreDetailsScreen(
          destinationId: destinationId,
          source: source,
          destination: destination as dynamic,
        );
      },
    ),
    GoRoute(
      path: '/plan-details',
      builder: (context, state) {
        final planId = state.uri.queryParameters['planId'];
        if (planId != null && planId.isNotEmpty) {
          final plan = PlanService.getPlanById(planId);
          return PlanDetailsScreen(plan: plan);
        }
        return const PlanDetailsScreen(plan: null);
      },
    ),
    GoRoute(
      path: '/view',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return MapScreen(
          destinations: extra?['destinations'],
          selectedDestination: extra?['selectedDestination'],
        );
      },
    ),
    GoRoute(
      path: '/create-plan',
      builder: (context, state) {
        final destination = state.extra;
        return CreatePlanScreen(initialDestination: destination as dynamic);
      },
    ),
    GoRoute(
      path: '/add-place',
      builder: (context, state) => const AddPlaceScreen(),
    ),
    GoRoute(
      path: '/route-options',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        return RouteOptionsScreen(
          destinationId: params['destinationId'] ?? '',
          destinationName: params['destinationName'] ?? 'Destination',
        );
      },
    ),
  ],
);

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const MyPlansScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 20 * scale, vertical: 8 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', 0, scale),
                _buildNavItem(Icons.explore_rounded, 'Explore', 1, scale),
                _buildNavItem(Icons.calendar_today_rounded, 'Plans', 2, scale),
                _buildNavItem(Icons.person_rounded, 'Profile', 3, scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, double scale) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24 * scale,
              color: isActive ? Colors.blue[600] : Colors.grey[400],
            ),
            SizedBox(height: 4 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 12 * scale,
                color: isActive ? Colors.blue[600] : Colors.grey[400],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HalaPhApp extends StatelessWidget {
  const HalaPhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate scale factor based on screen width
        final scale = _calculateScale(constraints.maxWidth);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'HalaPH - Where every trip finds its line',
            theme: _buildTheme(scale),
            routerConfig: _router,
          ),
        );
      },
    );
  }

  double _calculateScale(double width) {
    // Base design is for 390dp width (iPhone 14/15 standard)
    const double baseWidth = 390.0;
    const double minScale = 0.85;
    const double maxScale = 1.15;

    double scale = width / baseWidth;
    return scale.clamp(minScale, maxScale);
  }

  ThemeData _buildTheme(double scale) {
    return ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18 * scale,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.black87, size: 24 * scale),
        toolbarHeight: 56 * scale,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
              horizontal: 24 * scale, vertical: 12 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          textStyle: TextStyle(
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12 * scale),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12 * scale),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12 * scale),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2 * scale),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 14 * scale),
        labelStyle: TextStyle(fontSize: 14 * scale),
        hintStyle: TextStyle(fontSize: 14 * scale),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        margin: EdgeInsets.all(8 * scale),
      ),
      textTheme: TextTheme(
        headlineLarge:
            TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.bold),
        headlineMedium:
            TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold),
        headlineSmall:
            TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500),
        titleSmall:
            TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16 * scale),
        bodyMedium: TextStyle(fontSize: 14 * scale),
        bodySmall: TextStyle(fontSize: 12 * scale),
        labelLarge:
            TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
      ),
      iconTheme: IconThemeData(size: 24 * scale),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: Colors.blue[600],
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: TextStyle(fontSize: 12 * scale),
        unselectedLabelStyle: TextStyle(fontSize: 12 * scale),
        type: BottomNavigationBarType.fixed,
      ),
      useMaterial3: true,
    );
  }
}
