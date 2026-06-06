import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { BookOpen, LogOut, CheckCircle2, UserCircle, PlusCircle, Search, MessageSquare, Heart, ShieldCheck, BookCheck, XCircle, Loader2 } from 'lucide-react';
import Navbar from '@/components/ui-custom/Navbar';
import Footer from '@/components/ui-custom/Footer';
import Button from '@/components/ui-custom/Button';
import BookCard from '@/components/ui-custom/BookCard';
import { useAuth } from '@/context/AuthContext';
import { isFirebaseConfigured } from '@/lib/firebase';
import { getUserBooks, getUserRequestedBooks, cancelBookRequest } from '@/lib/bookService';
import { getUserTrades, updateTradeStatus } from '@/lib/tradeService';
import { Book } from '@/lib/types';
import { toast } from "@/components/ui/use-toast";
import { Badge } from "@/components/ui/badge";

// Define the possible trade statuses
type ActualTradeStatus = 'request_pending' | 'pending' | 'proposed' | 'accepted' | 'rejected' | 'completed' | 'cancelled';

// Define the expected structure for requested books/trades
interface RequestedItem {
  book: Book;
  trade_id: string;
  trade_status: ActualTradeStatus;
}

const Dashboard = () => {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [firebaseConnected, setFirebaseConnected] = useState(false);
  const [connectionTested, setConnectionTested] = useState(false);
  const [books, setBooks] = useState<Book[]>([]);
  const [requestedBooks, setRequestedBooks] = useState<RequestedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [requestedLoading, setRequestedLoading] = useState(true);
  const [cancellingRequestId, setCancellingRequestId] = useState<string | null>(null);

  // Test Firebase connection
  const testConnection = async () => {
    try {
      const isConnected = isFirebaseConfigured();
      setFirebaseConnected(isConnected);

      if (!isConnected) {
        console.error('Firebase not configured');
        toast({
          title: "Configuration Issue",
          description: "Firebase is not configured. Please check your environment variables.",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error('Firebase connection error:', error);
      setFirebaseConnected(false);
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
      const userBooks = await getUserBooks(user.uid);
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
      // Fetch trades where user is initiator
      const trades = await getUserTrades();

      // Filter for trades initiated by the user in pending states
      const initiatedPendingTrades = trades.filter(trade =>
        trade.initiator_id === user.uid &&
        ['request_pending', 'pending', 'proposed'].includes(trade.status)
      );

      // Transform trades to RequestedItem structure
      const transformedItems: RequestedItem[] = initiatedPendingTrades.flatMap(trade => {
        // Get the first book from trade items that the user is requesting
        const requestedItem = trade.items?.find(item => item.owner_id !== user.uid);

        if (!requestedItem?.book) return [];

        return [{
          book: requestedItem.book,
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
    fetchBooks();
  };

  // Handle cancelling a trade request
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
      const result = await updateTradeStatus(tradeId, 'cancelled');

      if (result.success) {
        toast({
          title: "Success",
          description: "Trade cancelled successfully."
        });
        // Remove the cancelled request from the state
        setRequestedBooks(prev => prev.filter(item => item.trade_id !== tradeId));
      } else {
        toast({
          title: "Error",
          description: result.error || "Failed to cancel trade.",
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

  useEffect(() => {
    if (user) {
      fetchBooks();
      fetchRequestedBooks();
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
                <h2 className="text-2xl font-semibold">Welcome{user?.displayName ? `, ${user.displayName}` : ''}!</h2>
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
