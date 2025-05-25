import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import ConversationList from './ConversationList';
import ChatHeader from './ChatHeader';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import { MessageCircle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const INITIAL_MESSAGES_PER_PAGE = 10;
const OLDER_MESSAGES_PER_PAGE = 20;

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
  const [messagePage, setMessagePage] = useState(0);
  const [hasMoreMessages, setHasMoreMessages] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchConversations = async () => {
      if (!userId) return;
      setLoading(true);
      try {
        const { data: participations, error: participationsError } = await supabase
          .from('conversation_participants')
          .select('conversation_id, last_read_at')
          .eq('user_id', userId);
        
        if (participationsError) throw participationsError;
        
        if (participations && participations.length > 0) {
          const conversationIds = participations.map(p => p.conversation_id);
          
          const { data: conversationsData, error: conversationsError } = await supabase
            .from('conversations')
            .select(`
              id, 
              created_at, 
              last_message, 
              last_message_at, 
              last_message_sender_id,
              book_id,
              conversation_participants!inner(user_id)
            `)
            .in('id', conversationIds)
            .order('last_message_at', { ascending: false });
          
          if (conversationsError) throw conversationsError;

          const { data: participantsData, error: participantsError_2 } = await supabase
            .from('conversation_participants')
            .select('user_id, conversation_id')
            .in('conversation_id', conversationIds);
          
          if (participantsError_2) throw participantsError_2;

          const user = await supabase.auth.getUser().then(res => res.data.user);
          const enhancedConversations = await Promise.all(
            conversationsData.map(async (conversation) => {
              const participationsForThisConvo = participantsData.filter(
                (p) => p.conversation_id === conversation.id
              );
              const otherParticipants = participationsForThisConvo.filter(
                (p) => p.user_id !== user.id
              );
              if (otherParticipants.length === 0) {
                return { ...conversation, name: 'Empty Chat', avatar: null, unreadCount: 0 };
              }
              const firstOtherUserId = otherParticipants[0].user_id;
              const { data: profileData, error: profileError } = await supabase
                .from('profiles')
                .select('id, avatar_url, full_name')
                .eq('id', firstOtherUserId)
                .maybeSingle();
              const { data: emailData, error: rpcError } = await supabase.rpc(
                'get_user_email',
                { user_id_input: firstOtherUserId }
              );
              const userEmail = emailData && emailData.length > 0 ? emailData[0]?.email : null;
              const participation = participations.find(p => p.conversation_id === conversation.id);
              let unreadCount = 0;
              if (participation && participation.last_read_at) {
                const lastReadDate = new Date(participation.last_read_at);
                const { count, error: unreadError } = await supabase
                  .from('messages')
                  .select('id', { count: 'exact', head: true })
                  .eq('conversation_id', conversation.id)
                  .neq('user_id', user.id)
                  .gt('created_at', lastReadDate.toISOString());
                if (!unreadError) unreadCount = count || 0;
              } else {
                const { count, error: totalError } = await supabase
                  .from('messages')
                  .select('id', { count: 'exact', head: true })
                  .eq('conversation_id', conversation.id)
                  .neq('user_id', user.id);
                if (!totalError) unreadCount = count || 0;
              }
              return {
                ...conversation,
                name: profileData?.full_name || userEmail || 'Unknown User',
                avatar: profileData?.avatar_url || null,
                unreadCount,
              };
            })
          );
          setConversations(enhancedConversations);
          if (selectedConversationId) {
            const conversation = enhancedConversations.find(c => c.id === selectedConversationId);
            if (conversation) setSelectedConversation(conversation);
          } else if (!selectedConversation && enhancedConversations.length > 0) {
            setSelectedConversation(enhancedConversations[0]);
          }
        } else {
          setConversations([]);
        }
      } catch (error) {
        console.error('[ChatContainer] Error fetching conversations:', error);
        setConversations([]);
      } finally {
        setLoading(false);
      }
    };
    if (userId) fetchConversations();
    const conversationsSubscription = supabase
        .channel('public:conversation_participants')
        .on(
          'postgres_changes', 
          { 
            event: 'INSERT', 
            schema: 'public', 
            table: 'conversation_participants',
            filter: `user_id=eq.${userId}`
          },
          (payload) => { fetchConversations(); }
        )
        .subscribe();
    return () => { supabase.removeChannel(conversationsSubscription); };
  }, [userId, selectedConversationId]);

  const fetchMessages = useCallback(async (conversationId, page, shouldPrepend = false) => {
    if (!userId || !conversationId) return;
    setMessageLoading(true);
    try {
      let actualFrom, actualTo;
      if (shouldPrepend) {
        actualFrom = INITIAL_MESSAGES_PER_PAGE + (page - 1) * OLDER_MESSAGES_PER_PAGE;
        actualTo = actualFrom + OLDER_MESSAGES_PER_PAGE - 1;
      } else {
        actualFrom = 0;
        actualTo = INITIAL_MESSAGES_PER_PAGE - 1;
      }
      const { data: messagesData, error: messagesError } = await supabase
        .from('messages')
        .select('id, content, created_at, user_id, conversation_id')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: false })
        .range(actualFrom, actualTo);

      if (messagesError) {
        console.error('Error fetching messages:', messagesError);
        setMessages(prev => shouldPrepend ? prev : []);
        setHasMoreMessages(false);
        setMessageLoading(false);
        return;
      }
      const fetchedMessages = (messagesData || []).reverse();
      setMessages(prev => shouldPrepend ? [...fetchedMessages, ...prev] : fetchedMessages);
      setHasMoreMessages(fetchedMessages.length === (shouldPrepend ? OLDER_MESSAGES_PER_PAGE : INITIAL_MESSAGES_PER_PAGE));
      if (page === 0 && !shouldPrepend) {
        await supabase
          .from('conversation_participants')
          .update({ last_read_at: new Date().toISOString() })
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
      }
    } catch (error) {
      console.error('Error in fetchMessages logic:', error);
    } finally {
      setMessageLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    if (selectedConversation) {
      setMessagePage(0);
      setHasMoreMessages(true);
      setMessages([]);
      fetchMessages(selectedConversation.id, 0, false);
    }
  }, [selectedConversation, fetchMessages]);

  useEffect(() => {
    if (!selectedConversation) return;
    const channel = supabase
      .channel(`messages:${selectedConversation.id}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${selectedConversation.id}` }, (payload) => {
        setMessages(prev => prev.some(msg => msg.id === payload.new.id) ? prev : [...prev, payload.new]);
        if (payload.new.user_id !== userId) {
          supabase
            .from('conversation_participants')
            .update({ last_read_at: new Date().toISOString() })
            .eq('conversation_id', selectedConversation.id)
            .eq('user_id', userId);
        }
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [selectedConversation, userId]);

  const handleLoadOlderMessages = useCallback(() => {
    if (!messageLoading && hasMoreMessages && selectedConversation) {
      const nextPageForOlder = messagePage + 1;
      setMessagePage(nextPageForOlder);
      fetchMessages(selectedConversation.id, nextPageForOlder, true);
    }
  }, [messageLoading, hasMoreMessages, selectedConversation, messagePage, fetchMessages]);

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
    const messageData = { conversation_id: selectedConversation.id, user_id: userId, content: messageContent.trim() };
    try {
      const { data: insertedMessages, error } = await supabase.from('messages').insert(messageData).select();
      if (error) throw error;
      if (insertedMessages && insertedMessages.length > 0) {
        const newMessage = insertedMessages[0];
        setConversations(prevConversations => {
          const updatedConversationIndex = prevConversations.findIndex(c => c.id === selectedConversation.id);
          if (updatedConversationIndex === -1) return prevConversations;
          const updatedConversation = {
            ...prevConversations[updatedConversationIndex],
            last_message: newMessage.content,
            last_message_at: newMessage.created_at,
            last_message_sender_id: userId,
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
      const { data, error } = await supabase
        .rpc('start_conversation', { 
          other_user_id: otherUserId,
          initial_message: initialMessage,
          book_id: bookId
        });
      if (error) throw error;
      const { data: conversationData, error: conversationError } = await supabase
        .from('conversations')
        .select('*') 
        .eq('id', data)
        .single();
      if (conversationError) throw conversationError;
      setConversations(prev => [conversationData, ...prev.filter(c => c.id !== conversationData.id)]);
      setSelectedConversation(conversationData);
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
              hasMore={hasMoreMessages}
              onLoadOlder={handleLoadOlderMessages}
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