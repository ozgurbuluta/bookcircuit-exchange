import { useState } from 'react';
import { BookPlus, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/context/AuthContext';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Textarea } from '@/components/ui/textarea';
import { Book } from '@/lib/types';

interface RequestBookButtonProps {
  bookId: string;
  bookTitle: string;
  ownerId: string;
  variant?: 'default' | 'outline' | 'secondary' | 'ghost';
  size?: 'sm' | 'default' | 'lg';
  className?: string;
  fullWidth?: boolean;
  onRequestSent?: () => void;
}

export const RequestBookButton = ({ 
  bookId, 
  bookTitle,
  ownerId, 
  variant = 'default', 
  size = 'default', 
  className = '',
  fullWidth = false,
  onRequestSent
}: RequestBookButtonProps) => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [message, setMessage] = useState('');
  const [isEligible, setIsEligible] = useState<boolean | null>(null);

  const isOwnBook = user?.id === ownerId;

  const handleRequestBook = async () => {
    if (!user) {
      toast.error('You must be logged in to request books');
      return;
    }

    if (isOwnBook) {
      toast.error('You cannot request your own book');
      return;
    }

    setLoading(true);
    console.log(`[RequestBookButton] Initiating request. User ID: ${user.id}, Book ID: ${bookId}, Book Owner ID: ${ownerId}`);

    try {
      // First check if the book is available
      const { data: bookData, error: bookError } = await supabase
        .from('books')
        .select('status')
        .eq('id', bookId)
        .single();
      
      if (bookError) {
        console.error('[RequestBookButton] Error checking book status:', bookError);
        throw new Error('Could not verify book availability');
      }
      
      if (bookData.status !== 'available') {
        throw new Error(`Book is not available (current status: ${bookData.status})`);
      }
      
      // Proceed with creating the request
      console.log(`[RequestBookButton] Calling RPC 'create_direct_request' with params:`, { 
        p_book_id: bookId
        // p_initiator_id is inferred from auth.uid() in the SQL function
        // p_recipient_id is derived from p_book_id in the SQL function
        // p_note is optional and defaults to NULL in the SQL function
      });
      const { data, error } = await supabase.rpc('create_direct_request', {
        p_book_id: bookId
        // Removed p_recipient_id as it's not in the SQL function signature from 10_fix_trade_history_columns.sql
        // p_note: message.trim() || null, // If a message/note feature is to be used, uncomment and implement UI
      });

      console.log(`[RequestBookButton] RPC Response - Data: ${JSON.stringify(data)}, Error: ${JSON.stringify(error)}`);

      if (error) {
        console.error('[RequestBookButton] Error creating direct request:', error);
        toast.error(error.message || 'Failed to request book');
      } else if (data) {
        const tradeId = data as string;
        toast.success('Book requested successfully!');
        setIsDialogOpen(false);
        
        if (onRequestSent) {
          onRequestSent();
        }
        
        navigate(`/trades/${tradeId}`);
      } else {
        toast.error('An unknown error occurred: No trade ID returned.');
      }
    } catch (error: any) {
      console.error('[RequestBookButton] Exception during request book:', error);
      toast.error(error.message || 'An unexpected error occurred.');
    } finally {
      setLoading(false);
    }
  };

  if (!user || isOwnBook) {
    return null;
  }

  return (
    <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
      <DialogTrigger asChild>
        <Button
          variant={variant}
          size={size}
          className={`${className} ${fullWidth ? 'w-full' : ''}`}
        >
          <BookPlus className="h-4 w-4 mr-2" />
          Request Book
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Request "{bookTitle}"</DialogTitle>
          <DialogDescription>
            This will notify the book owner that you're interested in their book. They'll be able to respond by selecting books they want from your collection.
          </DialogDescription>
        </DialogHeader>
        
        <div className="py-4">
          <Textarea
            placeholder="Optional message to the book owner (e.g., I'd love to read this book!)"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            className="w-full min-h-[100px]"
          />
        </div>
        
        <DialogFooter>
          <Button 
            variant="outline" 
            onClick={() => setIsDialogOpen(false)}
            disabled={loading}
          >
            Cancel
          </Button>
          <Button 
            onClick={handleRequestBook}
            disabled={loading}
          >
            {loading ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
                Requesting...
              </>
            ) : (
              <>Request Book</>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}; 