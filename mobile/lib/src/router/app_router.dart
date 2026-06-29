import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/analytics_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/barcode/barcode_scan_screen.dart';
import '../features/dashboard/home_dashboard_screen.dart';
import '../features/foods/create_custom_food_screen.dart';
import '../features/foods/food_detail_screen.dart';
import '../features/foods/food_search_screen.dart';
import '../features/habits/habit_grid_screen.dart';
import '../features/meals/add_food_manual_screen.dart';
import '../features/meals/meal_log_screen.dart';
import '../features/meals/quick_add_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/photos/photo_review_screen.dart';
import '../features/photos/photo_scan_screen.dart';
import '../features/profile/profile_settings_screen.dart';
import '../features/recipes/recipe_builder_screen.dart';
import 'splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';
      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }
      if (user == null && !isAuthRoute) return '/login';
      if (user != null && !user.hasCompletedOnboarding) {
        return location == '/onboarding' ? null : '/onboarding';
      }
      if (user != null &&
          (isAuthRoute || location == '/splash' || location == '/onboarding')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeDashboardScreen()),
      GoRoute(
          path: '/foods/search', builder: (_, __) => const FoodSearchScreen()),
      GoRoute(
        path: '/foods/:id',
        builder: (_, state) => FoodDetailScreen(
          foodId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(path: '/meals', builder: (_, __) => const MealLogScreen()),
      GoRoute(
          path: '/meals/manual',
          builder: (_, __) => const AddFoodManualScreen()),
      GoRoute(
          path: '/meals/quick-add', builder: (_, __) => const QuickAddScreen()),
      GoRoute(
        path: '/foods/custom',
        builder: (_, __) => const CreateCustomFoodScreen(),
      ),
      GoRoute(
          path: '/photos/scan', builder: (_, __) => const PhotoScanScreen()),
      GoRoute(
        path: '/photos/review',
        builder: (_, state) => PhotoReviewScreen(
          analysisId:
              state.uri.queryParameters['analysis_id'] ?? 'mock-analysis',
        ),
      ),
      GoRoute(path: '/barcode', builder: (_, __) => const BarcodeScanScreen()),
      GoRoute(
          path: '/recipes', builder: (_, __) => const RecipeBuilderScreen()),
      GoRoute(path: '/habits', builder: (_, __) => const HabitGridScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(
          path: '/profile', builder: (_, __) => const ProfileSettingsScreen()),
    ],
  );
});
