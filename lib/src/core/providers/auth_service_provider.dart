import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/city_search_service.dart';
import '../services/tts_service.dart';
import '../services/permission_service.dart';

// ─── SERVICE PROVIDERS ───

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(Supabase.instance.client);
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(Supabase.instance.client);
});

final citySearchServiceProvider = Provider<CitySearchService>((ref) {
  return CitySearchService();
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  tts.init();
  ref.onDispose(() => tts.dispose());
  return tts;
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

// ─── AUTH STATE PROVIDERS ───

final currentUserProvider = StreamProvider<AuthState>((ref) {
  return ref.read(authServiceProvider).authStateChanges;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentUserProvider);
  return authState.whenOrNull(
        data: (state) => state.session != null,
      ) ??
      false;
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  final authService = ref.read(authServiceProvider);
  if (authService.currentUser == null) return null;
  return await authService.getUserRole();
});

final userProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final authService = ref.read(authServiceProvider);
  if (authService.currentUser == null) return null;
  return await authService.getUserProfile();
});

// ─── INVALIDATION HELPER ───

void invalidateAllUserProviders(WidgetRef ref) {
  ref.invalidate(userRoleProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(supplierActiveLoadsCountProvider);
  ref.invalidate(supplierRecentLoadsProvider);
  ref.invalidate(supplierDataProvider);
  ref.invalidate(truckerActiveTripsCountProvider);
  ref.invalidate(truckerFleetCountProvider);
  ref.invalidate(truckerTotalTripsProvider);
  ref.invalidate(truckerRatingProvider);
  ref.invalidate(truckerEarningsProvider);
  ref.invalidate(truckerCompletionRateProvider);
  ref.invalidate(unreadChatsCountProvider);
}

// ─── SUPPLIER PROVIDERS ───

final supplierActiveLoadsCountProvider = FutureProvider<int>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0;

  final db = ref.read(databaseServiceProvider);
  final loads = await db.getMyLoads(userId);
  return loads.where((l) => l['status'] == 'active').length;
});

final supplierRecentLoadsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return [];

  final db = ref.read(databaseServiceProvider);
  final loads = await db.getMyLoads(userId);
  return loads.take(3).toList();
});

final supplierDataProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return null;

  final db = ref.read(databaseServiceProvider);
  return await db.getSupplierData(userId);
});

// ─── TRUCKER PROVIDERS ───

final truckerActiveTripsCountProvider = FutureProvider<int>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0;

  final db = ref.read(databaseServiceProvider);
  final truckerData = await db.getTruckerData(userId);
  return (truckerData?['total_trips'] as int? ?? 0) -
      (truckerData?['completed_trips'] as int? ?? 0);
});

final truckerFleetCountProvider = FutureProvider<int>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0;

  final db = ref.read(databaseServiceProvider);
  final trucks = await db.getMyTrucks(userId);
  return trucks.length;
});

final truckerTotalTripsProvider = FutureProvider<int>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0;

  final db = ref.read(databaseServiceProvider);
  final truckerData = await db.getTruckerData(userId);
  return truckerData?['total_trips'] as int? ?? 0;
});

final truckerRatingProvider = FutureProvider<double>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0.0;

  final db = ref.read(databaseServiceProvider);
  final truckerData = await db.getTruckerData(userId);
  return (truckerData?['rating'] as num?)?.toDouble() ?? 0.0;
});

final truckerEarningsProvider = FutureProvider<double>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0.0;

  final db = ref.read(databaseServiceProvider);
  try {
    final loads = await db.getMyTrips(userId);
    final completedLoads = loads.where((l) => l['status'] == 'completed');
    double total = 0.0;
    for (final load in completedLoads) {
      total += (load['price'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  } catch (_) {
    return 0.0;
  }
});

final truckerCompletionRateProvider = FutureProvider<double>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0.0;

  final db = ref.read(databaseServiceProvider);
  final truckerData = await db.getTruckerData(userId);
  final total = truckerData?['total_trips'] as int? ?? 0;
  final completed = truckerData?['completed_trips'] as int? ?? 0;
  if (total == 0) return 0.0;
  return (completed / total) * 100;
});

// ─── CHAT PROVIDERS ───

final unreadChatsCountProvider = FutureProvider<int>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return 0;

  final db = ref.read(databaseServiceProvider);
  try {
    final conversations = await db.getConversationsByUser(userId);
    int unread = 0;
    for (final conv in conversations) {
      final unreadCount = conv['unread_count'] as int? ?? 0;
      unread += unreadCount;
    }
    return unread;
  } catch (_) {
    return 0;
  }
});
