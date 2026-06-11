import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Loader2, X, ArrowRight } from 'lucide-react';
import { toast } from 'sonner';
import { getUserBooks } from '@/lib/bookService';
import { createTrade } from '@/lib/tradeService';
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
} from '@/components/ui/dialog';
import { Textarea } from '@/components/ui/textarea';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { BookSelectList } from './BookSelectList';
import { TradeItemCard, TradeItem } from './TradeItemCard';

interface TradePartner {
  id: string;
  name: string;
  avatar_url?: string;
}

interface TradeCreationModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  partner: TradePartner;
  initialItems?: TradeItem[];
}

export function TradeCreationModal({
  open,
  onOpenChange,
  partner,
  initialItems = [],
}: TradeCreationModalProps) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [loadingMyBooks, setLoadingMyBooks] = useState(false);
  const [loadingPartnerBooks, setLoadingPartnerBooks] = useState(false);
  const [myBooks, setMyBooks] = useState<Book[]>([]);
  const [partnerBooks, setPartnerBooks] = useState<TradeItem[]>([]);
  const [selectedMyBookIds, setSelectedMyBookIds] = useState<string[]>([]);
  const [selectedPartnerBookIds, setSelectedPartnerBookIds] = useState<string[]>(
    initialItems.map(item => item.book_id)
  );
  const [message, setMessage] = useState('');
  const [activeTab, setActiveTab] = useState('myBooks');

  // Load user's available books
  useEffect(() => {
    if (!user || !open) return;

    const fetchMyBooks = async () => {
      setLoadingMyBooks(true);
      try {
        const books = await getUserBooks(user.uid);
        // Filter to only available books
        const availableBooks = books.filter(book => book.status === 'available');
        setMyBooks(availableBooks);
      } catch (error) {
        console.error('Error fetching user books:', error);
        toast.error('Failed to load your books');
      } finally {
        setLoadingMyBooks(false);
      }
    };

    fetchMyBooks();
  }, [user, open]);

  // Load partner's available books
  useEffect(() => {
    if (!partner.id || !open) return;

    const fetchPartnerBooks = async () => {
      setLoadingPartnerBooks(true);
      try {
        const books = await getUserBooks(partner.id);
        // Filter to only available books
        const availableBooks = books.filter(book => book.status === 'available');

        // Convert Book[] to TradeItem[]
        const tradeItems: TradeItem[] = availableBooks.map(book => ({
          id: book.id,
          book_id: book.id,
          title: book.title,
          author: book.author,
          cover_url: book.cover_img_url,
          condition: book.condition,
          owner_id: partner.id,
          owner_name: partner.name,
          item_type: 'book',
        }));

        setPartnerBooks(tradeItems);
      } catch (error) {
        console.error('Error fetching partner books:', error);
        toast.error('Failed to load their books');
      } finally {
        setLoadingPartnerBooks(false);
      }
    };

    fetchPartnerBooks();
  }, [partner.id, partner.name, open]);

  // Handle trade creation
  const handleCreateTrade = async () => {
    if (!user || selectedMyBookIds.length === 0 || selectedPartnerBookIds.length === 0) return;

    setLoading(true);
    try {
      const result = await createTrade(
        partner.id,
        selectedMyBookIds,
        selectedPartnerBookIds,
        message.trim() || undefined
      );

      if (!result.success) {
        throw new Error(result.error);
      }

      toast.success('Trade proposal created successfully!');
      onOpenChange(false);
      navigate('/trades');
    } catch (error: any) {
      console.error('Error creating trade:', error);
      toast.error(error.message || 'Failed to create trade');
    } finally {
      setLoading(false);
    }
  };

  // Check if form is valid
  const isValid = selectedMyBookIds.length > 0 && selectedPartnerBookIds.length > 0;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Create a Trade with {partner.name}</DialogTitle>
          <DialogDescription>
            Select books to offer and books you'd like in return to create a trade proposal.
          </DialogDescription>
        </DialogHeader>

        <div className="py-4">
          <Tabs value={activeTab} onValueChange={setActiveTab}>
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="myBooks">Your Offer</TabsTrigger>
              <TabsTrigger value="theirBooks">Books You Want</TabsTrigger>
            </TabsList>

            <TabsContent value="myBooks" className="space-y-4 mt-4">
              <div>
                <h3 className="text-sm font-medium mb-2">
                  Select Books to Offer ({selectedMyBookIds.length} selected):
                </h3>
                {loadingMyBooks ? (
                  <div className="py-8 flex justify-center">
                    <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                  </div>
                ) : (
                  <BookSelectList
                    books={myBooks}
                    selectedBookIds={selectedMyBookIds}
                    onSelectionChange={setSelectedMyBookIds}
                    emptyMessage="You don't have any available books to offer. Add some books first!"
                    maxHeight="350px"
                  />
                )}
              </div>
            </TabsContent>

            <TabsContent value="theirBooks" className="space-y-4 mt-4">
              <div>
                <h3 className="text-sm font-medium mb-2">
                  Select Books You Want ({selectedPartnerBookIds.length} selected):
                </h3>
                {loadingPartnerBooks ? (
                  <div className="py-8 flex justify-center">
                    <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                  </div>
                ) : (
                  <div className="max-h-[350px] overflow-y-auto">
                    {partnerBooks.length === 0 ? (
                      <div className="p-4 text-center text-muted-foreground">
                        This user doesn't have any available books.
                      </div>
                    ) : (
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        {partnerBooks.map((book) => (
                          <TradeItemCard
                            key={book.book_id}
                            item={book}
                            selected={selectedPartnerBookIds.includes(book.book_id)}
                            onClick={() => {
                              setSelectedPartnerBookIds((prev) =>
                                prev.includes(book.book_id)
                                  ? prev.filter((id) => id !== book.book_id)
                                  : [...prev, book.book_id]
                              );
                            }}
                          />
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
            </TabsContent>
          </Tabs>

          <div className="mt-6">
            <h3 className="text-sm font-medium mb-2">Add a Message (Optional):</h3>
            <Textarea
              placeholder="Add a message to explain your trade proposal..."
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              className="w-full min-h-[100px]"
            />
          </div>
        </div>

        <DialogFooter className="flex justify-between items-center">
          <DialogClose asChild>
            <Button variant="outline">
              <X className="h-4 w-4 mr-2" />
              Cancel
            </Button>
          </DialogClose>

          <Button
            onClick={handleCreateTrade}
            disabled={loading || !isValid}
          >
            {loading ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin mr-2" />
                Creating Trade...
              </>
            ) : (
              <>
                Create Trade Proposal
                <ArrowRight className="h-4 w-4 ml-2" />
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
