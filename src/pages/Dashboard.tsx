import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { BookOpen, LogOut, CheckCircle2, UserCircle, PlusCircle, Search, MessageSquare, Heart, ShieldCheck, BookCheck, XCircle, Loader2 } from 'lucide-react';
import Navbar from '@/components/ui-custom/Navbar';
import Footer from '@/components/ui-custom/Footer';
import Button from '@/components/ui-custom/Button';
import BookCard from '@/components/ui-custom/BookCard';
import { useAuth } from '@/context/AuthContext';
import { supabase, checkSupabaseConnection } from '@/lib/supabase';
import { getUserBooks, getUserRequestedBooks, cancelBookRequest } from '@/lib/bookService';
import { Book } from '@/lib/types';
import { toast } from "@/components/ui/use-toast";
import { Badge } from "@/components/ui/badge";
import { RealtimeChannel } from '@supabase/supabase-js';

// Define the possible trade statuses based on the Trade interface in types.ts
type ActualTradeStatus = 'request_pending' | 'pending' | 'proposed' | 'accepted' | 'rejected' | 'completed' | 'cancelled';

// Define the expected structure for requested books/trades
interface RequestedItem {
  book: Book;
  trade_id: string; 
  // This status might need refinement based on actual data fetching
  trade_status: ActualTradeStatus;
}

