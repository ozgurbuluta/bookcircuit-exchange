import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import '../models/models.dart';

/// Supabase service for database operations
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );
  }

  // ============ AUTH ============

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Get current session
  static Session? get currentSession => client.auth.currentSession;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
    return response;
  }

  /// Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  // ============ PROFILES ============

  /// Get profile by ID
  static Future<Profile?> getProfile(String userId) async {
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  /// Get current user's profile
  static Future<Profile?> getCurrentProfile() async {
    if (currentUser == null) return null;
    return getProfile(currentUser!.id);
  }

  /// Update profile
  static Future<Profile?> updateProfile(Profile profile) async {
    final response = await client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', profile.id)
        .select()
        .single();

    return Profile.fromJson(response);
  }

  /// Create profile (for new users)
  static Future<Profile> createProfile(Profile profile) async {
    final response = await client
        .from('profiles')
        .insert(profile.toJson())
        .select()
        .single();

    return Profile.fromJson(response);
  }

  // ============ BOOKS ============

  /// Get books with optional filters
  static Future<List<Book>> getBooks({
    String? query,
    String? genre,
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    var request = client.from('books').select('*, owner:profiles(*)');

    if (query != null && query.isNotEmpty) {
      request = request.or('title.ilike.%$query%,author.ilike.%$query%');
    }

    if (genre != null && genre != 'All') {
      request = request.contains('genres', [genre]);
    }

    if (userId != null) {
      request = request.eq('user_id', userId);
    }

    final response = await request
        .eq('status', 'available')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => Book.fromJson(e)).toList();
  }

  /// Get books within distance (geographic search)
  static Future<List<Book>> getBooksWithinDistance({
    required double lat,
    required double lng,
    required double maxDistanceMeters,
    String? query,
    String? genre,
    int limit = 50,
  }) async {
    final response = await client.rpc('books_within_distance', params: {
      'search_lat': lat,
      'search_lng': lng,
      'max_distance_meters': maxDistanceMeters,
    });

    List<Book> books =
        (response as List).map((e) => Book.fromJson(e)).toList();

    // Apply additional filters client-side
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      books = books
          .where((b) =>
              b.title.toLowerCase().contains(q) ||
              b.author.toLowerCase().contains(q))
          .toList();
    }

    if (genre != null && genre != 'All') {
      books = books
          .where((b) => b.genres?.contains(genre) ?? false)
          .toList();
    }

    return books.take(limit).toList();
  }

  /// Get book by ID
  static Future<Book?> getBook(String bookId) async {
    final response = await client
        .from('books')
        .select('*, owner:profiles(*)')
        .eq('id', bookId)
        .maybeSingle();

    if (response == null) return null;
    return Book.fromJson(response);
  }

  /// Get user's books
  static Future<List<Book>> getUserBooks(String userId) async {
    final response = await client
        .from('books')
        .select('*, owner:profiles(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Book.fromJson(e)).toList();
  }

  /// Get current user's books
  static Future<List<Book>> getMyBooks() async {
    if (currentUser == null) return [];
    return getUserBooks(currentUser!.id);
  }

  /// Create book
  static Future<Book> createBook(Book book) async {
    final response = await client
        .from('books')
        .insert(book.toJson())
        .select('*, owner:profiles(*)')
        .single();

    return Book.fromJson(response);
  }

  /// Update book
  static Future<Book> updateBook(Book book) async {
    final response = await client
        .from('books')
        .update(book.toJson())
        .eq('id', book.id)
        .select('*, owner:profiles(*)')
        .single();

    return Book.fromJson(response);
  }

  /// Delete book
  static Future<void> deleteBook(String bookId) async {
    await client.from('books').delete().eq('id', bookId);
  }

  // ============ TRADES ============

  /// Get user's trades
  static Future<List<Trade>> getUserTrades({String? statusFilter}) async {
    final response = await client.rpc('get_user_trades', params: {
      'p_status_filter': statusFilter,
    });

    return (response as List).map((e) => Trade.fromJson(e)).toList();
  }

  /// Get trade by ID
  static Future<Trade?> getTrade(String tradeId) async {
    final response = await client
        .from('trades')
        .select('''
          *,
          initiator:profiles!initiator_id(*),
          recipient:profiles!recipient_id(*),
          items:trade_items(*, book:books(*))
        ''')
        .eq('id', tradeId)
        .maybeSingle();

    if (response == null) return null;
    return Trade.fromJson(response);
  }

  /// Create trade
  static Future<Trade?> createTrade({
    required String partnerId,
    required List<String> myBookIds,
    required List<String> theirBookIds,
    String? message,
  }) async {
    final response = await client.rpc('create_trade', params: {
      'p_partner_id': partnerId,
      'p_my_book_ids': myBookIds,
      'p_their_book_ids': theirBookIds,
      'p_message': message,
    });

    if (response != null && response['id'] != null) {
      return getTrade(response['id']);
    }
    return null;
  }

  /// Update trade status
  static Future<void> updateTradeStatus({
    required String tradeId,
    required String newStatus,
  }) async {
    await client.rpc('update_trade_status', params: {
      'p_trade_id': tradeId,
      'p_new_status': newStatus,
    });
  }

  // ============ CONVERSATIONS ============

  /// Get user's conversations
  static Future<List<Conversation>> getConversations() async {
    if (currentUser == null) return [];

    final response = await client
        .from('conversations')
        .select('''
          *,
          participants:conversation_participants(*, user:profiles(*))
        ''')
        .order('last_message_at', ascending: false);

    final conversations =
        (response as List).map((e) => Conversation.fromJson(e)).toList();

    // Add other_user to each conversation
    return conversations.map((conv) {
      final otherParticipant = conv.participants.firstWhere(
        (p) => p.odroid != currentUser!.id,
        orElse: () => conv.participants.first,
      );
      return Conversation(
        id: conv.id,
        createdAt: conv.createdAt,
        updatedAt: conv.updatedAt,
        lastMessage: conv.lastMessage,
        lastMessageAt: conv.lastMessageAt,
        lastMessageSenderId: conv.lastMessageSenderId,
        unreadCount: conv.unreadCount,
        participants: conv.participants,
        otherUser: otherParticipant.user,
        bookId: conv.bookId,
        book: conv.book,
      );
    }).toList();
  }

  /// Get messages for a conversation
  static Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await client
        .from('messages')
        .select('*, user:profiles(*)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => Message.fromJson(e)).toList();
  }

  /// Send message
  static Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String? relatedBookId,
  }) async {
    final response = await client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'user_id': currentUser!.id,
          'content': content,
          'related_book_id': relatedBookId,
        })
        .select('*, user:profiles(*)')
        .single();

    return Message.fromJson(response);
  }

  /// Start or get existing conversation
  static Future<Conversation?> startConversation({
    required String otherUserId,
    String? initialMessage,
    String? bookId,
  }) async {
    final response = await client.rpc('start_conversation', params: {
      'other_user_id': otherUserId,
      'initial_message': initialMessage,
      'book_id': bookId,
    });

    if (response != null && response['conversation_id'] != null) {
      // Fetch the full conversation
      final convResponse = await client
          .from('conversations')
          .select('''
            *,
            participants:conversation_participants(*, user:profiles(*))
          ''')
          .eq('id', response['conversation_id'])
          .single();

      return Conversation.fromJson(convResponse);
    }
    return null;
  }

  // ============ BOOK INTERESTS ============

  /// Toggle book interest
  static Future<bool> toggleBookInterest(String bookId) async {
    if (currentUser == null) return false;

    // Check if interest exists
    final existing = await client
        .from('book_interests')
        .select()
        .eq('user_id', currentUser!.id)
        .eq('book_id', bookId)
        .maybeSingle();

    if (existing != null) {
      // Remove interest
      await client.from('book_interests').delete().eq('id', existing['id']);
      return false;
    } else {
      // Add interest
      await client.from('book_interests').insert({
        'user_id': currentUser!.id,
        'book_id': bookId,
        'status': 'active',
      });
      return true;
    }
  }

  /// Check if user is interested in a book
  static Future<bool> isInterestedInBook(String bookId) async {
    if (currentUser == null) return false;

    final response = await client
        .from('book_interests')
        .select()
        .eq('user_id', currentUser!.id)
        .eq('book_id', bookId)
        .eq('status', 'active')
        .maybeSingle();

    return response != null;
  }

  // ============ REALTIME ============

  /// Subscribe to messages in a conversation
  static RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Message) onMessage,
  ) {
    return client
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
            final message = Message.fromJson(payload.newRecord);
            onMessage(message);
          },
        )
        .subscribe();
  }

  /// Subscribe to trade updates
  static RealtimeChannel subscribeToTrades(
    void Function(Trade) onUpdate,
  ) {
    if (currentUser == null) {
      throw Exception('User must be logged in to subscribe to trades');
    }

    return client
        .channel('trades:${currentUser!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trades',
          callback: (payload) async {
            final trade = await getTrade(payload.newRecord['id']);
            if (trade != null) onUpdate(trade);
          },
        )
        .subscribe();
  }

  /// Unsubscribe from a channel
  static Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }
}
