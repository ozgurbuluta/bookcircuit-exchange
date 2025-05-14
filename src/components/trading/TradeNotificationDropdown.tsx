import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bell, BookPlus, Repeat, MessageCircle, Loader2, X } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/context/AuthContext';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Badge } from '@/components/ui/badge';
import { RequestResponseModal } from './RequestResponseModal';

interface TradeNotification {
  id: string;
  type: 'new_trade' | 'trade_accepted' | 'trade_rejected' | 'trade_completed' | 'direct_request' | 'interest_marked';
  title: string;
  description: string;
  trade_id?: string;
  book_id?: string;
  user_id?: string;
  user_name?: string;
  user_avatar?: string;
  book_title?: string;
  book_author?: string;
  book_cover_url?: string;
  book_condition?: string;
  created_at: string;
  read: boolean;
}

export function TradeNotificationDropdown() {
  const { user } = useAuth();
  const navigate = useNavigate();
  
  const [notifications, setNotifications] = useState<TradeNotification[]>([]);
  const [loading, setLoading] = useState(true);
  const [isOpen, setIsOpen] = useState(false);
  const [showRequestModal, setShowRequestModal] = useState(false);
  const [selectedRequest, setSelectedRequest] = useState<any>(null);
  
  // Count unread notifications
  const unreadCount = notifications.filter(n => !n.read).length;
  
  // Fetch notifications
  useEffect(() => {
    const fetchNotifications = async () => {
      if (!user) return;
      
      try {
        setLoading(true);
        
        // Call your backend function to get trade notifications
        const { data, error } = await supabase.rpc('get_user_trade_notifications', {
          p_limit: 10
        });
        
        if (error) throw error;
        
        setNotifications(data || []);
      } catch (error) {
        console.error('Error fetching notifications:', error);
      } finally {
        setLoading(false);
      }
    };
    
    if (user) {
      fetchNotifications();
      
      // Set up real-time subscription for new notifications
      const subscription = supabase
        .channel('trade_notifications')
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'user_notifications',
          filter: `user_id=eq.${user.id}`,
        }, payload => {
          // Handle new notification
          fetchNotifications();
          
          // Show a toast for the new notification
          toast.info('New notification received', {
            description: payload.new.title,
            action: {
              label: 'View',
              onClick: () => {
                setIsOpen(true);
              },
            },
          });
        })
        .subscribe();
      
      return () => {
        subscription.unsubscribe();
      };
    }
  }, [user]);
  
  // Mark notifications as read when dropdown is opened
  useEffect(() => {
    const markAsRead = async () => {
      if (!user || !isOpen || notifications.length === 0) return;
      
      const unreadIds = notifications
        .filter(n => !n.read)
        .map(n => n.id);
      
      if (unreadIds.length === 0) return;
      
      try {
        await supabase.rpc('mark_notifications_as_read', {
          p_notification_ids: unreadIds
        });
        
        // Update local state
        setNotifications(prev => 
          prev.map(n => unreadIds.includes(n.id) ? { ...n, read: true } : n)
        );
      } catch (error) {
        console.error('Error marking notifications as read:', error);
      }
    };
    
    markAsRead();
  }, [isOpen, notifications, user]);
  
  // Handle notification click
  const handleNotificationClick = (notification: TradeNotification) => {
    // Close dropdown
    setIsOpen(false);
    
    // Handle based on notification type
    if (notification.type === 'direct_request' && notification.trade_id) {
      // Format request data for the modal
      setSelectedRequest({
        trade_id: notification.trade_id,
        requester_id: notification.user_id || '',
        requester_name: notification.user_name || 'User',
        requester_avatar: notification.user_avatar,
        book_id: notification.book_id || '',
        book_title: notification.book_title || 'Book',
        book_author: notification.book_author,
        book_cover_url: notification.book_cover_url,
        book_condition: notification.book_condition || 'Unknown',
        notes: notification.description
      });
      
      // Show request response modal
      setShowRequestModal(true);
    } else if (notification.trade_id) {
      // Navigate to the trade details
      navigate(`/trades/${notification.trade_id}`);
    } else if (notification.book_id) {
      // Navigate to the book details
      navigate(`/books/${notification.book_id}`);
    } else if (notification.user_id) {
      // Navigate to chat with the user
      navigate(`/chat/${notification.user_id}`);
    }
  };
  
  // Clear all notifications
  const clearAllNotifications = async () => {
    if (!user || notifications.length === 0) return;
    
    try {
      await supabase.rpc('clear_user_notifications');
      
      setNotifications([]);
      toast.success('All notifications cleared');
    } catch (error) {
      console.error('Error clearing notifications:', error);
      toast.error('Failed to clear notifications');
    }
  };
  
  // Get notification icon based on type
  const getNotificationIcon = (type: TradeNotification['type']) => {
    switch (type) {
      case 'new_trade':
      case 'trade_accepted':
      case 'trade_rejected':
      case 'trade_completed':
        return <Repeat className="h-4 w-4" />;
      case 'direct_request':
        return <BookPlus className="h-4 w-4" />;
      case 'interest_marked':
        return <MessageCircle className="h-4 w-4" />;
      default:
        return <Bell className="h-4 w-4" />;
    }
  };
  
  // Format notification time
  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMin = Math.round(diffMs / 60000);
    const diffHours = Math.round(diffMs / 3600000);
    const diffDays = Math.round(diffMs / 86400000);
    
    if (diffMin < 60) {
      return `${diffMin}m ago`;
    } else if (diffHours < 24) {
      return `${diffHours}h ago`;
    } else if (diffDays < 7) {
      return `${diffDays}d ago`;
    } else {
      return date.toLocaleDateString();
    }
  };
  
  if (!user) return null;
  
  return (
    <>
      <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon" className="relative">
            <Bell className="h-5 w-5" />
            {unreadCount > 0 && (
              <span className="absolute top-0 right-0 h-4 w-4 rounded-full bg-destructive text-destructive-foreground text-[10px] flex items-center justify-center">
                {unreadCount}
              </span>
            )}
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-80">
          <DropdownMenuLabel className="flex items-center justify-between">
            <span>Notifications</span>
            {notifications.length > 0 && (
              <Button
                variant="ghost"
                size="sm"
                className="h-8 text-xs"
                onClick={clearAllNotifications}
              >
                <X className="h-3.5 w-3.5 mr-1" />
                Clear all
              </Button>
            )}
          </DropdownMenuLabel>
          <DropdownMenuSeparator />
          
          {loading ? (
            <div className="py-6 flex justify-center">
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          ) : notifications.length === 0 ? (
            <div className="py-6 text-center text-muted-foreground">
              No notifications
            </div>
          ) : (
            <DropdownMenuGroup className="max-h-[420px] overflow-y-auto">
              {notifications.map((notification) => (
                <DropdownMenuItem
                  key={notification.id}
                  className={cn(
                    "py-3 px-4 cursor-pointer",
                    !notification.read && "bg-muted/50"
                  )}
                  onClick={() => handleNotificationClick(notification)}
                >
                  <div className="flex gap-3">
                    <div className="flex-shrink-0 h-10 w-10 rounded-full bg-muted flex items-center justify-center">
                      {getNotificationIcon(notification.type)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium">
                        {notification.title}
                      </p>
                      <p className="text-xs text-muted-foreground line-clamp-2">
                        {notification.description}
                      </p>
                      <p className="text-xs text-muted-foreground mt-1">
                        {formatTime(notification.created_at)}
                      </p>
                    </div>
                  </div>
                </DropdownMenuItem>
              ))}
            </DropdownMenuGroup>
          )}
          
          <DropdownMenuSeparator />
          <DropdownMenuItem
            className="py-2 justify-center cursor-pointer"
            onClick={() => {
              setIsOpen(false);
              navigate('/trades');
            }}
          >
            <span className="text-sm">View all trades</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      
      {/* Request response modal */}
      {showRequestModal && selectedRequest && (
        <RequestResponseModal
          open={showRequestModal}
          onOpenChange={setShowRequestModal}
          request={selectedRequest}
        />
      )}
    </>
  );
} 