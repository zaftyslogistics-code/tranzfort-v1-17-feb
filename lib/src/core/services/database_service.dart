import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final SupabaseClient _supabase;

  DatabaseService(this._supabase);

  // ─── PROFILES ───

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> updateProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('profiles').update(data).eq('id', userId);
    } on PostgrestException catch (e) {
      final isMissingAadhaarLast4 =
          data.containsKey('aadhaar_last4') &&
          (e.code == 'PGRST204' || e.code == '42703') &&
          e.message.toLowerCase().contains('aadhaar_last4');

      if (!isMissingAadhaarLast4) rethrow;

      final fallbackData = Map<String, dynamic>.from(data)
        ..remove('aadhaar_last4');
      if (fallbackData.isEmpty) return;

      await _supabase.from('profiles').update(fallbackData).eq('id', userId);
    }
  }

  Future<Map<String, dynamic>?> getPublicProfile(String userId) async {
    // Read from public_profiles (readable by all authenticated users via RLS).
    // Falls back to own profile if public_profiles row doesn't exist yet.
    final pub = await _supabase
        .from('public_profiles')
        .select('id, full_name, avatar_url, current_role, verification_status')
        .eq('id', userId)
        .maybeSingle();
    if (pub != null) return pub;
    return await _supabase
        .from('profiles')
        .select('id, full_name, avatar_url, current_role, verification_status')
        .eq('id', userId)
        .maybeSingle();
  }

  // ─── SUPPLIERS ───

  Future<Map<String, dynamic>?> getSupplierData(String userId) async {
    return await _supabase
        .from('suppliers')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> createSupplierData(
      String userId, Map<String, dynamic> data) async {
    await _supabase.from('suppliers').upsert(
      {'id': userId, ...data},
      onConflict: 'id',
    );
  }

  Future<void> updateSupplierData(
      String userId, Map<String, dynamic> data) async {
    await _supabase.from('suppliers').upsert(
      {'id': userId, ...data},
      onConflict: 'id',
    );
  }

  // ─── TRUCKERS ───

  Future<Map<String, dynamic>?> getTruckerData(String userId) async {
    return await _supabase
        .from('truckers')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> createTruckerData(
      String userId, Map<String, dynamic> data) async {
    await _supabase.from('truckers').upsert(
      {'id': userId, ...data},
      onConflict: 'id',
    );
  }

  Future<void> updateTruckerData(
      String userId, Map<String, dynamic> data) async {
    await _supabase.from('truckers').upsert(
      {'id': userId, ...data},
      onConflict: 'id',
    );
  }

  // ─── LOADS ───

  static const int _loadPageSize = 50;

  Future<List<Map<String, dynamic>>> getActiveLoads({
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
    var query = _supabase
        .from('loads')
        .select()
        .eq('status', 'active');

    // P1-12: Prefix match instead of contains — prevents "Pur" matching "Jaipur"
    if (originCity != null && originCity.isNotEmpty) {
      query = query.ilike('origin_city', '$originCity%');
    }
    if (destCity != null && destCity.isNotEmpty) {
      query = query.ilike('dest_city', '$destCity%');
    }
    if (truckType != null && truckType.isNotEmpty && truckType != 'Any') {
      query = query.eq('required_truck_type', truckType.toLowerCase());
    }
    // P0-5: Category-based material filter (list of materials)
    if (materialList != null && materialList.isNotEmpty) {
      query = query.inFilter('material', materialList);
    } else if (materialFilter != null && materialFilter != 'Any') {
      query = query.ilike('material', '%$materialFilter%');
    }
    if (minWeight != null) {
      query = query.gte('weight_tonnes', minWeight);
    }
    if (maxWeight != null) {
      query = query.lte('weight_tonnes', maxWeight);
    }
    // P1-8: Pickup date filter
    if (pickupDateFrom != null && pickupDateFrom.isNotEmpty) {
      query = query.gte('pickup_date', pickupDateFrom);
    }
    // P1-9: Price range filter
    if (minPrice != null) {
      query = query.gte('price', minPrice);
    }
    if (maxPrice != null) {
      query = query.lte('price', maxPrice);
    }

    // P1-4: DB-level verified supplier filter
    if (verifiedOnly == true) {
      query = query.eq('is_verified_supplier', true);
    }

    // P1-4: Pagination
    final from = page * _loadPageSize;
    final to = from + _loadPageSize - 1;

    // Apply sorting + pagination at DB level
    final response = sortOrder == 'price_high'
        ? await query.order('price', ascending: false).range(from, to)
        : sortOrder == 'price_low'
            ? await query.order('price', ascending: true).range(from, to)
            : await query.order('created_at', ascending: false).range(from, to);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getLoadById(String id) async {
    return await _supabase
        .from('loads')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> createLoad(
      Map<String, dynamic> data) async {
    final response =
        await _supabase.from('loads').insert(data).select().single();
    return response;
  }

  Future<void> updateLoad(
      String id, Map<String, dynamic> data) async {
    // Phase 2D: Guard — only allow updates on draft/active loads
    // (booking/in_transit/completed loads are immutable except via dedicated methods)
    final current = await _supabase
        .from('loads')
        .select('status')
        .eq('id', id)
        .maybeSingle();
    final status = current?['status'] as String?;
    const mutableStatuses = ['draft', 'active'];
    if (status != null && !mutableStatuses.contains(status)) {
      throw Exception('Cannot edit load in "$status" status');
    }
    await _supabase.from('loads').update(data).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getMyLoads(String supplierId) async {
    final response = await _supabase
        .from('loads')
        .select()
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> incrementLoadViews(String loadId) async {
    await _supabase.rpc('increment_load_views', params: {'load_uuid': loadId});
  }

  // ─── DEAL / BOOKING ───

  Future<void> acceptDeal({
    required String loadId,
    required String truckerId,
    String? truckId,
  }) async {
    await _supabase.from('loads').update({
      'status': 'booked',
      'assigned_trucker_id': truckerId,
      // ignore: use_null_aware_elements
      if (truckId != null) 'assigned_truck_id': truckId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', loadId);
  }

  /// Direct booking: trucker requests to book a load.
  /// Uses atomic server-side function to prevent double-booking.
  Future<void> bookLoad({
    required String loadId,
    required String truckerId,
    required String truckId,
  }) async {
    final result = await _supabase.rpc('book_load', params: {
      'p_load_id': loadId,
      'p_trucker_id': truckerId,
      'p_truck_id': truckId,
    });
    final data = result as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Booking failed');
    }
  }

  /// Supplier approves a booking request.
  /// Uses atomic server-side function to prevent race conditions.
  Future<void> approveBooking(String loadId) async {
    final load = await getLoadById(loadId);
    if (load == null) throw Exception('Load not found');

    final result = await _supabase.rpc('approve_booking', params: {
      'p_load_id': loadId,
      'p_expected_trucker_id': load['booked_by_trucker_id'],
    });
    final data = result as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Approval failed');
    }
  }

  /// Supplier rejects a booking request — load goes back to active.
  /// Uses atomic server-side function for consistency.
  Future<void> rejectBooking(String loadId) async {
    final result = await _supabase.rpc('reject_booking', params: {
      'p_load_id': loadId,
    });
    final data = result as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Rejection failed');
    }
  }

  /// Returns the trucker's first verified truck (default for booking).
  Future<Map<String, dynamic>?> getDefaultTruck(String ownerId) async {
    final response = await _supabase
        .from('trucks')
        .select()
        .eq('owner_id', ownerId)
        .eq('status', 'verified')
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    return response;
  }

  // ─── TRIPS (trucker assigned loads) ───

  Future<List<Map<String, dynamic>>> getMyTrips(String truckerId) async {
    final response = await _supabase
        .from('loads')
        .select()
        .eq('assigned_trucker_id', truckerId)
        .inFilter('status', ['booked', 'in_transit', 'delivered', 'completed'])
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateTripStage(String loadId, String stage) async {
    final data = <String, dynamic>{'trip_stage': stage};
    if (stage == 'in_transit') {
      data['status'] = 'in_transit';
    } else if (stage == 'delivered') {
      final load = await _supabase
          .from('loads')
          .select('is_super_load, pod_photo_url')
          .eq('id', loadId)
          .maybeSingle();

      final isSuperLoad = load?['is_super_load'] == true;
      final hasPod = (load?['pod_photo_url'] as String?)?.isNotEmpty == true;

      if (isSuperLoad) {
        // Super loads require admin POD review before final completion/payout.
        data['status'] = 'in_transit';
        data['super_status'] = hasPod ? 'pod_uploaded' : 'in_transit';
      } else {
        data['status'] = 'completed';
        data['completed_at'] = DateTime.now().toIso8601String();
      }
    }
    await _supabase.from('loads').update(data).eq('id', loadId);
  }

  // ─── PAYMENT LEDGER ───

  Future<void> logPayment({
    required String loadId,
    required String payerId,
    required String paymentType,
    required double amount,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    await _supabase.from('payment_ledger').insert({
      'load_id': loadId,
      'payer_id': payerId,
      'payment_type': paymentType,
      'amount': amount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (referenceNumber != null && referenceNumber.isNotEmpty)
        'reference_number': referenceNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<List<Map<String, dynamic>>> getPaymentsForLoad(String loadId) async {
    final response = await _supabase
        .from('payment_ledger')
        .select()
        .eq('load_id', loadId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── RATINGS ───

  Future<void> submitRating({
    required String loadId,
    required String reviewerId,
    required String revieweeId,
    required String reviewerRole,
    required int score,
    String? comment,
  }) async {
    await _supabase.from('ratings').insert({
      'load_id': loadId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'reviewer_role': reviewerRole,
      'score': score,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<bool> hasRated({
    required String loadId,
    required String reviewerId,
  }) async {
    final result = await _supabase
        .from('ratings')
        .select('id')
        .eq('load_id', loadId)
        .eq('reviewer_id', reviewerId)
        .maybeSingle();
    return result != null;
  }

  // ─── TRUCKS ───

  Future<List<Map<String, dynamic>>> getMyTrucks(String ownerId) async {
    final response = await _supabase
        .from('trucks')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> addTruck(
      Map<String, dynamic> data) async {
    final response =
        await _supabase.from('trucks').insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>?> getTruckById(String id) async {
    return await _supabase
        .from('trucks')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  Future<void> deleteTruck(String truckId) async {
    final deleted = await _supabase
        .from('trucks')
        .delete()
        .eq('id', truckId)
        .select('id')
        .maybeSingle();

    if (deleted == null) {
      throw Exception('Truck delete failed: not found or not permitted');
    }
  }

  Future<List<Map<String, dynamic>>> getVerifiedTrucks(
      String ownerId) async {
    final response = await _supabase
        .from('trucks')
        .select()
        .eq('owner_id', ownerId)
        .eq('status', 'verified');
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── CONVERSATIONS ───

  Future<List<Map<String, dynamic>>> getConversationsByUser(
      String userId) async {
    // Join through suppliers/truckers → profiles to get names.
    // FK path: conversations.supplier_id → suppliers.id → profiles.id
    //          conversations.trucker_id → truckers.id → profiles.id
    final response = await _supabase
        .from('conversations')
        .select('''
          *,
          suppliers!conversations_supplier_id_fkey(id, profiles(id, full_name, avatar_url)),
          truckers!conversations_trucker_id_fkey(id, profiles(id, full_name, avatar_url))
        ''')
        .or('supplier_id.eq.$userId,trucker_id.eq.$userId')
        .order('last_message_at', ascending: false);

    final conversations = List<Map<String, dynamic>>.from(response);

    // Compute unread counts per conversation (single query)
    final allConvIds = conversations.map((c) => c['id'] as String).toList();
    if (allConvIds.isNotEmpty) {
      final unreadRows = await _supabase
          .from('messages')
          .select('conversation_id')
          .inFilter('conversation_id', allConvIds)
          .neq('sender_id', userId)
          .eq('is_read', false);
      final unreadCounts = <String, int>{};
      for (final row in unreadRows) {
        final cid = row['conversation_id'] as String;
        unreadCounts[cid] = (unreadCounts[cid] ?? 0) + 1;
      }
      for (final conv in conversations) {
        conv['unread_count'] = unreadCounts[conv['id']] ?? 0;
      }
    }

    // Backfill last message if null (single batch query)
    final conversationIds = conversations
        .where((c) {
          final text = c['last_message_text'] as String?;
          return text == null || text.isEmpty;
        })
        .map((c) => c['id'] as String)
        .toList();

    if (conversationIds.isNotEmpty) {
      final lastMessages = await _supabase
          .from('messages')
          .select('conversation_id, text_content, message_type')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false);

      // Group by conversation and take first (most recent)
      final msgMap = <String, Map<String, dynamic>>{};
      for (final msg in lastMessages) {
        final convId = msg['conversation_id'] as String;
        if (!msgMap.containsKey(convId)) {
          msgMap[convId] = msg;
        }
      }

      // Apply backfill
      for (var i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        final currentText = conv['last_message_text'] as String?;
        if (currentText == null || currentText.isEmpty) {
          final msg = msgMap[conv['id']];
          if (msg != null) {
            conv['last_message_text'] = msg['text_content'] ?? msg['message_type'] ?? '';
          }
        }
        _resolveConversationNames(conv);
        conversations[i] = conv;
      }
    } else {
      for (var i = 0; i < conversations.length; i++) {
        _resolveConversationNames(conversations[i]);
      }
    }

    return conversations;
  }

  void _resolveConversationNames(Map<String, dynamic> conv) {
    // Extract name from nested join: suppliers → profiles → full_name
    final suppliers = conv['suppliers'] as Map<String, dynamic>?;
    final truckers = conv['truckers'] as Map<String, dynamic>?;
    final supplierProfile = suppliers?['profiles'] as Map<String, dynamic>?;
    final truckerProfile = truckers?['profiles'] as Map<String, dynamic>?;
    conv['supplier_name'] = _resolveName(supplierProfile, 'Supplier');
    conv['trucker_name'] = _resolveName(truckerProfile, 'Trucker');
    conv['supplier_avatar'] = supplierProfile?['avatar_url'] as String?;
    conv['trucker_avatar'] = truckerProfile?['avatar_url'] as String?;
  }

  String _resolveName(Map<String, dynamic>? profile, [String fallback = 'User']) {
    if (profile == null) return fallback;
    final name = profile['full_name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return fallback;
  }

  /// MSG-1: Direct profile lookup by user ID — used when FK join fails.
  Future<String> getUserDisplayName(String userId) async {
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      final name = row?['full_name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return 'User';
  }

  Future<Map<String, dynamic>> getOrCreateConversation({
    required String loadId,
    required String supplierId,
    required String truckerId,
  }) async {
    final existing = await _supabase
        .from('conversations')
        .select()
        .eq('load_id', loadId)
        .eq('supplier_id', supplierId)
        .eq('trucker_id', truckerId)
        .maybeSingle();

    if (existing != null) return existing;

    final response = await _supabase.from('conversations').insert({
      'load_id': loadId,
      'supplier_id': supplierId,
      'trucker_id': truckerId,
    }).select().single();

    return response;
  }

  Future<Map<String, dynamic>?> getConversationById(String id) async {
    return await _supabase
        .from('conversations')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  // ─── MESSAGES ───

  Future<List<Map<String, dynamic>>> getMessages(
      String conversationId, {int limit = 50, int offset = 0}) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    // Reverse so oldest first for display
    return List<Map<String, dynamic>>.from(response).reversed.toList();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String type,
    String? text,
    Map<String, dynamic>? payload,
    String? voiceUrl,
    int? voiceDurationSeconds,
  }) async {
    final data = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': type,
      'text_content': text,
      'payload': payload,
    };

    if (voiceUrl != null) data['voice_url'] = voiceUrl;
    if (voiceDurationSeconds != null) {
      data['voice_duration_seconds'] = voiceDurationSeconds;
    }

    final response =
        await _supabase.from('messages').insert(data).select().single();
    return response;
  }

  Future<void> markAsRead(String messageId) async {
    await _supabase.from('messages').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> markAllAsRead(String conversationId, String currentUserId) async {
    await _supabase.from('messages').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    })
        .eq('conversation_id', conversationId)
        .neq('sender_id', currentUserId)
        .eq('is_read', false);
  }

  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    return _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  // ─── TYPING PRESENCE ───

  void sendTypingEvent(String conversationId, bool isTyping) {
    final userId = _supabase.auth.currentUser?.id;
    _supabase.channel('typing:$conversationId').sendBroadcastMessage(
      event: 'typing',
      payload: {'is_typing': isTyping, 'user_id': userId},
    );
  }

  RealtimeChannel subscribeToTyping(
    String conversationId,
    void Function(String userId, bool isTyping) onTyping,
  ) {
    return _supabase
        .channel('typing:$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final isTyping = payload['is_typing'] as bool? ?? false;
            onTyping(payload['user_id'] as String? ?? 'unknown', isTyping);
          },
        )
        .subscribe();
  }

  // ─── PAYOUT PROFILES ───

  Future<Map<String, dynamic>?> getPayoutProfile(String userId) async {
    return await _supabase
        .from('payout_profiles')
        .select()
        .eq('profile_id', userId)
        .maybeSingle();
  }

  Future<void> createPayoutProfile(
      String userId, Map<String, dynamic> data) async {
    await _supabase
        .from('payout_profiles')
        .insert({'profile_id': userId, ...data});
  }

  Future<void> updatePayoutProfile(
      String id, Map<String, dynamic> data) async {
    await _supabase.from('payout_profiles').update(data).eq('id', id);
  }

  // ─── SUPER LOADS ───

  Future<void> requestSuperLoad(String loadId, {int paymentTermDays = 10}) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    await _supabase.from('loads').update({
      'is_super_load': true,
      'super_status': 'requested',
      'payment_term_days': paymentTermDays,
    }).eq('id', loadId);

    if (currentUserId != null) {
      await _supabase.from('super_load_requests').upsert(
        {
          'load_id': loadId,
          'supplier_id': currentUserId,
          'status': 'requested',
          'payment_term_days': paymentTermDays,
        },
        onConflict: 'load_id',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getSuperLoads(
      String supplierId) async {
    final response = await _supabase
        .from('loads')
        .select()
        .eq('supplier_id', supplierId)
        .eq('is_super_load', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── SUPPORT ───

  Future<void> createTicket({
    required String userId,
    required String subject,
    required String description,
  }) async {
    await _supabase.from('support_tickets').insert({
      'user_id': userId,
      'subject': subject,
      'description': description,
    });
  }

  Future<List<Map<String, dynamic>>> getMyTickets(String userId) async {
    final response = await _supabase
        .from('support_tickets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getTicketById(String ticketId) async {
    return await _supabase
        .from('support_tickets')
        .select()
        .eq('id', ticketId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getTicketMessages(String ticketId) async {
    final response = await _supabase
        .from('support_ticket_messages')
        .select('*, sender:profiles(id, full_name, avatar_url)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addTicketMessage({
    required String ticketId,
    required String senderId,
    required String message,
  }) async {
    await _supabase.from('support_ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': senderId,
      'message': message,
    });
  }

  // ─── CONSENTS ───

  Future<void> recordConsent({
    required String profileId,
    required String consentType,
    required String consentVersion,
  }) async {
    await _supabase.from('user_consents').insert({
      'profile_id': profileId,
      'consent_type': consentType,
      'consent_version': consentVersion,
    });
  }
}
