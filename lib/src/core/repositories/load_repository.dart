import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/load_model.dart';
import '../utils/result.dart';

class LoadRepository {
  final SupabaseClient _supabase;

  LoadRepository(this._supabase);

  static const int _pageSize = 50;

  Future<Result<List<LoadModel>>> getActiveLoads({
    String? originCity,
    String? destCity,
    String? truckType,
    String? sortOrder,
    bool? verifiedOnly,
    String? materialFilter,
    List<String>? materialList,
    double? minWeight,
    double? maxWeight,
    String? pickupDateFrom,
    double? minPrice,
    double? maxPrice,
    int page = 0,
  }) async {
    try {
      var query = _supabase.from('loads').select().eq('status', 'active');

      if (originCity != null && originCity.isNotEmpty) {
        query = query.ilike('origin_city', '$originCity%');
      }
      if (destCity != null && destCity.isNotEmpty) {
        query = query.ilike('dest_city', '$destCity%');
      }
      if (truckType != null && truckType.isNotEmpty && truckType != 'Any') {
        query = query.eq('required_truck_type', truckType.toLowerCase());
      }
      if (materialList != null && materialList.isNotEmpty) {
        query = query.inFilter('material', materialList);
      } else if (materialFilter != null && materialFilter != 'Any') {
        query = query.ilike('material', '%$materialFilter%');
      }
      if (minWeight != null) query = query.gte('weight_tonnes', minWeight);
      if (maxWeight != null) query = query.lte('weight_tonnes', maxWeight);
      if (pickupDateFrom != null && pickupDateFrom.isNotEmpty) {
        query = query.gte('pickup_date', pickupDateFrom);
      }
      if (minPrice != null) query = query.gte('price', minPrice);
      if (maxPrice != null) query = query.lte('price', maxPrice);
      if (verifiedOnly == true) {
        query = query.eq('is_verified_supplier', true);
      }

      final from = page * _pageSize;
      final to = from + _pageSize - 1;

      final response = sortOrder == 'price_high'
          ? await query.order('price', ascending: false).range(from, to)
          : sortOrder == 'price_low'
              ? await query.order('price', ascending: true).range(from, to)
              : await query
                  .order('created_at', ascending: false)
                  .range(from, to);

      final loads = (response as List)
          .map((e) => LoadModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success(loads);
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }

  Future<Result<LoadModel>> getById(String id) async {
    try {
      final response = await _supabase
          .from('loads')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) {
        return const Failure('Load not found', error: AppError.notFound);
      }
      return Success(LoadModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }

  Future<Result<LoadModel>> create(Map<String, dynamic> data) async {
    try {
      final response =
          await _supabase.from('loads').insert(data).select().single();
      return Success(LoadModel.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }

  Future<Result<List<LoadModel>>> getMyLoads(String supplierId) async {
    try {
      final response = await _supabase
          .from('loads')
          .select()
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false);
      final loads = (response as List)
          .map((e) => LoadModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success(loads);
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }

  Future<Result<void>> bookLoad({
    required String loadId,
    required String truckerId,
    required String truckId,
  }) async {
    try {
      final result = await _supabase.rpc('book_load', params: {
        'p_load_id': loadId,
        'p_trucker_id': truckerId,
        'p_truck_id': truckId,
      });
      final data = result as Map<String, dynamic>;
      if (data['success'] != true) {
        return Failure(
          data['message'] as String? ?? 'Booking failed',
          error: AppError.businessRule,
        );
      }
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }

  Future<Result<void>> approveBooking(String loadId) async {
    try {
      final load = await _supabase
          .from('loads')
          .select('booked_by_trucker_id')
          .eq('id', loadId)
          .maybeSingle();
      if (load == null) {
        return const Failure('Load not found', error: AppError.notFound);
      }

      final result = await _supabase.rpc('approve_booking', params: {
        'p_load_id': loadId,
        'p_expected_trucker_id': load['booked_by_trucker_id'],
      });
      final data = result as Map<String, dynamic>;
      if (data['success'] != true) {
        return Failure(
          data['message'] as String? ?? 'Approval failed',
          error: AppError.businessRule,
        );
      }
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }

  Future<Result<void>> rejectBooking(String loadId) async {
    try {
      final result = await _supabase.rpc('reject_booking', params: {
        'p_load_id': loadId,
      });
      final data = result as Map<String, dynamic>;
      if (data['success'] != true) {
        return Failure(
          data['message'] as String? ?? 'Rejection failed',
          error: AppError.businessRule,
        );
      }
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }

  Future<Result<List<LoadModel>>> getMyTrips(String truckerId) async {
    try {
      final response = await _supabase
          .from('loads')
          .select()
          .eq('assigned_trucker_id', truckerId)
          .inFilter('status', [
            'booked',
            'in_transit',
            'delivered',
            'completed',
          ])
          .order('updated_at', ascending: false);
      final loads = (response as List)
          .map((e) => LoadModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success(loads);
    } on PostgrestException catch (e) {
      return Failure(e.message, error: AppError.server);
    } catch (e) {
      return Failure(e.toString(), error: AppError.unknown);
    }
  }
}
