import { useState, useEffect, useCallback } from 'react';
import {
  getUserConversations,
  getMessages,
  sendMessage,
  markConversationAsRead,
  subscribeToMessages,
  getOrCreateConversation,
} from '@/lib/conversationService';
import ConversationList from './ConversationList';
import ChatHeader from './ChatHeader';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import { MessageCircle } from 'lucide-react';

const INITIAL_MESSAGES_PER_PAGE = 50;

/**
 * Main container for the chat feature
 * @param {Object} props
 * @param {string} props.userId - The current user's ID
 * @param {string} props.selectedConversationId - Optional ID of a specific conversation to load
 */
const ChatContainer = ({ userId, selectedConversationId }) => {
  const [conversations, setConversations] = useState([]);
  const [selectedConversation, setSelectedConversation] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [messageLoading, setMessageLoading] = useState(false);

  // Fetch conversations
  useEffect(() => {
    const fetchConversations = async () => {
      if (!userId) return;
      setLoading(true);
      try {
        const convos = await getUserConversations();

        // Transform to match expected format
        const enhancedConversations = convos.map(convo => ({
          id: convo.id,
          created_at: convo.created_at,
          last_message: convo.last_message,
          last_message_at: convo.last_message_at,
          name: convo.other_user?.full_name || 'Unknown User',
          avatar: convo.other_user?.avatar_url || null,
          unreadCount: convo.unread_count || 0,
          book_id: convo.book_id,
        }));

        setConversations(enhancedConversations);

        if (selectedConversationId) {
          const conversation = enhancedConversations.find(c => c.id === selectedConversationId);
          if (conversation) setSelectedConversation(conversation);
        } else if (!selectedConversation && enhancedConversations.length > 0) {
          setSelectedConversation(enhancedConversations[0]);
        }
      } catch (error) {
        console.error('[ChatContainer] Error fetching conversations:', error);
        setConversations([]);
      } finally {
        setLoading(false);
      }
    };

    if (userId) fetchConversations();
  }, [userId, selectedConversationId]);

  // Fetch messages and subscribe to updates
  useEffect(() => {
    if (!selectedConversation) return;

    setMessageLoading(true);

    // Subscribe to real-time messages
    const unsubscribe = subscribeToMessages(selectedConversation.id, (newMessages) => {
      setMessages(newMessages);
      setMessageLoading(false);
    });

    // Mark as read
    markConversationAsRead(selectedConversation.id);

    return () => unsubscribe();
  }, [selectedConversation?.id]);

  const handleSelectConversation = async (conversation) => {
    if (selectedConversation?.id !== conversation.id) {
      setSelectedConversation(conversation);
    }
    if (conversation.unreadCount > 0) {
      setConversations(prevConversations =>
        prevConversations.map(convo =>
          convo.id === conversation.id ? { ...convo, unreadCount: 0 } : convo
        )
      );
    }
  };

  const handleSendMessage = async (messageContent) => {
    if (!selectedConversation || !messageContent.trim() || !userId) return;

    try {
      const result = await sendMessage(selectedConversation.id, messageContent.trim());

      if (result.success) {
        // Update local conversation list
        setConversations(prevConversations => {
          const updatedConversationIndex = prevConversations.findIndex(c => c.id === selectedConversation.id);
          if (updatedConversationIndex === -1) return prevConversations;

          const updatedConversation = {
            ...prevConversations[updatedConversationIndex],
            last_message: messageContent.trim(),
            last_message_at: new Date().toISOString(),
          };
          const otherConversations = prevConversations.filter(c => c.id !== selectedConversation.id);
          return [updatedConversation, ...otherConversations];
        });
      }
    } catch (error) {
      console.error('Error sending message:', error);
    }
  };

  const startNewConversation = async (otherUserId, initialMessage = null, bookId = null) => {
    try {
      const result = await getOrCreateConversation(otherUserId, bookId);

      if (result.success && result.conversationId) {
        // Send initial message if provided
        if (initialMessage) {
          await sendMessage(result.conversationId, initialMessage);
        }

        // Refresh conversations
        const convos = await getUserConversations();
        const enhancedConversations = convos.map(convo => ({
          id: convo.id,
          created_at: convo.created_at,
          last_message: convo.last_message,
          last_message_at: convo.last_message_at,
          name: convo.other_user?.full_name || 'Unknown User',
          avatar: convo.other_user?.avatar_url || null,
          unreadCount: convo.unread_count || 0,
        }));

        setConversations(enhancedConversations);
        const newConvo = enhancedConversations.find(c => c.id === result.conversationId);
        if (newConvo) setSelectedConversation(newConvo);
      }
    } catch (error) {
      console.error('Error starting conversation:', error);
    }
  };

  if (loading) {
    return <div className="flex items-center justify-center h-[70vh]"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div></div>;
  }

  return (
    <div className="flex h-[calc(100vh-140px)] border border-gray-200 rounded-lg overflow-hidden bg-gray-50">
      <div className="w-1/3 border-r border-gray-200 overflow-y-auto bg-white">
        <ConversationList
          conversations={conversations}
          selectedConversationId={selectedConversation?.id}
          onSelectConversation={handleSelectConversation}
          loading={loading}
          currentUserId={userId}
        />
      </div>
      <div className="w-2/3 flex flex-col bg-white">
        {selectedConversation ? (
          <>
            <ChatHeader conversation={selectedConversation} currentUserId={userId} />
            <MessageList
              messages={messages}
              currentUserId={userId}
              loading={messageLoading}
              hasMore={false}
              onLoadOlder={() => {}}
            />
            <MessageInput onSendMessage={handleSendMessage} conversationId={selectedConversation?.id}/>
          </>
        ) : (
          <div className="flex-grow flex items-center justify-center text-gray-500">
            {loading ? (
               <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            ) : conversations.length > 0 ? (
              <span className="text-center">
                <MessageCircle className="mx-auto h-12 w-12 mb-4 opacity-50" />
                Select a conversation to start chatting.
              </span>
            ) : (
               <span className="text-center">
                <MessageCircle className="mx-auto h-12 w-12 mb-4 opacity-50" />
                No conversations yet. Start one by messaging a book owner!
              </span>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatContainer;
