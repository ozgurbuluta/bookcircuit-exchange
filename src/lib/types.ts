// Database types for TypeScript
export interface Profile {
  id: string;
  full_name?: string;
  avatar_url?: string;
  email?: string;
  location_city?: string;
  location_state?: string;
  location_country?: string;
  location_lat?: number;
  location_lng?: number;
  bio?: string;
  website?: string;
  university?: string;
  created_at?: string;
  updated_at?: string;
}

export interface Book {
  id: string;
  user_id: string;
  title: string;
  author: string;
  description?: string;
  condition: 'New' | 'Like New' | 'Very Good' | 'Good' | 'Acceptable' | 'Poor';
  isbn?: string;
  cover_img_url?: string;
  publisher?: string;
  publication_year?: number;
  language?: string;
  pages?: number;
  genres?: string[];
  location_text?: string;
  postal_code?: string;
  location_lat?: number;
  location_lng?: number;
  created_at: string;
  updated_at: string;
  owner?: Profile;
  status?: 'available' | 'requested' | 'trading' | 'completed';
  current_trade_id?: string;
  trade_count?: number;
  interest_count?: number;
  // Distance properties for geographic search results
  distance_km?: number;
  distance_meters?: number;
  calculated_distance_meters?: number;
}

export type BookCondition = Book['condition'];

// Single source of truth for selectable book conditions. Use this in every
// book form so the options can never drift out of sync with the Book type.
export const BOOK_CONDITIONS: readonly BookCondition[] = [
  'New',
  'Like New',
  'Very Good',
  'Good',
  'Acceptable',
  'Poor',
] as const;

// New type extending Book with request details
export interface BookWithRequestDetails extends Book {
  request_id?: string;
  request_status?: 'pending' | 'accepted' | 'rejected' | 'expired';
  request_date?: string;
}

export interface BookRequest {
  id: string;
  from_user_id: string;
  to_user_id: string;
  book_id: string;
  status: 'pending' | 'accepted' | 'rejected' | 'expired';
  created_at: string;
  updated_at: string;
  message?: string;
  from_user?: Profile;
  to_user?: Profile;
  book?: Book;
  trade_id?: string;
}

export interface BookInterest {
  id: string;
  user_id: string;
  book_id: string;
  created_at: string;
  updated_at: string;
  status: 'active' | 'inactive';
  note?: string;
  user?: Profile;
  book?: Book;
}

export interface Trade {
  id: string;
  initiator_id: string;
  recipient_id: string;
  status: 'request_pending' | 'pending' | 'accepted' | 'rejected' | 'completed' | 'cancelled';
  created_at: string;
  updated_at: string;
  initiator_message?: string;
  recipient_message?: string;
  is_direct_request: boolean;
  is_counteroffered: boolean;
  initiator?: Profile;
  recipient?: Profile;
  items: TradeItem[];
}

export interface TradeItem {
  id: string;
  trade_id: string;
  book_id: string;
  owner_id: string;
  recipient_id: string;
  created_at: string;
  interest_id?: string;
  item_type: 'book';
  book?: Book;
  owner?: Profile;
  recipient?: Profile;
}

export interface TradeHistory {
  id: string;
  trade_id: string;
  action: 'created' | 'accepted' | 'rejected' | 'completed' | 'cancelled' | 'counteroffered' | 'updated';
  actor_id: string;
  details?: string;
  created_at: string;
  actor?: Profile;
}

export interface Conversation {
  id: string;
  created_at: string;
  updated_at: string;
  last_message?: string;
  last_message_at?: string;
  unread_count?: number;
  participants: ConversationParticipant[];
  other_user?: Profile;
}

export interface ConversationParticipant {
  user_id: string;
  conversation_id: string;
  created_at: string;
  user?: Profile;
}

export interface Message {
  id: string;
  conversation_id: string;
  user_id: string;
  content: string;
  created_at: string;
  updated_at?: string;
  user?: Profile;
  related_book_id?: string;
  related_book?: Book;
}

// Blog post type
export type BlogPost = {
  id: string;
  title: string;
  slug: string;
  summary: string;
  content: string;
  featured_image_url?: string;
  author: string;
  author_id?: string;
  published_at: string;
  created_at: string;
  updated_at: string;
};

// Location data types
export type LocationData = {
  postalCode: string;
  formattedAddress: string;
  lat?: number;
  lng?: number;
};

// API response types for Open Library API
export type OpenLibraryBook = {
  key?: string;
  title: string;
  authors?: { name: string }[];
  author_name?: string[];
  covers?: number[];
  cover_i?: number;
  isbn_13?: string[];
  isbn_10?: string[];
  isbn?: string[];
  description?: string | { value: string };
  publish_date?: string;
};

export type OpenLibraryResponse = {
  numFound: number;
  start: number;
  docs: OpenLibraryBook[];
}; 