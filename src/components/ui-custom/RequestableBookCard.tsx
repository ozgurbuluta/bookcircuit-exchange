import React, { useState, useEffect } from 'react';
import { Book } from '@/lib/types';
import { Card, CardContent, CardFooter, CardHeader } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { BookOpen, MapPin, User, MessageSquare, Navigation, MessageCircle, Check, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';
import { useAuth } from '@/context/AuthContext';
import { supabase } from '@/lib/supabase';
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { MessageOwnerModal } from './MessageOwnerModal';
import { RealtimeChannel } from '@supabase/supabase-js';

interface RequestableBookCardProps {
  book: Book;
  ownerName?: string;
  className?: string;
  onRequest?: () => void;
  onCancel?: () => void;
}

const RequestableBookCard: React.FC<RequestableBookCardProps> = ({ 
  book, 
  ownerName = "Owner",
  className = '',
  onRequest,
  onCancel
}) => {
  const { user } = useAuth();
  const [requesting, setRequesting] = useState(false);
  const [isRequested, setIsRequested] = useState(false);
  const [isMessageModalOpen, setIsMessageModalOpen] = useState(false);
  const [justRequestedId, setJustRequestedId] = useState<string | null>(null);
  const [existingRequestId, setExistingRequestId] = useState<string | null>(null);
  const [cancelling, setCancelling] = useState(false);
  const realtimeSubscriptionRef = React.useRef<RealtimeChannel | null>(null);

  // Setup real-time subscription for trades
  useEffect(() => {
    // Only set up subscription if we have a user and a book
    if (!user || !book.id) return;
    
    // Clean up existing subscription if any
    if (realtimeSubscriptionRef.current) {
      supabase.removeChannel(realtimeSubscriptionRef.current);
      realtimeSubscriptionRef.current = null;
    }
    
    console.log(`[RequestableBookCard] Setting up real-time subscription for book: ${book.id}`);
    
    // This channel listens for trades involving this book and the current user
    const channel = supabase
      .channel(`book_trade:${book.id}:${user.id}`) // Unique channel name for trades
      .on('postgres_changes', {
        event: '*', // All events (INSERT, UPDATE, DELETE)
        schema: 'public',
        table: 'trades',
        // Filter for trades involving this book and this user
        filter: `id=cs.{trade_items.book_id.${book.id},trade_items.requester_id.${user.id}}`, 
      }, (payload) => {
        console.log(`[RequestableBookCard] Received real-time trade event for book ${book.id}:`, payload);
        
        // Handle different event types
        if (payload.eventType === 'DELETE') {
          // Trade was deleted
          setIsRequested(false);
          setJustRequestedId(null);
        } else if (payload.eventType === 'INSERT') {
          // New trade was created
          setIsRequested(true);
          setJustRequestedId(payload.new.id);
        } else if (payload.eventType === 'UPDATE') {
          // Trade was updated (e.g., status change)
          // If status is cancelled or rejected, mark as not requested
          if (['cancelled', 'rejected'].includes(payload.new.status)) {
            setIsRequested(false);
            setJustRequestedId(null);
          } else {
            setIsRequested(true);
            setJustRequestedId(payload.new.id);
          }
        }
      })
      .subscribe((status, err) => {
        if (err) {
          console.error(`[RequestableBookCard] Subscription error for book ${book.id}:`, err);
        }
      });
    
    realtimeSubscriptionRef.current = channel;
    
    // Clean up function
    return () => {
      if (realtimeSubscriptionRef.current) {
        console.log(`[RequestableBookCard] Cleaning up real-time subscription for book: ${book.id}`);
        supabase.removeChannel(realtimeSubscriptionRef.current);
      }
    };
  }, [user?.id, book.id]); // Re-run if user or book changes

  // Function to check if book is already requested
  const checkIfRequested = async () => {
    if (!user || !book.id) return;
    
    // Reset IDs before check
    setJustRequestedId(null);
    setExistingRequestId(null);

    try {
      // Use the new check_book_trade_status function
      const { data: tradeStatus, error: tradeError } = await supabase.rpc('check_book_trade_status', {
        p_book_id: book.id
      });
      
      console.log('[RequestableBookCard] Trade status check response:', tradeStatus);
      
      if (tradeError) {
        console.error('[RequestableBookCard] Error checking trade status:', tradeError);
      } else if (tradeStatus && tradeStatus.has_active_request) {
        // Book is currently requested
        setIsRequested(true);
        setJustRequestedId(tradeStatus.trade_id);
        console.log('[RequestableBookCard] Found active trade request:', tradeStatus.trade_id);
        return; // No need to check book_requests
      }

      // As a fallback, check the legacy book_requests table
      const { data: legacyRequest, error: legacyError } = await supabase
        .from('book_requests')
        .select('id')
        .eq('book_id', book.id)
        .eq('requester_id', user.id)
        .maybeSingle();
      
      if (legacyError) {
        console.error('[RequestableBookCard] Error checking legacy request:', legacyError);
      } else if (legacyRequest) {
        // Legacy request exists - we should migrate it
        console.log('[RequestableBookCard] Found legacy request:', legacyRequest.id);
        // Tentatively set as requested, but confirm after migration
        setExistingRequestId(legacyRequest.id);
        
        try {
          console.log('[RequestableBookCard] Attempting migration via create_direct_request for book:', book.id);
          // Call the function which is now idempotent and handles legacy checks
          const { data: tradeId, error: migrationError } = await supabase.rpc('create_direct_request', {
            p_book_id: book.id
          });
          
          if (migrationError) {
            // Migration failed, log error and reset requested state
            console.error('[RequestableBookCard] Migration via create_direct_request failed:', migrationError);
            toast.error('Failed to update request status. Please try again.');
            setIsRequested(false); 
            setExistingRequestId(null);
          } else if (tradeId) {
            // Migration successful (or trade already existed)
            console.log('[RequestableBookCard] Migration successful/Trade exists, Trade ID:', tradeId);
            setIsRequested(true); // Confirm requested state
            setJustRequestedId(tradeId); // Set the actual trade ID
            setExistingRequestId(null); // Clear legacy ID
            
            // Attempt to clean up the legacy request (best effort)
            try {
               await supabase.rpc('cleanup_book_requests', {
                 p_book_id: book.id,
                 p_user_id: user.id
               });
               console.log('[RequestableBookCard] Legacy request cleanup attempted.');
            } catch (cleanupError) {
               console.warn('[RequestableBookCard] Legacy request cleanup failed:', cleanupError);
            }
          } else {
             // RPC succeeded but returned no tradeId - unexpected
             console.warn('[RequestableBookCard] Migration RPC ran but returned no trade ID.');
             setIsRequested(false); 
             setExistingRequestId(null);
          }
        } catch (migrationRpcError) {
          // Catch any error during the RPC call itself
          console.error('[RequestableBookCard] Error calling migration RPC:', migrationRpcError);
          toast.error('An error occurred while updating the request.');
          setIsRequested(false);
          setExistingRequestId(null);
        }
      } else {
        // No request exists in either system
        console.log('[RequestableBookCard] No active requests found for book:', book.id);
        setIsRequested(false);
      }
    } catch (error) {
      console.error('[RequestableBookCard] Unexpected error checking request:', error);
      setIsRequested(false);
    }
  };

  // Check if the user has already requested this book
  useEffect(() => {    
    // Reset all state on user/book change before check
    setIsRequested(false);
    setJustRequestedId(null);
    setExistingRequestId(null);
    setCancelling(false); 
    if (user && book.id) {
        checkIfRequested();
    }
  }, [book.id, user]);

  // Function to get condition color
  const getConditionColor = (condition: string) => {
    switch (condition) {
      case 'New':
        return 'bg-green-500';
      case 'Like New':
        return 'bg-emerald-500';
      case 'Good':
        return 'bg-blue-500';
      case 'Fair':
        return 'bg-yellow-500';
      case 'Poor':
        return 'bg-red-500';
      default:
        return 'bg-gray-500';
    }
  };

  // Handle request book
  const handleRequest = async () => {
    if (!user) {
      toast.error('You must be logged in to request books');
      return;
    }

    if (user.id === book.user_id) {
      toast.error('You cannot request your own book');
      return;
    }

    setRequesting(true);
    setJustRequestedId(null);
    setExistingRequestId(null);
    try {
      console.log(`[RequestableBookCard] Requesting book: ${book.id}`);
      
      // Call create_direct_request RPC instead of old requestBook function
      const { data, error } = await supabase.rpc('create_direct_request', {
        p_book_id: book.id
      });
      
      if (error) throw error;
      
      console.log('[RequestableBookCard] Book request response:', data);
      
      // If data is not null/undefined, and no error, assume success
      if (data) { 
        const tradeId = data as string; // data should be the trade_id (UUID string)
        toast.success('Book requested successfully');
        setIsRequested(true);
        setJustRequestedId(tradeId); // Store the trade ID
        
        // Clean up any legacy book_requests if they exist
        // Consider moving this to the RPC or ensuring it handles errors gracefully
        supabase.rpc('cleanup_book_requests', {
          p_book_id: book.id,
          p_user_id: user.id
        }).then(({ error: cleanupError }) => {
          if (cleanupError) console.warn('[RequestableBookCard] Legacy request cleanup failed:', cleanupError);
        });
        
        if (onRequest) onRequest(); // Consider passing tradeId if onRequest needs it
      } else {
        // This case might be hit if data is null/undefined even without an error
        toast.error('Failed to request book: No trade ID returned.');
        setIsRequested(false);
        setJustRequestedId(null);
      }
    } catch (error: any) {
      console.error('Error requesting book:', error);
      toast.error(error?.message || 'Failed to request book');
      setIsRequested(false);
      setJustRequestedId(null);
    } finally {
      setRequesting(false);
    }
  };

  // Handle cancel request
  const handleCancelRequest = async () => {
    if (!user) {
      toast.error('You must be logged in to cancel requests');
      return;
    }

    const tradeId = justRequestedId;
    if (!tradeId) {
      toast.error('No active trade found to cancel.');
      return;
    }

    setCancelling(true);
    try {
      console.log('[RequestableBookCard] Attempting to cancel trade:', tradeId);
      
      // Use the RPC function with correct parameter order (p_trade_id, p_new_status)
      const { data, error } = await supabase.rpc('update_trade_status', {
        p_trade_id: tradeId,
        p_new_status: 'cancelled'
      });

      if (error) throw error;

      console.log('[RequestableBookCard] Trade cancellation response:', data);
      
      if (data && data.success) {
        toast.success('Trade cancelled successfully');
        setIsRequested(false);
        setJustRequestedId(null);
        
        // Verify the book status after cancellation
        const { data: bookData } = await supabase
          .from('books')
          .select('status, current_trade_id')
          .eq('id', book.id)
          .single();
        
        console.log('[RequestableBookCard] Book status after cancellation:', bookData);
        
        // Check if we need to force the book to be available
        if (bookData && (bookData.status !== 'available' || bookData.current_trade_id !== null)) {
          console.log('[RequestableBookCard] Book not properly updated, applying fix...');
          await supabase.rpc('fix_book_status', {
            p_book_id: book.id
          });
        }
        
        // Wait a moment and recheck request status
        setTimeout(() => {
          checkIfRequested();
        }, 500);
        
        // If there's an onCancel callback, call it
        if (onCancel) {
          onCancel();
        }
      } else {
        toast.error(data?.message || 'Failed to cancel trade');
      }
    } catch (error: any) {
      console.error('Error cancelling trade:', error);
      toast.error(error?.message || 'Failed to cancel trade');
    } finally {
      setCancelling(false);
    }
  };

  const handleOpenMessageModal = () => {
    if (!user) {
      toast.error('You must be logged in to message book owners');
      return;
    }
    if (user.id === book.user_id) {
      toast.error('You cannot message yourself');
      return;
    }
    setIsMessageModalOpen(true);
  };

  return (
    <>
      <Card className={`h-full flex flex-col overflow-hidden hover:shadow-md transition-shadow relative ${className}`}>
        <div className="relative pt-[60%] bg-muted">
          {book.cover_img_url ? (
            <img
              src={book.cover_img_url}
              alt={book.title}
              className="absolute inset-0 w-full h-full object-contain"
              onError={(e) => {
                (e.target as HTMLImageElement).src = '/placeholder-book.png';
              }}
            />
          ) : (
            <div className="absolute inset-0 flex items-center justify-center bg-muted">
              <BookOpen className="h-16 w-16 text-muted-foreground opacity-20" />
            </div>
          )}
          <Badge 
            className={`absolute bottom-2 left-2 ${getConditionColor(book.condition)}`}
          >
            {book.condition}
          </Badge>
          
          {isRequested && (
            <Badge className="absolute top-2 right-2 bg-blue-500">
              Requested
            </Badge>
          )}
        </div>
        
        <CardHeader className="pb-2">
          <h3 className="font-semibold text-lg line-clamp-1">{book.title}</h3>
          {book.author && (
            <p className="text-sm text-muted-foreground line-clamp-1">{book.author}</p>
          )}
        </CardHeader>
        
        <CardContent className="pb-2 flex-grow">
          {book.description && (
            <p className="text-sm text-muted-foreground line-clamp-2 mb-2">
              {book.description}
            </p>
          )}
        </CardContent>
        
        <CardFooter className="pt-0 flex flex-col items-start gap-2 w-full">
          <div className="flex items-center justify-between w-full text-sm text-muted-foreground">
            <div className="flex items-center">
              <MapPin className="h-3.5 w-3.5 mr-1" />
              <span className="line-clamp-1">{book.location_text || ''}</span>
            </div>
            
            {ownerName && (
              <div className="flex items-center ml-auto">
                <User className="h-3.5 w-3.5 mr-1" />
                <span className="line-clamp-1">{ownerName}</span>
              </div>
            )}
          </div>
          
          {/* Display distance if available - using optional property access */}
          {(book as any).distance_km !== undefined && (
            <div className="flex items-center justify-start w-full text-sm">
              <Navigation className="h-3.5 w-3.5 mr-1 text-blue-500" />
              <span className="text-blue-600 font-medium">
                {(book as any).distance_km < 1 
                  ? `${Math.round((book as any).distance_meters || 0)} meters away` 
                  : `${(book as any).distance_km.toFixed(1)} km away`}
              </span>
            </div>
          )}
          
          {user && user.id !== book.user_id && (
            <div className="grid grid-cols-2 gap-2 w-full mt-1">
              {!isRequested ? (
                <Button 
                  variant="outline" 
                  size="sm" 
                  className="w-full h-9 px-2 text-xs sm:text-sm flex items-center justify-center"
                  onClick={handleRequest}
                  disabled={requesting}
                >
                  {requesting ? 'Requesting...' : 'Request Book'}
                  <MessageSquare className="ml-1 h-4 w-4 flex-shrink-0" />
                </Button>
              ) : (
                 <Button 
                  variant="destructive"
                  size="sm" 
                  className="w-full h-9 px-2 text-xs sm:text-sm flex items-center justify-center"
                  onClick={handleCancelRequest}
                  disabled={cancelling || requesting}
                >
                  {cancelling ? 'Cancelling...' : 'Cancel Request'}
                  <XCircle className="ml-1 h-4 w-4 flex-shrink-0" /> 
                </Button>
              )}
              
              <Button 
                variant="default" 
                size="sm"
                className="w-full h-9 px-2 text-xs sm:text-sm flex items-center justify-center"
                onClick={handleOpenMessageModal}
              >
                Message Owner
                <MessageCircle className="ml-1 h-4 w-4 flex-shrink-0" />
              </Button>
            </div>
          )}
          
          {user && user.id === book.user_id && (
            <Tooltip>
              <TooltipTrigger asChild>
                <div className="w-full">
                  <Button 
                    variant="outline" 
                    size="sm"
                    className="w-full mt-1 opacity-50 cursor-not-allowed"
                    disabled={true}
                  >
                    Your Book
                  </Button>
                </div>
              </TooltipTrigger>
              <TooltipContent>
                <p>You cannot request your own book</p>
              </TooltipContent>
            </Tooltip>
          )}
        </CardFooter>
      </Card>

      {book && ownerName && (
        <MessageOwnerModal
          isOpen={isMessageModalOpen}
          onClose={() => setIsMessageModalOpen(false)}
          book={book}
          ownerName={ownerName}
          onSendComplete={(conversationId) => {
            console.log('Message sent, conversation ID:', conversationId);
          }}
        />
      )}
    </>
  );
};

export default RequestableBookCard; 