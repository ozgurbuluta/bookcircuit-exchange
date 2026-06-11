import { useState } from 'react';
import { BookPlus, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { useNavigate } from 'react-router-dom';
import { requestBook } from '@/lib/bookService';
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

  const isOwnBook = user?.uid === ownerId;

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

    try {
      const result = await requestBook(bookId, user.uid);

      if (!result.success) {
        toast.error(result.error || 'Failed to request book');
        return;
      }

      toast.success('Book requested successfully!');
      setIsDialogOpen(false);

      if (onRequestSent) {
        onRequestSent();
      }

      // Navigate to trades page
      navigate('/trades');
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
