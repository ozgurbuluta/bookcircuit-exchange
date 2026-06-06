import { OpenLibraryBook, OpenLibraryResponse, Book, BookCondition, Profile, BookWithRequestDetails } from './types';
import { db, auth } from './firebase';
import {
  collection,
  doc,
  addDoc,
  getDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

// Base URL for Open Library API
const OPEN_LIBRARY_API_URL = 'https://openlibrary.org';

// Helper to convert Firestore document to Book
const docToBook = (docSnap: any, includeOwner?: Profile): Book => {
  const data = docSnap.data ? docSnap.data() : docSnap;
  const id = docSnap.id || data.id;

  return {
    id,
    user_id: data.userId,
    title: data.title || '',
    author: data.author || '',
    description: data.description || '',
    condition: data.condition || 'Good',
    isbn: data.isbn || '',
    cover_img_url: data.coverImgUrl || '',
    publisher: data.publisher || '',
    publication_year: data.publicationYear,
    language: data.language || '',
    pages: data.pages,
    genres: data.genres || [],
    location_text: data.locationText || '',
    postal_code: data.postalCode || '',
    location_lat: data.locationLat,
    location_lng: data.locationLng,
    status: data.status || 'available',
    current_trade_id: data.currentTradeId,
    trade_count: data.tradeCount || 0,
    interest_count: data.interestCount || 0,
    created_at: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    updated_at: data.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    owner: includeOwner,
  };
};

// Helper to convert Book to Firestore data
const bookToFirestore = (book: Partial<Book> & { user_id?: string }) => {
  return {
    userId: book.user_id,
    title: book.title || '',
    author: book.author || '',
    description: book.description || '',
    condition: book.condition || 'Good',
    isbn: book.isbn || '',
    coverImgUrl: book.cover_img_url || '',
    publisher: book.publisher || '',
    publicationYear: book.publication_year || null,
    language: book.language || '',
    pages: book.pages || null,
    genres: book.genres || [],
    locationText: book.location_text || '',
    postalCode: book.postal_code || '',
    locationLat: book.location_lat || null,
    locationLng: book.location_lng || null,
    status: book.status || 'available',
    currentTradeId: book.current_trade_id || null,
    tradeCount: book.trade_count || 0,
    interestCount: book.interest_count || 0,
    updatedAt: serverTimestamp(),
  };
};

// Helper to fetch user profile
const fetchUserProfile = async (userId: string): Promise<Profile | undefined> => {
  try {
    const userDoc = await getDoc(doc(db, 'users', userId));
    if (userDoc.exists()) {
      const data = userDoc.data();
      return {
        id: userDoc.id,
        full_name: data.fullName || '',
        avatar_url: data.avatarUrl || '',
        email: data.email || '',
        location_city: data.locationCity || '',
        location_state: data.locationState || '',
        location_country: data.locationCountry || '',
      } as Profile;
    }
  } catch (error) {
    console.error('Error fetching user profile:', error);
  }
  return undefined;
};

// Calculate distance between two points (Haversine formula)
const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number): number => {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in km
};

// Search for books by title, author, or ISBN (Open Library API)
export const searchBooks = async (query: string): Promise<OpenLibraryBook[]> => {
  try {
    const response = await fetch(
      `${OPEN_LIBRARY_API_URL}/search.json?q=${encodeURIComponent(query)}&limit=10`
    );

    if (!response.ok) {
      throw new Error(`Error fetching book data: ${response.statusText}`);
    }

    const data: OpenLibraryResponse = await response.json();

    // Enhance the search results with additional data where possible
    const enhancedResults = await Promise.all(
      data.docs.map(async (book) => {
        if (book.key && book.key.startsWith('/works/')) {
          try {
            const workResponse = await fetch(`${OPEN_LIBRARY_API_URL}${book.key}.json`);
            if (workResponse.ok) {
              const workData = await workResponse.json();
              return {
                ...book,
                description: workData.description || book.description,
                covers: workData.covers || book.covers
              };
            }
          } catch (error) {
            console.error('Error fetching additional book details:', error);
          }
        }
        return book;
      })
    );

    return enhancedResults;
  } catch (error) {
    console.error('Error searching books:', error);
    return [];
  }
};

