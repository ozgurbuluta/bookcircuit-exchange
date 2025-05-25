import { useState, useEffect } from 'react';
import { BookOpen, Info, ArrowLeft } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { useAuth } from '@/context/AuthContext';

/**
 * ChatHeader component displays information about the current conversation
 * @param {Object} props
 * @param {Object} props.conversation - The current conversation data
 * @param {Function} props.onBack - Callback function to handle going back
 * @param {String} props.bookId - The ID of the book associated with the conversation
 */
const ChatHeader = ({ conversation, onBack, bookId }) => {
  const [showBookDetails, setShowBookDetails] = useState(false);
  const [bookDetails, setBookDetails] = useState(null);
  const { supabase: authSupabase } = useAuth();

  useEffect(() => {
    // Fetch associated book details if there's a book_id
    const fetchBookDetails = async () => {
      if (!conversation?.book_id) return;
      
      try {
        const { data, error } = await supabase
          .from('books')
          .select('id, title, cover_img_url')
          .eq('id', conversation.book_id)
          .single();
          
        if (error) throw error;
        setBookDetails(data);
      } catch (err) {
        console.error('Error fetching book details:', err);
      }
    };
    
    fetchBookDetails();
  }, [conversation?.book_id]);

  if (!conversation) return null;

  return (
    <div className="flex items-center p-3 border-b border-book-leather/20 bg-white shadow-sm sticky top-0 z-10">
      <button onClick={onBack} className="mr-3 md:hidden text-book-dark">
        <ArrowLeft className="h-6 w-6" />
      </button>
      
      {/* Avatar or Placeholder */}
      {conversation.avatar ? (
        <img src={conversation.avatar} alt={conversation.name} className="w-10 h-10 rounded-full mr-6 object-cover" />
      ) : (
        <div className="w-10 h-10 rounded-full bg-book-leather/20 flex items-center justify-center text-book-leather font-medium mr-6">
          {conversation.name ? conversation.name.charAt(0).toUpperCase() : '-'}
        </div>
      )}

      <div className="flex-1 min-w-0">
        <h2 className="text-lg font-semibold truncate text-book-dark">{conversation.name}</h2>
        {/* Optionally display status or other info here */}
      </div>

      {/* Book Info Button - Conditionally rendered */}
      {bookId && (
        <button onClick={() => setShowBookDetails(true)} className="ml-auto p-2 rounded-full hover:bg-book-warm-cream/50">
          <Info className="h-5 w-5 text-book-leather" />
        </button>
      )}
      
      {/* Book Details Dialog - remains the same */}
      {/* ... Dialog JSX ... */}
      
    </div>
  );
};

export default ChatHeader; 