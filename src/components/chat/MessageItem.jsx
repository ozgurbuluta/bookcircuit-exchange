/**
 * MessageItem component displays a single message
 * @param {Object} props
 * @param {Object} props.message - The message data from Supabase
 * @param {boolean} props.isOwnMessage - Whether this message was sent by the current user
 */
import { formatTimeCET } from '@/lib/dateUtils';
import { CheckCheck } from 'lucide-react';

const MessageItem = ({ message, isOwnMessage }) => {
  return (
    <div className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'} p-1`}>
      {/* Original Message Structure */}
      <div className={`flex flex-col max-w-[75%] md:max-w-[65%] ${isOwnMessage ? 'items-end' : 'items-start'} p-1 rounded-lg bg-gray-50`}>
        <div
          className={`px-2.5 py-1.5 rounded-lg shadow-sm text-sm break-words ${
            isOwnMessage
              ? 'bg-accent text-white rounded-br-none'
              : 'bg-gray-100 text-gray-800 rounded-bl-none'
          }`}
        >
          <p className="whitespace-pre-wrap">{message.content}</p>
        </div>
        <div className="flex items-center mt-0.5 text-xs text-gray-400">
          <span>{formatTimeCET(message.created_at)}</span>
          {isOwnMessage && (
            <CheckCheck className="ml-1.5 h-3.5 w-3.5 text-gray-400" />
          )}
        </div>
      </div>
    </div>
  );
};

export default MessageItem; 