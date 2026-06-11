import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { BookOpen, Loader2, X, ArrowRight } from 'lucide-react';
import { toast } from 'sonner';
import { getUserBooks } from '@/lib/bookService';
import { updateTradeStatus } from '@/lib/tradeService';
import { Book } from '@/lib/types';
import { useAuth } from '@/context/AuthContext';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogClose,
} from "@/components/ui/dialog";
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { BookSelectList } from './BookSelectList';

interface RequestDetails {
  trade_id: string;
  requester_id: string;
  requester_name: string;
  requester_avatar?: string;
  book_id: string;
  book_title: string;
  book_author?: string;
  book_cover_url?: string;
  book_condition?: string;
  notes?: string;
}

interface RequestResponseModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  request: RequestDetails;
}

export const RequestResponseModal = ({
  open,
  onOpenChange,
  request,
}: RequestResponseModalProps) => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [loadingBooks, setLoadingBooks] = useState(false);
  const [loadingReject, setLoadingReject] = useState(false);
  const [myBooks, setMyBooks] = useState<Book[]>([]);
  const [selectedBookIds, setSelectedBookIds] = useState<string[]>([]);
  const [note, setNote] = useState('');
  const [activeTab, setActiveTab] = useState('respond');

  // Load user's available books
  useEffect(() => {
    const fetchMyBooks = async () => {
      if (!user || !open) return;

      setLoadingBooks(true);
      try {
        const books = await getUserBooks(user.uid);
        // Filter to only available books
        const availableBooks = books.filter(book => book.status === 'available');
        setMyBooks(availableBooks);
      } catch (error) {
        console.error('Error fetching books:', error);
        toast.error('Failed to load your books');
      } finally {
        setLoadingBooks(false);
      }
    };

    fetchMyBooks();
  }, [user, open]);

  const handleSendProposal = async () => {
    if (!user || selectedBookIds.length === 0) return;

    setLoading(true);
    try {
      // Accept the trade with a message
      const result = await updateTradeStatus(request.trade_id, 'accepted', note.trim() || undefined);

      if (!result.success) {
        throw new Error(result.error);
      }

      toast.success('Trade proposal sent!');
      onOpenChange(false);
      navigate('/trades');
    } catch (error: any) {
      console.error('Error sending trade proposal:', error);
      toast.error(error.message || 'Failed to send trade proposal');
    } finally {
      setLoading(false);
    }
  };

  const handleRejectRequest = async () => {
    if (!user) return;

    setLoadingReject(true);
    try {
      const result = await updateTradeStatus(request.trade_id, 'rejected', note.trim() || undefined);

      if (!result.success) {
        throw new Error(result.error);
      }

      toast.success('Request rejected');
      onOpenChange(false);
    } catch (error: any) {
      console.error('Error rejecting request:', error);
      toast.error(error.message || 'Failed to reject request');
    } finally {
      setLoadingReject(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Book Request from {request.requester_name}</DialogTitle>
          <DialogDescription>
            {request.requester_name} has requested your book.
            You can respond by selecting books you'd like in return or reject the request.
          </DialogDescription>
        </DialogHeader>

        <div className="py-4 space-y-6">
          {/* Requested book info */}
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="text-sm font-medium mb-2">Requested Book:</h3>
            <div className="flex items-start gap-3">
              <div className="flex-shrink-0 w-16 h-20 bg-background rounded overflow-hidden border">
                {request.book_cover_url ? (
                  <img
                    src={request.book_cover_url}
                    alt={request.book_title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <BookOpen className="h-8 w-8 text-muted-foreground/40" />
                  </div>
                )}
              </div>

              <div>
                <h4 className="font-medium">{request.book_title}</h4>
                {request.book_author && (
                  <p className="text-sm text-muted-foreground">
                    by {request.book_author}
                  </p>
                )}
                {request.book_condition && (
                  <Badge
                    variant="outline"
                    className="mt-1"
                  >
                    {request.book_condition}
                  </Badge>
                )}
              </div>
            </div>

            {request.notes && (
              <div className="mt-3 p-3 bg-background rounded border">
                <p className="text-sm italic">{request.notes}</p>
              </div>
            )}
          </div>

          <Tabs value={activeTab} onValueChange={setActiveTab}>
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="respond">Respond with Books</TabsTrigger>
              <TabsTrigger value="reject">Reject Request</TabsTrigger>
            </TabsList>

            <TabsContent value="respond" className="space-y-4 mt-4">
              <div>
                <h3 className="text-sm font-medium mb-2">Select Books to Offer:</h3>
                {loadingBooks ? (
                  <div className="py-8 flex justify-center">
                    <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                  </div>
                ) : (
                  <BookSelectList
                    books={myBooks}
                    selectedBookIds={selectedBookIds}
                    onSelectionChange={setSelectedBookIds}
                    emptyMessage="You don't have any available books to offer. Add some books first!"
                  />
                )}
              </div>

              <div className="mt-4">
                <h3 className="text-sm font-medium mb-2">Add a Note (Optional):</h3>
                <Textarea
                  placeholder="Add a message to the requester..."
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  className="w-full min-h-[80px]"
                />
              </div>
            </TabsContent>

            <TabsContent value="reject" className="space-y-4 mt-4">
              <div>
                <h3 className="text-sm font-medium mb-2">Rejection Reason (Optional):</h3>
                <Textarea
                  placeholder="Explain why you're rejecting this request..."
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  className="w-full min-h-[120px]"
                />
              </div>
            </TabsContent>
          </Tabs>
        </div>

        <DialogFooter className="flex justify-between items-center">
          <DialogClose asChild>
            <Button variant="outline" disabled={loading || loadingReject}>
              <X className="h-4 w-4 mr-2" />
              Cancel
            </Button>
          </DialogClose>

          {activeTab === 'respond' ? (
            <Button
              onClick={handleSendProposal}
              disabled={loading || selectedBookIds.length === 0}
            >
              {loading ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  Sending...
                </>
              ) : (
                <>
                  Send Proposal
                  <ArrowRight className="h-4 w-4 ml-2" />
                </>
              )}
            </Button>
          ) : (
            <Button
              variant="destructive"
              onClick={handleRejectRequest}
              disabled={loadingReject}
            >
              {loadingReject ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  Rejecting...
                </>
              ) : (
                <>
                  Reject Request
                  <X className="h-4 w-4 ml-2" />
                </>
              )}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
