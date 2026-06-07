import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

/// Firebase service for database operations
class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;

  // ============ AUTH ============

  /// Get current user
  static User? get currentUser => auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  /// Sign up with email and password
  static Future<UserCredential> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user profile in Firestore
    if (credential.user != null) {
      await db.collection('users').doc(credential.user!.uid).set({
        'id': credential.user!.uid,
        'email': email,
        'fullName': fullName ?? '',
        'avatarUrl': '',
        'bio': '',
        'website': '',
        'university': '',
        'locationCity': '',
        'locationState': '',
        'locationCountry': '',
        'locationLat': null,
        'locationLng': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return credential;
  }

  /// Sign in with email and password
  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  static Future<void> signOut() async {
    await auth.signOut();
  }

  /// Send password reset email
  static Future<void> resetPassword(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  /// Listen to auth state changes
  static Stream<User?> get authStateChanges => auth.authStateChanges();

  // ============ PROFILES ============

  /// Get profile by ID
  static Future<Profile?> getProfile(String userId) async {
    final doc = await db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return _docToProfile(doc);
  }

  /// Get current user's profile
  static Future<Profile?> getCurrentProfile() async {
    if (currentUser == null) return null;
    return getProfile(currentUser!.uid);
  }

  /// Update profile
  static Future<Profile?> updateProfile(Profile profile) async {
    await db.collection('users').doc(profile.id).update({
      'fullName': profile.fullName,
      'avatarUrl': profile.avatarUrl,
      'bio': profile.bio,
      'website': profile.website,
      'university': profile.university,
      'locationCity': profile.locationCity,
      'locationState': profile.locationState,
      'locationCountry': profile.locationCountry,
      'locationLat': profile.locationLat,
      'locationLng': profile.locationLng,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return getProfile(profile.id);
  }

  // ============ BOOKS ============

  /// Get books with optional filters
  static Future<List<Book>> getBooks({
    String? query,
    String? genre,
    String? userId,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> ref = db
        .collection('books')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (userId != null) {
      ref = db
          .collection('books')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    final snapshot = await ref.get();
    List<Book> books = snapshot.docs.map((doc) => _docToBook(doc)).toList();

    // Apply client-side filtering for text search
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      books = books.where((b) =>
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q)).toList();
    }

    if (genre != null && genre != 'All') {
      books = books.where((b) => b.genres?.contains(genre) ?? false).toList();
    }

    return books;
  }

  /// Get book by ID
  static Future<Book?> getBook(String bookId) async {
    final doc = await db.collection('books').doc(bookId).get();
    if (!doc.exists) return null;

    var book = _docToBook(doc);

    // Fetch owner profile
    if (book.userId.isNotEmpty) {
      final owner = await getProfile(book.userId);
      book = book.copyWith(owner: owner);
    }

    return book;
  }

  /// Get user's books
  static Future<List<Book>> getUserBooks(String userId) async {
    final snapshot = await db
        .collection('books')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => _docToBook(doc)).toList();
  }

  /// Get current user's books
  static Future<List<Book>> getMyBooks() async {
    if (currentUser == null) return [];
    return getUserBooks(currentUser!.uid);
  }

  /// Create book
  static Future<Book> createBook(Book book) async {
    final docRef = await db.collection('books').add({
      'userId': book.userId,
      'title': book.title,
      'author': book.author,
      'description': book.description,
      'condition': book.condition.name,
      'isbn': book.isbn,
      'coverImgUrl': book.coverImgUrl,
      'publisher': book.publisher,
      'publicationYear': book.publicationYear,
      'language': book.language,
      'pages': book.pages,
      'genres': book.genres,
      'locationText': book.locationText,
      'postalCode': book.postalCode,
      'locationLat': book.locationLat,
      'locationLng': book.locationLng,
      'status': book.status.name,
      'tradeCount': 0,
      'interestCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final newDoc = await docRef.get();
    return _docToBook(newDoc);
  }

  /// Update book
  static Future<Book?> updateBook(Book book) async {
    await db.collection('books').doc(book.id).update({
      'title': book.title,
      'author': book.author,
      'description': book.description,
      'condition': book.condition.name,
      'isbn': book.isbn,
      'coverImgUrl': book.coverImgUrl,
      'locationText': book.locationText,
      'postalCode': book.postalCode,
      'locationLat': book.locationLat,
      'locationLng': book.locationLng,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return getBook(book.id);
  }

  /// Delete book
  static Future<void> deleteBook(String bookId) async {
    await db.collection('books').doc(bookId).delete();
  }

  // ============ TRADES ============

  /// Get user's trades
  static Future<List<Trade>> getUserTrades({String? statusFilter}) async {
    if (currentUser == null) return [];

    // Get trades where user is initiator
    final initiatorSnapshot = await db
        .collection('trades')
        .where('initiatorId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .get();

    // Get trades where user is recipient
    final recipientSnapshot = await db
        .collection('trades')
        .where('recipientId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .get();

    // Combine and deduplicate
    final Map<String, DocumentSnapshot> tradeMap = {};
    for (final doc in initiatorSnapshot.docs) {
      tradeMap[doc.id] = doc;
    }
    for (final doc in recipientSnapshot.docs) {
      tradeMap[doc.id] = doc;
    }

    List<Trade> trades = await Future.wait(
      tradeMap.values.map((doc) => _docToTrade(doc)),
    );

    // Apply status filter
    if (statusFilter != null) {
      trades = trades.where((t) => t.status.name == statusFilter).toList();
    }

    // Sort by date
    trades.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return trades;
  }

  /// Get trade by ID
  static Future<Trade?> getTrade(String tradeId) async {
    final doc = await db.collection('trades').doc(tradeId).get();
    if (!doc.exists) return null;
    return _docToTrade(doc);
  }

  /// Update trade status
  static Future<void> updateTradeStatus({
    required String tradeId,
    required String newStatus,
  }) async {
    await db.collection('trades').doc(tradeId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ CONVERSATIONS ============

  /// Get user's conversations
  static Future<List<Conversation>> getConversations() async {
    if (currentUser == null) return [];

    final snapshot = await db
        .collection('conversations')
        .where('participantIds', arrayContains: currentUser!.uid)
        .orderBy('lastMessageAt', descending: true)
        .get();

    return Future.wait(
      snapshot.docs.map((doc) => _docToConversation(doc)),
    );
  }

  /// Get messages for a conversation
  static Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final snapshot = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final messages = await Future.wait(
      snapshot.docs.map((doc) => _docToMessage(doc, conversationId)),
    );

    // Return in chronological order
    return messages.reversed.toList();
  }

  /// Send message
  static Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String? relatedBookId,
  }) async {
    if (currentUser == null) throw Exception('Not authenticated');

    final docRef = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
      'userId': currentUser!.uid,
      'content': content,
      'relatedBookId': relatedBookId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update conversation
    await db.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final newDoc = await docRef.get();
    return _docToMessage(newDoc, conversationId);
  }

  /// Subscribe to messages
  static Stream<List<Message>> subscribeToMessages(String conversationId) {
    return db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .asyncMap((snapshot) async {
      return Future.wait(
        snapshot.docs.map((doc) => _docToMessage(doc, conversationId)),
      );
    });
  }

  // ============ HELPERS ============

  static Profile _docToProfile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Profile(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      bio: data['bio'] ?? '',
      website: data['website'] ?? '',
      university: data['university'] ?? '',
      locationCity: data['locationCity'] ?? '',
      locationState: data['locationState'] ?? '',
      locationCountry: data['locationCountry'] ?? '',
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Book _docToBook(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Book(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      description: data['description'] ?? '',
      condition: BookCondition.values.firstWhere(
        (e) => e.name == data['condition'],
        orElse: () => BookCondition.good,
      ),
      isbn: data['isbn'],
      coverImgUrl: data['coverImgUrl'],
      publisher: data['publisher'],
      publicationYear: data['publicationYear'],
      language: data['language'],
      pages: data['pages'],
      genres: (data['genres'] as List<dynamic>?)?.cast<String>(),
      locationText: data['locationText'] ?? '',
      postalCode: data['postalCode'],
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
      status: BookStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => BookStatus.available,
      ),
      tradeCount: data['tradeCount'] ?? 0,
      interestCount: data['interestCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Future<Trade> _docToTrade(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Fetch initiator and recipient profiles
    final initiator = data['initiatorId'] != null
        ? await getProfile(data['initiatorId'])
        : null;
    final recipient = data['recipientId'] != null
        ? await getProfile(data['recipientId'])
        : null;

    // Fetch trade items
    final itemsSnapshot = await db
        .collection('trades')
        .doc(doc.id)
        .collection('tradeItems')
        .get();

    final items = await Future.wait(
      itemsSnapshot.docs.map((itemDoc) async {
        final itemData = itemDoc.data();
        final book = itemData['bookId'] != null
            ? await getBook(itemData['bookId'])
            : null;

        return TradeItem(
          id: itemDoc.id,
          tradeId: doc.id,
          bookId: itemData['bookId'] ?? '',
          ownerId: itemData['ownerId'] ?? '',
          recipientId: itemData['recipientId'] ?? '',
          itemType: 'book',
          book: book,
          createdAt: (itemData['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        );
      }),
    );

    return Trade(
      id: doc.id,
      initiatorId: data['initiatorId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      status: TradeStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TradeStatus.pending,
      ),
      initiatorMessage: data['initiatorMessage'],
      recipientMessage: data['recipientMessage'],
      isDirectRequest: data['isDirectRequest'] ?? false,
      isCounteroffered: data['isCounteroffered'] ?? false,
      initiator: initiator,
      recipient: recipient,
      items: items,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Future<Conversation> _docToConversation(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Find other user
    final participantIds =
        (data['participantIds'] as List<dynamic>?)?.cast<String>() ?? [];
    final otherUserId = participantIds.firstWhere(
      (id) => id != currentUser?.uid,
      orElse: () => '',
    );

    final otherUser =
        otherUserId.isNotEmpty ? await getProfile(otherUserId) : null;

    return Conversation(
      id: doc.id,
      lastMessage: data['lastMessage'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: 0, // TODO: Calculate from subcollection
      otherUser: otherUser,
      bookId: data['bookId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static Future<Message> _docToMessage(
      DocumentSnapshot doc, String conversationId) async {
    final data = doc.data() as Map<String, dynamic>;

    final user =
        data['userId'] != null ? await getProfile(data['userId']) : null;

    return Message(
      id: doc.id,
      conversationId: conversationId,
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      relatedBookId: data['relatedBookId'],
      user: user,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
