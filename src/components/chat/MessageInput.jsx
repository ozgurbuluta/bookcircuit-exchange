import { useState, useRef, useEffect } from 'react';
import { Send, BookOpen } from 'lucide-react';
import { getConversationById } from '@/lib/conversationService';
import { getBookById } from '@/lib/bookService';

/**
 * MessageInput component for sending new messages
 * @param {Object} props
 * @param {Function} props.onSendMessage - Function to call with new message content
 * @param {string} props.conversationId - ID of the current conversation
 */
const MessageInput = ({ onSendMessage, conversationId }) => {
  const [message, setMessage] = useState('');
  const [bookDetails, setBookDetails] = useState(null);
  const [loadingBook, setLoadingBook] = useState(false);
  const [isFirstMessage, setIsFirstMessage] = useState(false);
  const textareaRef = useRef(null);

  // Check if this is the first message in the conversation
  useEffect(() => {
    const fetchConversationDetails = async () => {
      if (!conversationId) return;

      try {
        const conversation = await getConversationById(conversationId);

        if (conversation?.book_id) {
          setLoadingBook(true);
          const book = await getBookById(conversation.book_id);

          if (book) {
            setBookDetails(book);
            // Check if no messages yet (simplified - just show template for new conversations)
            if (!conversation.last_message) {
              setIsFirstMessage(true);
              setMessage(`Hi, I'm interested in your book "${book.title}"! Is it still available?`);
            }
          }
        }
      } catch (err) {
        console.error('Error fetching conversation details:', err);
      } finally {
        setLoadingBook(false);
      }
    };

    fetchConversationDetails();
  }, [conversationId]);

  // Auto-resize the textarea based on content
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 120)}px`;
    }
  }, [message]);

  const handleKeyDown = (e) => {
    // Send message on Enter (without Shift)
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const handleChangeMessage = (e) => {
    setMessage(e.target.value);
  };

  const handleSendMessage = () => {
    const trimmedMessage = message.trim();
    if (trimmedMessage && onSendMessage) {
      onSendMessage(trimmedMessage);
      setMessage('');
      setIsFirstMessage(false);
      textareaRef.current?.focus();
    }
  };

  const useBookTemplate = () => {
    if (bookDetails) {
      setMessage(`Hi, I'm interested in your book "${bookDetails.title}"! Is it still available?`);
      textareaRef.current?.focus();
    }
  };

  return (
    <div className="p-3 border-t border-gray-200 bg-gray-100 rounded-b-lg shadow-sm">
      {/* Book template for first message */}
      {isFirstMessage && bookDetails && !loadingBook && (
        <div className="mb-3 p-3 bg-blue-50 rounded-lg border border-blue-200">
          <div className="flex items-center mb-2">
            <BookOpen className="h-4 w-4 text-blue-600 mr-2 flex-shrink-0" />
            <span className="text-sm font-medium text-blue-800">New conversation about a book</span>
          </div>

          <div className="flex items-center">
            <div className="w-10 h-12 bg-white rounded overflow-hidden mr-3 border border-gray-200 flex-shrink-0">
              {bookDetails.cover_img_url ? (
                <img
                  src={bookDetails.cover_img_url}
                  alt={bookDetails.title}
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center bg-gray-50">
                  <BookOpen className="h-5 w-5 text-gray-400" />
                </div>
              )}
            </div>

            <div className="flex-1 min-w-0">
              <h4 className="text-sm font-medium line-clamp-1 text-gray-900">{bookDetails.title}</h4>
              {bookDetails.author && (
                <p className="text-xs text-gray-500 line-clamp-1">by {bookDetails.author}</p>
              )}
            </div>

            <button
              className="ml-3 px-3 py-1 text-xs bg-white hover:bg-gray-100 text-blue-600 font-medium rounded border border-blue-300 transition-colors duration-150 flex-shrink-0"
              onClick={useBookTemplate}
            >
              Use template
            </button>
          </div>
        </div>
      )}

      <div className="flex items-end space-x-2">
        {/* Message textarea */}
        <textarea
          ref={textareaRef}
          className="flex-1 w-full border border-gray-300 bg-white rounded-lg px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500 resize-none placeholder:text-gray-400 text-sm"
          placeholder="Type a message..."
          value={message}
          onChange={handleChangeMessage}
          onKeyDown={handleKeyDown}
          rows={1}
          maxLength={2000}
        />

        {/* Send button */}
        <button
          className={`p-2 rounded-lg flex items-center justify-center transition-colors duration-150 ${
            message.trim()
              ? 'bg-accent text-white hover:bg-accent/90'
              : 'bg-gray-200 text-gray-400 cursor-not-allowed'
          }`}
          onClick={handleSendMessage}
          disabled={!message.trim()}
          aria-label="Send message"
        >
          <Send className="h-5 w-5" />
        </button>
      </div>

      {/* Character count */}
      {message.length > 1500 && (
        <div className="text-xs text-right mt-1 text-gray-400">
          {message.length}/2000
        </div>
      )}
    </div>
  );
};

export default MessageInput;
