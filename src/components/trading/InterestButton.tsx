import { useState, useEffect } from 'react';
import { Heart, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { checkBookInterest, markBookInterest, removeBookInterest } from '@/lib/bookService';
import { useAuth } from '@/context/AuthContext';
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Textarea } from '@/components/ui/textarea';

interface InterestButtonProps {
  bookId: string;
  ownerId: string;
  size?: 'sm' | 'default';
  className?: string;
  onInterestMarked?: () => void;
  onInterestRemoved?: () => void;
}

export const InterestButton = ({
  bookId,
  ownerId,
  size = 'default',
  className = '',
  onInterestMarked,
  onInterestRemoved
}: InterestButtonProps) => {
  const { user } = useAuth();
  const [isInterested, setIsInterested] = useState(false);
  const [interestId, setInterestId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [note, setNote] = useState('');

  const isOwnBook = user?.uid === ownerId;

  // Check if the user has already marked interest in this book
  useEffect(() => {
    const checkInterest = async () => {
      if (!user) {
        setLoading(false);
        return;
      }

      try {
        const result = await checkBookInterest(bookId, user.uid);

        if (result.interested && result.interestId) {
          setIsInterested(true);
          setInterestId(result.interestId);
        } else {
          setIsInterested(false);
          setInterestId(null);
          setNote('');
        }
      } catch (error) {
        console.error('Error checking interest:', error);
      } finally {
        setLoading(false);
      }
    };

    if (bookId && user) {
      checkInterest();
    } else {
      setLoading(false);
    }
  }, [bookId, user]);

  const handleMarkInterest = async () => {
    if (!user) {
      toast.error('You must be logged in to mark interest in books');
      return;
    }

    if (isOwnBook) {
      toast.error('You cannot mark interest in your own book');
      return;
    }

    setActionLoading(true);
    try {
      const result = await markBookInterest(bookId, note.trim() || undefined);

      if (!result.success) {
        throw new Error(result.error);
      }

      toast.success('Interest marked successfully');
      setIsInterested(true);
      setInterestId(result.interestId || null);
      setIsDialogOpen(false);

      if (onInterestMarked) {
        onInterestMarked();
      }
    } catch (error: any) {
      console.error('Error marking interest:', error);
      toast.error(error.message || 'Failed to mark interest in book');
    } finally {
      setActionLoading(false);
    }
  };

  const handleRemoveInterest = async () => {
    if (!user || !interestId) {
      return;
    }

    setActionLoading(true);
    try {
      const result = await removeBookInterest(interestId);

      if (!result.success) {
        throw new Error(result.error);
      }

      toast.success('Interest removed successfully');
      setIsInterested(false);
      setInterestId(null);
      setNote('');

      if (onInterestRemoved) {
        onInterestRemoved();
      }
    } catch (error: any) {
      console.error('Error removing interest:', error);
      toast.error(error.message || 'Failed to remove interest in book');
    } finally {
      setActionLoading(false);
    }
  };

  // If still loading, show a spinner
  if (loading) {
    return (
      <Button
        size={size}
        variant="ghost"
        className={`relative ${className}`}
        disabled
      >
        <Loader2 className="h-4 w-4 animate-spin" />
      </Button>
    );
  }

  // If the user is not logged in or it's their own book, show a disabled button
  if (!user || isOwnBook) {
    return (
      <Button
        size={size}
        variant="ghost"
        className={`relative ${className}`}
        disabled
      >
        <Heart className="h-4 w-4" />
      </Button>
    );
  }

  // If the user is already interested, show the button to remove interest
  if (isInterested) {
    return (
      <Button
        size={size}
        variant="ghost"
        className={`relative text-red-500 hover:text-red-700 ${className}`}
        onClick={handleRemoveInterest}
        disabled={actionLoading}
      >
        {actionLoading ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          <>
            <Heart className="h-4 w-4 fill-current" />
            <span className="sr-only">Remove Interest</span>
          </>
        )}
      </Button>
    );
  }

  // Otherwise, show the button to mark interest
  return (
    <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
      <DialogTrigger asChild>
        <Button
          size={size}
          variant="ghost"
          className={`relative ${className}`}
          disabled={actionLoading}
        >
          {actionLoading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <>
              <Heart className="h-4 w-4" />
              <span className="sr-only">Mark Interest</span>
            </>
          )}
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Mark Interest in Book</DialogTitle>
          <DialogDescription>
            Let the owner know you're interested in this book. You can optionally leave a note.
          </DialogDescription>
        </DialogHeader>

        <div className="py-4">
          <Textarea
            placeholder="Optional note to the book owner (e.g., I've been looking for this title for ages!)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            className="w-full min-h-[100px]"
          />
        </div>

        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline">Cancel</Button>
          </DialogClose>
          <Button
            onClick={handleMarkInterest}
            disabled={actionLoading}
          >
            {actionLoading ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
                Saving...
              </>
            ) : (
              <>Mark Interest</>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