const Dashboard = () => {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [supabaseConnected, setSupabaseConnected] = useState(false);
  const [connectionTested, setConnectionTested] = useState(false);
  const [books, setBooks] = useState<Book[]>([]);
  const [requestedBooks, setRequestedBooks] = useState<RequestedItem[]>([]); // Use local type
  const [loading, setLoading] = useState(true);
  const [requestedLoading, setRequestedLoading] = useState(true);
  const [cancellingRequestId, setCancellingRequestId] = useState<string | null>(null);
  const realtimeSubscriptionRef = React.useRef<RealtimeChannel | null>(null);

  // Test Supabase connection
  const testConnection = async () => {
    try {
      const isConnected = await checkSupabaseConnection();
      setSupabaseConnected(isConnected);
      
      if (isConnected) {
        console.log('Supabase connection successful!');
      } else {
        console.error('Supabase connection issue detected');
        toast({
          title: "Connection Issue",
          description: "Unable to connect to the database. Some features may not work correctly.",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error('Supabase connection error:', error);
      setSupabaseConnected(false);
    } finally {
      setConnectionTested(true);
    }
  };

  useEffect(() => {
    testConnection();
  }, []);

  // Fetch user's books
  const fetchBooks = async () => {
    if (!user) return;
    
    setLoading(true);
    try {
      const userBooks = await getUserBooks(user.id);
      setBooks(userBooks);
    } catch (error) {
      console.error('Error fetching books:', error);
      toast({
        title: "Error",
        description: "Failed to load your books. Please try again later.",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  // Fetch user's requested books/trades
  const fetchRequestedBooks = async () => {
    if (!user) return;
    
    setRequestedLoading(true);
    try {
      // Fetch ALL trades involving the user using the existing function
      const { data: tradesData, error: tradesError } = await supabase
        .rpc('get_user_trades', { 
          p_status_filter: null // Fetch all statuses initially
        });

      if (tradesError) throw tradesError;
      
      // Filter for trades initiated by the user and are in a pending-like state
      const initiatedPendingTrades = (tradesData || []).filter(trade => 
        trade.is_initiator && 
        ['request_pending', 'pending', 'proposed'].includes(trade.status)
      );

      // Transform the filtered trades into RequestedItem structure
      const transformedItems: RequestedItem[] = initiatedPendingTrades.flatMap(trade => {
        // Assuming requested_books contains the book the user initially requested in a direct_request
        // Or the books the user is asking for in a proposed trade.
        // We might need to adjust logic based on exact structure of requested_books/offered_books
        
        // For simplicity, let's assume the FIRST book in requested_books is the primary one for display
        // A more robust solution might be needed depending on trade complexity
        const primaryRequestedBook = trade.requested_books?.[0]; 
        
        if (!primaryRequestedBook) return []; // Skip if no requested book found (shouldn't happen for direct_request)
        
        return [{
          // Construct the Book object from the JSONB data
          book: {
            id: primaryRequestedBook.id,
            user_id: primaryRequestedBook.owner_id, // Owner is the recipient in a direct request
            title: primaryRequestedBook.title,
            author: primaryRequestedBook.author,
            condition: primaryRequestedBook.condition,
            cover_url: primaryRequestedBook.cover_img_url, // Use the correct field name from SQL function
            // Add other necessary Book fields if available in JSONB
            created_at: '', // Add placeholder or actual data if available
            updated_at: '', // Add placeholder or actual data if available
          },
          trade_id: trade.id,
          trade_status: trade.status as ActualTradeStatus, 
        }];
      });

      setRequestedBooks(transformedItems);
    } catch (error: any) {
      console.error('[Dashboard] Error fetching requested books/trades:', error);
      toast({
        title: "Error",
        description: "Failed to load your requested books/trades. " + (error?.message || ''),
        variant: "destructive"
      });
    } finally {
      setRequestedLoading(false);
    }
  };

  // Handle book deletion
  const handleBookDeleted = () => {
    // Refresh the book list
    fetchBooks();
  };

  // Handle cancelling a book request made by the user
  const handleCancelRequest = async (tradeId: string) => {
    if (!user) {
        toast({ title: "Error", description: "You must be logged in.", variant: "destructive" });
        return;
    }
    if (!tradeId) {
        toast({ title: "Error", description: "Invalid trade ID.", variant: "destructive" });
        return;
    }

    setCancellingRequestId(tradeId);
    console.log(`[Dashboard] Attempting to cancel trade with ID: ${tradeId}`);
    
    try {
      // Call the new SQL function to update the trade status
      const { data, error } = await supabase.rpc('update_trade_status', {
        p_trade_id: tradeId,
        p_new_status: 'cancelled'
      });
      
      if (error) throw error;
      
      console.log('[Dashboard] Trade cancellation response:', data);
      
      if (data && data.success) {
        toast({ 
          title: "Success", 
          description: "Trade cancelled successfully."
        });
        // Remove the cancelled request from the state
        setRequestedBooks(prev => prev.filter(item => item.trade_id !== tradeId));
        
        // Refresh the requested books list to ensure UI is in sync with database
        await fetchRequestedBooks();
      } else {
        toast({ 
          title: "Error", 
          description: data?.message || "Failed to cancel trade.", 
          variant: "destructive" 
        });
      }
    } catch (error: any) {
      console.error('[Dashboard] Error cancelling trade:', error);
      toast({ 
        title: "Error", 
        description: error?.message || "Failed to cancel trade.", 
        variant: "destructive" 
      });
    } finally {
      setCancellingRequestId(null);
    }
  };

  // Set up real-time subscription for trades involving the user
  const setupRealtimeSubscription = () => {
    if (!user) return;
    
    // Clean up any existing subscription
    if (realtimeSubscriptionRef.current) {
      supabase.removeChannel(realtimeSubscriptionRef.current);
      realtimeSubscriptionRef.current = null;
    }
    
    console.log('[Dashboard] Setting up real-time subscription for trades');
    
    // Channel name can be more generic or user-specific
    const channelName = `user-trades-${user.id}`;
    const channel = supabase.channel(channelName);

    const commonTradeFilter = `initiator_id=eq.${user.id},recipient_id=eq.${user.id}`; // Listen if user is initiator OR recipient

    channel
      .on('postgres_changes', { 
        event: 'INSERT', 
        schema: 'public',
        table: 'trades',
        // Filter: listen for inserts where the user is initiator OR recipient
        filter: commonTradeFilter 
      }, (payload) => {
        console.log('[Dashboard] Received real-time INSERT event for trades:', payload);
        // A new trade involving the user was created, refresh the list
        fetchRequestedBooks(); 
        // Consider more granular update instead of full refetch if performance becomes an issue
      })
      .on('postgres_changes', { 
        event: 'UPDATE', 
        schema: 'public', 
        table: 'trades',
        // Filter: listen for updates where the user is initiator OR recipient
        filter: commonTradeFilter 
      }, (payload) => {
        console.log('[Dashboard] Received real-time UPDATE event for trades:', payload);
        // Update the status of the modified trade in the state
        setRequestedBooks(prev => prev.map(item => {
          if (item.trade_id === payload.new.id) { 
            // If the updated trade is one we initiated and are displaying,
            // update its status.
            return { ...item, trade_status: payload.new.status as ActualTradeStatus };
          }
          return item;
        }));
        // We might also need to ADD an item here if a trade the user *received*
        // was updated (e.g., accepted) and should now appear in some list (though
        // this component focuses on *requested* books).
        // OR trigger a full refetch if state logic gets too complex:
        // fetchRequestedBooks(); 
      })      
      .on('postgres_changes', {
        event: 'DELETE', 
        schema: 'public',
        table: 'trades',
        // Filter: listen for deletes where the user is initiator OR recipient
        filter: commonTradeFilter
      }, (payload) => {
        console.log('[Dashboard] Received real-time DELETE event for trades:', payload);
        // Remove the deleted trade from state if it was being displayed
        setRequestedBooks(prev => prev.filter(item => item.trade_id !== payload.old.id)); 
      })
      .subscribe((status, err) => {
        if (err) {
          console.error('[Dashboard] Real-time subscription error:', err);
        } else {
          console.log('[Dashboard] Real-time subscription status:', status);
        }
      });
    
    realtimeSubscriptionRef.current = channel;
  };

  // Clean up subscription on unmount
  useEffect(() => {
    return () => {
      if (realtimeSubscriptionRef.current) {
        console.log('[Dashboard] Cleaning up real-time subscription');
        supabase.removeChannel(realtimeSubscriptionRef.current);
      }
    };
  }, []);

  useEffect(() => {
    // Fetch user's books when component mounts or user changes
    if (user) {
      fetchBooks();
      fetchRequestedBooks();
      setupRealtimeSubscription(); // Set up real-time updates
    }
  }, [user]);

  const handleSignOut = async () => {
    try {
      await signOut();
      navigate('/');
    } catch (error) {
      console.error('Error signing out:', error);
      toast({
        title: "Error",
        description: "Failed to sign out. Please try again.",
        variant: "destructive"
      });
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      
      <main className="flex-grow pt-28 pb-20">
        <div className="container mx-auto px-4 md:px-6">
          <div className="max-w-5xl mx-auto">
            <div className="flex justify-between items-center mb-8">
              <h1 className="text-3xl font-bold">Dashboard</h1>
              <Button 
                onClick={() => navigate('/add-book')} 
                className="flex items-center gap-2"
              >
                <PlusCircle size={18} />
                Add Book
              </Button>
            </div>

            <div className="glass-card rounded-xl p-8 shadow-lg mb-8">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-semibold">Welcome{user?.user_metadata?.full_name ? `, ${user.user_metadata.full_name}` : ''}!</h2>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="flex items-center gap-4 p-4 rounded-lg bg-white/10">
                  <div className="bg-primary/10 p-3 rounded-full">
                    <UserCircle size={24} className="text-primary" />
                  </div>
                  <div>
                    <h3 className="font-medium">Profile</h3>
                    <p className="text-sm text-muted-foreground">Manage your profile information</p>
                  </div>
                  <Button onClick={() => navigate('/profile')} variant="ghost" className="ml-auto">View</Button>
                </div>
                
                <div className="flex items-center gap-4 p-4 rounded-lg bg-white/10">
                  <div className="bg-primary/10 p-3 rounded-full">
                    <BookOpen size={24} className="text-primary" />
                  </div>
                  <div>
                    <h3 className="font-medium">My Books</h3>
                    <p className="text-sm text-muted-foreground">You have {books.length} books listed</p>
                  </div>
                  <Button onClick={() => navigate('/add-book')} variant="ghost" className="ml-auto">Add</Button>
                </div>
                
                <div className="flex items-center gap-4 p-4 rounded-lg bg-white/10">
                  <div className="bg-purple-500/10 p-3 rounded-full">
                    <MessageSquare size={24} className="text-purple-500" />
                  </div>
                  <div>
                    <h3 className="font-medium">Messages</h3>
                    <p className="text-sm text-muted-foreground">Chat with other book lovers</p>
                  </div>
                  <Button onClick={() => navigate('/chat')} variant="ghost" className="ml-auto">View</Button>
                </div>

                <div className="flex items-center gap-4 p-4 rounded-lg bg-blue-500/10">
                  <div className="bg-blue-500/10 p-3 rounded-full">
                    <BookCheck size={24} className="text-blue-500" />
                  </div>
                  <div>
                    <h3 className="font-medium">Requested Books</h3>
                    <p className="text-sm text-muted-foreground">You've requested {requestedBooks.length} books</p>
                  </div>
                  <Button onClick={() => navigate('/search')} variant="ghost" className="ml-auto">See</Button>
                </div>
                
                <div className="flex items-center gap-4 p-4 rounded-lg bg-purple-500/10">
                  <div className="bg-purple-500/10 p-3 rounded-full">
                    <Heart size={24} className="text-purple-500" />
                  </div>
                  <div>
                    <h3 className="font-medium">Blog</h3>
                    <p className="text-sm text-muted-foreground">Latest news and updates</p>
                  </div>
                  <Button onClick={() => navigate('/blog')} variant="ghost" className="ml-auto">View</Button>
                </div>
                
                {user?.user_metadata?.role === 'admin' && (
                  <div className="flex items-center gap-4 p-4 rounded-lg bg-amber-500/20">
                    <div className="bg-amber-500/20 p-3 rounded-full">
                      <ShieldCheck size={24} className="text-amber-500" />
                    </div>
                    <div>
                      <h3 className="font-medium">Admin Panel</h3>
                      <p className="text-sm text-muted-foreground">Manage users and system settings</p>
                    </div>
                    <Button onClick={() => navigate('/admin')} variant="ghost" className="ml-auto">Access</Button>
                  </div>
                )}
              </div>
              
              
            </div>
            
            {/* Books Section */}
            <div className="mb-8">
              <h2 className="text-2xl font-semibold mb-6">My Books</h2>
              
              {loading ? (
                <div className="text-center py-12">
                  <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                  <p className="mt-4 text-muted-foreground">Loading your books...</p>
                </div>
              ) : books.length > 0 ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                  {books.map(book => (
                    <BookCard 
                      key={book.id} 
                      book={book} 
                      onDelete={handleBookDeleted}
                      isReadOnly={false}
                    />
                  ))}
                </div>
              ) : (
                <div className="text-center py-12 bg-muted/30 rounded-xl">
                  <BookOpen className="mx-auto h-12 w-12 text-muted-foreground opacity-30" />
                  <h3 className="mt-4 text-xl font-medium">No books yet</h3>
                  <p className="mt-2 text-muted-foreground">
                    You haven't added any books to your collection yet.
                  </p>
                  <Button 
                    onClick={() => navigate('/add-book')} 
                    className="mt-6"
                  >
                    Add Your First Book
                  </Button>
                </div>
              )}
            </div>
            
            {/* Requested Books Section */}
            <div className="mb-8">
              <h2 className="text-2xl font-semibold mb-6">Requested Books</h2>
              
              {requestedLoading ? (
                <div className="text-center py-12">
                  <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                  <p className="mt-4 text-muted-foreground">Loading your requested books...</p>
                </div>
              ) : requestedBooks.length > 0 ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                  {requestedBooks.map(item => (
                    <div key={item.trade_id} className="flex flex-col gap-2">
                      <BookCard 
                        book={item.book} 
                        isReadOnly={true}
                      />
                      <Button 
                        variant="outline"
                        size="sm"
                        onClick={() => handleCancelRequest(item.trade_id)}
                        disabled={cancellingRequestId === item.trade_id}
                        className="w-full text-red-600 border-red-600 hover:bg-red-50 hover:text-red-700"
                      >
                        {cancellingRequestId === item.trade_id ? (
                          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        ) : (
                          <XCircle className="mr-2 h-4 w-4" />
                        )}
                        Cancel Request
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-12 bg-muted/30 rounded-xl">
                  <BookCheck className="mx-auto h-12 w-12 text-muted-foreground opacity-30" />
                  <h3 className="mt-4 text-xl font-medium">No requested books</h3>
                  <p className="mt-2 text-muted-foreground">
                    You haven't requested any books yet.
                  </p>
                  <Button 
                    onClick={() => navigate('/search')} 
                    className="mt-6"
                  >
                    Find Books to Request
                  </Button>
                </div>
              )}
            </div>
          </div>
        </div>
      </main>
      
      <Footer />
    </div>
  );
};

export default Dashboard;
