import { useEffect, useRef, useLayoutEffect } from 'react';
import MessageItem from './MessageItem';
import { formatDateCETForGrouping, formatGroupDateCET } from '@/lib/dateUtils';

/**
 * MessageList component displays all messages in a conversation
 * @param {Object} props
 * @param {string} props.currentUserId - ID of the current user
 * @param {Array} props.messages - Array of message objects
 * @param {boolean} props.loading - Whether messages are loading
 * @param {Function} props.onLoadOlder - Function to load older messages
 * @param {boolean} props.hasMore - Whether there are more older messages to load
 */
const MessageList = ({ 
  currentUserId, 
  messages = [], 
  loading = false, 
  onLoadOlder, 
  hasMore
}) => {
  const messagesEndRef = useRef(null);
  const messagesContainerRef = useRef(null);

  const scrollHeightBeforePrependRef = useRef(null);
  // Tracks if the "Load Older Messages" button was clicked, and we're waiting for those messages.
  const isManuallyLoadingOlderRef = useRef(false);
  // Tracks if it's the initial set of messages being loaded for the current view (e.g., new conversation selected).
  const isInitialMessageLoadRef = useRef(true);

  useLayoutEffect(() => {
    const container = messagesContainerRef.current;
    if (!container) return;

    if (isManuallyLoadingOlderRef.current && !loading) {
      // Scenario: Finished loading older messages (triggered by button click)
      if (scrollHeightBeforePrependRef.current !== null) {
        const heightDiff = container.scrollHeight - scrollHeightBeforePrependRef.current;
        if (heightDiff > 0) { // Ensure scrollHeight actually increased
          container.scrollTop += heightDiff; // Adjust scroll to maintain position
        }
      }
      isManuallyLoadingOlderRef.current = false; // Reset flag
      scrollHeightBeforePrependRef.current = null; // Reset stored height
    } else if (isInitialMessageLoadRef.current && messages.length > 0 && !loading) {
      // Scenario: Initial messages for a conversation have loaded
      // messagesEndRef.current?.scrollIntoView({ behavior: 'auto' }); // Removed to prevent auto-scroll to bottom
      isInitialMessageLoadRef.current = false; // No longer the initial load for this message set
    } else if (!isManuallyLoadingOlderRef.current && !isInitialMessageLoadRef.current && !loading && messages.length > 0) {
      // Scenario: A new message was appended (e.g., real-time update or sent by current user)
      // Only scroll to bottom if the user is already near the bottom.
      const isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 200;
      if (isNearBottom) {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
      }
    }
  }, [messages, loading]); // Rerun when messages array or loading state changes

  // Effect to reset flags when the conversation changes (indicated by messages becoming empty)
  useEffect(() => {
    if (messages.length === 0) {
      isInitialMessageLoadRef.current = true; // Next load will be "initial"
      isManuallyLoadingOlderRef.current = false; // Reset
      scrollHeightBeforePrependRef.current = null; // Reset
    }
  }, [messages]);

  // Group messages by date using CET formatter
  const groupMessagesByDate = () => {
    const groups = {};
    
    messages.forEach(message => {
      const dateString = formatDateCETForGrouping(message.created_at);
      if (!groups[dateString]) {
        groups[dateString] = [];
      }
      groups[dateString].push(message);
    });
    
    // Ensure groups are sorted chronologically by date string
    const sortedGroupKeys = Object.keys(groups).sort((a, b) => {
      // Convert formatted date string back to Date for sorting (or sort based on first message time)
      // This is a bit inefficient, ideally sort keys before grouping if dates aren't naturally ordered
      return new Date(messages.find(m => formatDateCETForGrouping(m.created_at) === a).created_at) - 
             new Date(messages.find(m => formatDateCETForGrouping(m.created_at) === b).created_at);
    });

    const sortedGroups = {};
    sortedGroupKeys.forEach(key => {
      sortedGroups[key] = groups[key];
    });

    return sortedGroups;
  };

  const messageGroups = groupMessagesByDate();

  const handleLoadOlderClick = () => {
    const container = messagesContainerRef.current;
    if (container && messages.length > 0) { // Only store if there's content to measure against
      scrollHeightBeforePrependRef.current = container.scrollHeight;
    }
    isManuallyLoadingOlderRef.current = true; // Set flag indicating we're loading older messages
    onLoadOlder(); // Call the original function passed via props
  };

  return (
    <div ref={messagesContainerRef} className="flex-1 p-4 overflow-y-auto bg-white space-y-2 relative">
      {/* Button to load older messages */}
      <div className="flex justify-center sticky top-2 z-10 py-1">
        {hasMore && (
          <button
            onClick={handleLoadOlderClick}
            disabled={loading}
            className="text-xs bg-white hover:bg-gray-100 text-blue-600 font-medium rounded-full px-4 py-1.5 shadow-sm disabled:opacity-50 border border-gray-200 transition-colors duration-150"
          >
            {loading ? (
              <span className="flex items-center">
                <svg className="animate-spin -ml-1 mr-2 h-3 w-3 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Loading...
              </span>
            ) : (
              'Load Older Messages'
            )}
          </button>
        )}
      </div>

      {messages.length === 0 && !loading ? (
        <div className="flex items-center justify-center h-full text-gray-500">
          No messages yet. Start the conversation!
        </div>
      ) : (
        <>
          {Object.entries(messageGroups).map(([dateString, messagesInGroup]) => (
            <div key={dateString} className="relative py-2">
              {/* Date separator */}
              <div className="flex justify-center my-2 sticky top-12 z-10">
                <span className="text-xs bg-gray-100 text-gray-600 rounded-full px-3 py-1 shadow-sm border border-gray-200">
                  {formatGroupDateCET(dateString)}
                </span>
              </div>

              <div className="space-y-1">
                {messagesInGroup.map((message) => {
                  return (
                    <MessageItem
                      key={message.id}
                      message={message}
                      isOwnMessage={message.user_id === currentUserId}
                    />
                  );
                })}
              </div>
            </div>
          ))}
          <div ref={messagesEndRef} />
        </>
      )}
    </div>
  );
};

export default MessageList; 