// Get book cover image URL from Open Library
export const getBookCoverUrl = (coverId: number, size: 'S' | 'M' | 'L' = 'M'): string => {
  return `https://covers.openlibrary.org/b/id/${coverId}-${size}.jpg`;
};

// Format book data from Open Library for our database
export const formatBookData = (bookData: OpenLibraryBook): Partial<Book> => {
  let description = '';
  if (typeof bookData.description === 'string') {
    description = bookData.description;
  } else if (bookData.description && typeof bookData.description === 'object' && 'value' in bookData.description) {
    description = bookData.description.value;
  }

  let author = '';
  if (bookData.authors && bookData.authors.length > 0 && bookData.authors[0].name) {
    author = bookData.authors[0].name;
  } else if (bookData.author_name && bookData.author_name.length > 0) {
    author = bookData.author_name[0];
  }

  let isbn = '';
  if (bookData.isbn_13 && bookData.isbn_13.length > 0) {
    isbn = bookData.isbn_13[0];
  } else if (bookData.isbn_10 && bookData.isbn_10.length > 0) {
    isbn = bookData.isbn_10[0];
  } else if (bookData.isbn && bookData.isbn.length > 0) {
    isbn = bookData.isbn[0];
  }

  let coverImgUrl = undefined;
  if (bookData.covers && bookData.covers.length > 0) {
    coverImgUrl = getBookCoverUrl(bookData.covers[0]);
  } else if (bookData.cover_i) {
    coverImgUrl = getBookCoverUrl(bookData.cover_i);
  }

  return {
    title: bookData.title,
    author,
    isbn,
    description,
    cover_img_url: coverImgUrl,
  };
};

// Add a new book to the database
export const addBook = async (
  userId: string,
  bookData: {
    title: string;
    author?: string;
    location_text: string;
    condition: BookCondition;
    cover_img_url?: string;
    isbn?: string;
    description?: string;
    postal_code?: string;
    lat?: number;
    lng?: number;
  }
): Promise<{ success: boolean; error?: string; book?: Book }> => {
  try {
    const firestoreData = {
      userId,
      title: bookData.title,
      author: bookData.author || '',
      description: bookData.description || '',
      condition: bookData.condition,
      isbn: bookData.isbn || '',
      coverImgUrl: bookData.cover_img_url || '',
      locationText: bookData.location_text,
      postalCode: bookData.postal_code || '',
      locationLat: bookData.lat || null,
      locationLng: bookData.lng || null,
      status: 'available',
      tradeCount: 0,
      interestCount: 0,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    const docRef = await addDoc(collection(db, 'books'), firestoreData);
    const newDoc = await getDoc(docRef);

    return { success: true, book: docToBook(newDoc) };
  } catch (error) {
    console.error('Error adding book:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

// Get all books for a user
export const getUserBooks = async (userId: string): Promise<Book[]> => {
  try {
    const q = query(
      collection(db, 'books'),
      where('userId', '==', userId),
      orderBy('createdAt', 'desc')
    );

    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => docToBook(doc));
  } catch (error) {
    console.error('Error getting user books:', error);
    return [];
  }
};

// Get all books (with optional limit)
export const getAllBooks = async (limitCount?: number): Promise<Book[]> => {
  try {
    let q = query(
      collection(db, 'books'),
      orderBy('createdAt', 'desc')
    );

    if (limitCount) {
      q = query(q, limit(limitCount));
    }

    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => docToBook(doc));
  } catch (error) {
    console.error('Error getting all books:', error);
    return [];
  }
};

// Get a book by ID
export const getBookById = async (bookId: string): Promise<Book | null> => {
  try {
    const docSnap = await getDoc(doc(db, 'books', bookId));

    if (!docSnap.exists()) {
      return null;
    }

    const book = docToBook(docSnap);

    // Fetch owner profile
    if (book.user_id) {
      book.owner = await fetchUserProfile(book.user_id);
    }

    return book;
  } catch (error) {
    console.error('Error getting book by ID:', error);
    return null;
  }
};

// Delete a book
export const deleteBook = async (bookId: string): Promise<{ success: boolean; error?: string }> => {
  try {
    await deleteDoc(doc(db, 'books', bookId));
    return { success: true };
  } catch (error) {
    console.error('Error deleting book:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

// Update an existing book
export const updateBook = async (
  bookId: string,
  bookData: {
    title: string;
    author?: string;
    location_text: string;
    condition: BookCondition;
    cover_img_url?: string;
    isbn?: string;
    description?: string;
    postal_code?: string;
    lat?: number;
    lng?: number;
  }
): Promise<{ success: boolean; error?: string; book?: Book }> => {
  try {
    const updateData = {
      title: bookData.title,
      author: bookData.author || '',
      description: bookData.description || '',
      condition: bookData.condition,
      isbn: bookData.isbn || '',
      coverImgUrl: bookData.cover_img_url || '',
      locationText: bookData.location_text,
      postalCode: bookData.postal_code || '',
      locationLat: bookData.lat || null,
      locationLng: bookData.lng || null,
      updatedAt: serverTimestamp(),
    };

    await updateDoc(doc(db, 'books', bookId), updateData);

    const updatedDoc = await getDoc(doc(db, 'books', bookId));
    return { success: true, book: docToBook(updatedDoc) };
  } catch (error) {
    console.error('Error updating book:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

// Get recently added books
export const getRecentlyAddedBooks = async (limitCount: number = 8): Promise<Book[]> => {
  try {
    const q = query(
      collection(db, 'books'),
      where('status', '==', 'available'),
      orderBy('createdAt', 'desc'),
      limit(limitCount)
    );

    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => docToBook(doc));
  } catch (error) {
    console.error('Error fetching recently added books:', error);
    return [];
  }
};

// Search books by various parameters
export const searchBooksByParams = async (
  params: {
    title?: string;
    author?: string;
    postal_code?: string;
    radius?: number;
    latitude?: number;
    longitude?: number;
  }
): Promise<Book[]> => {
  try {
    // Get all available books first
    const q = query(
      collection(db, 'books'),
      where('status', '==', 'available'),
      orderBy('createdAt', 'desc'),
      limit(100)
    );

    const snapshot = await getDocs(q);
    let results = snapshot.docs.map(doc => docToBook(doc));

    // Apply text filters
    if (params.title) {
      const titleLower = params.title.toLowerCase();
      results = results.filter(book =>
        book.title.toLowerCase().includes(titleLower)
      );
    }

    if (params.author) {
      const authorLower = params.author.toLowerCase();
      results = results.filter(book =>
        book.author?.toLowerCase().includes(authorLower)
      );
    }

    if (params.postal_code) {
      results = results.filter(book =>
        book.postal_code === params.postal_code
      );
    }

    // Apply geographic filter if provided
    if (params.latitude && params.longitude && params.radius) {
      results = results.filter(book => {
        if (!book.location_lat || !book.location_lng) return false;

        const distance = calculateDistance(
          params.latitude!,
          params.longitude!,
          book.location_lat,
          book.location_lng
        );

        // Add distance to book object
        (book as any).distance_km = distance;
        (book as any).calculated_distance_meters = distance * 1000;

        return distance <= params.radius!;
      });

      // Sort by distance
      results.sort((a, b) => {
        const distA = (a as any).distance_km || Infinity;
        const distB = (b as any).distance_km || Infinity;
        return distA - distB;
      });
    }

    return results;
  } catch (error) {
    console.error('Error searching books:', error);
    return [];
  }
};

// Quick search books by title or author
export const quickSearchBooks = async (searchQuery: string): Promise<Book[]> => {
  try {
    if (!searchQuery.trim()) {
      return [];
    }

    const q = query(
      collection(db, 'books'),
      where('status', '==', 'available'),
      orderBy('createdAt', 'desc'),
      limit(50)
    );

    const snapshot = await getDocs(q);
    const allBooks = snapshot.docs.map(doc => docToBook(doc));

    const queryLower = searchQuery.toLowerCase();
    return allBooks.filter(book =>
      book.title.toLowerCase().includes(queryLower) ||
      book.author?.toLowerCase().includes(queryLower)
    );
  } catch (error) {
    console.error('Error in quick search:', error);
    return [];
  }
};

// Request a book
export const requestBook = async (
  bookId: string,
  requesterId: string
): Promise<{ success: boolean; requestId?: string; error?: string }> => {
  try {
    // First, check if the book exists
    const bookDoc = await getDoc(doc(db, 'books', bookId));

    if (!bookDoc.exists()) {
      return { success: false, error: 'Book not found' };
    }

    const bookData = bookDoc.data();

    // Don't allow requesting your own book
    if (bookData.userId === requesterId) {
      return { success: false, error: 'You cannot request your own book' };
    }

    // Check if a request already exists
    const existingQuery = query(
      collection(db, 'bookRequests'),
      where('bookId', '==', bookId),
      where('requesterId', '==', requesterId),
      where('status', '==', 'pending')
    );

    const existingSnapshot = await getDocs(existingQuery);
    if (!existingSnapshot.empty) {
      return { success: false, error: 'You have already requested this book' };
    }

    // Create the request
    const requestData = {
      bookId,
      requesterId,
      ownerId: bookData.userId,
      status: 'pending',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    const requestRef = await addDoc(collection(db, 'bookRequests'), requestData);

    // Create a notification for the book owner
    await addDoc(collection(db, 'notifications'), {
      userId: bookData.userId,
      type: 'book_request',
      message: 'Someone has requested your book',
      relatedId: bookId,
      read: false,
      createdAt: serverTimestamp(),
    });

    return { success: true, requestId: requestRef.id };
  } catch (error) {
    console.error('Error requesting book:', error);
    return { success: false, error: 'An unexpected error occurred' };
  }
};

// Cancel a book request
export const cancelBookRequest = async (
  requestId: string,
  requesterId: string
): Promise<{ success: boolean; error?: string }> => {
  try {
    const requestDoc = await getDoc(doc(db, 'bookRequests', requestId));

    if (!requestDoc.exists()) {
      return { success: false, error: 'Request not found.' };
    }

    const requestData = requestDoc.data();

    if (requestData.requesterId !== requesterId) {
      return { success: false, error: 'You are not authorized to cancel this request.' };
    }

    await deleteDoc(doc(db, 'bookRequests', requestId));

    return { success: true };
  } catch (error) {
    console.error('Error cancelling book request:', error);
    return { success: false, error: 'An unexpected error occurred during cancellation.' };
  }
};

// Get requested books for a user
export const getUserRequestedBooks = async (userId: string): Promise<BookWithRequestDetails[]> => {
  try {
    const q = query(
      collection(db, 'bookRequests'),
      where('requesterId', '==', userId),
      orderBy('createdAt', 'desc')
    );

    const snapshot = await getDocs(q);
    const requests = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Fetch book details for each request
    const booksWithDetails: BookWithRequestDetails[] = [];

    for (const request of requests) {
      const bookDoc = await getDoc(doc(db, 'books', (request as any).bookId));

      if (bookDoc.exists()) {
        const book = docToBook(bookDoc);

        // Fetch owner profile
        if ((request as any).ownerId) {
          book.owner = await fetchUserProfile((request as any).ownerId);
        }

        booksWithDetails.push({
          ...book,
          request_id: request.id,
          request_status: (request as any).status,
          request_date: (request as any).createdAt?.toDate?.()?.toISOString(),
        });
      }
    }

    return booksWithDetails;
  } catch (error) {
    console.error('Error fetching requested books:', error);
    return [];
  }
};

// Test function for debugging
export const testGeographyColumn = async (): Promise<{ success: boolean; message: string }> => {
  try {
    const books = await getAllBooks(5);
    console.log('Sample books:', books);
    return {
      success: true,
      message: `Found ${books.length} books in the database`
    };
  } catch (error) {
    console.error('Error testing:', error);
    return {
      success: false,
      message: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};
