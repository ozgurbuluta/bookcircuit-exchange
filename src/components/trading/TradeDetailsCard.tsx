import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Loader2, MessageCircle, CheckCircle, XCircle, RefreshCw, User, Clock } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/context/AuthContext';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { Textarea } from '@/components/ui/textarea';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { TradeItem, TradeItemCard } from './TradeItemCard';
import { TradeCreationModal } from './TradeCreationModal';

export interface TradeDetails {
  id: string;
  status: 'pending' | 'accepted' | 'rejected' | 'completed' | 'cancelled';
  created_at: string;
  updated_at: string;
  initiator_id: string;
  initiator_name: string;
  initiator_avatar?: string;
  recipient_id: string;
  recipient_name: string;
  recipient_avatar?: string;
  initiator_message?: string;
  recipient_message?: string;
  initiator_items: TradeItem[];
  recipient_items: TradeItem[];
  is_direct_request: boolean;
  is_counteroffered: boolean;
}

interface TradeDetailsCardProps {
  trade: TradeDetails;
  onStatusChange?: () => void;
  className?: string;
}

export function TradeDetailsCard({ 
  trade, 
  onStatusChange,
  className 
}: TradeDetailsCardProps) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState<string | null>(null);
  const [message, setMessage] = useState('');
  const [showCounterModal, setShowCounterModal] = useState(false);
  
  if (!user) return null;
  
  const isUserInitiator = user.id === trade.initiator_id;
  const userItems = isUserInitiator ? trade.initiator_items : trade.recipient_items;
  const otherItems = isUserInitiator ? trade.recipient_items : trade.initiator_items;
  const otherUser = isUserInitiator ? 
    { id: trade.recipient_id, name: trade.recipient_name, avatar: trade.recipient_avatar } : 
    { id: trade.initiator_id, name: trade.initiator_name, avatar: trade.initiator_avatar };
  
  const getStatusBadge = () => {
    switch (trade.status) {
      case 'pending':
        return <Badge className="text-xs">Pending</Badge>;
      case 'accepted':
        return <Badge variant="secondary" className="text-xs bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300">Accepted</Badge>;
      case 'rejected':
        return <Badge variant="destructive" className="text-xs">Rejected</Badge>;
      case 'completed':
        return <Badge variant="secondary" className="text-xs bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300">Completed</Badge>;
      case 'cancelled':
        return <Badge variant="destructive" className="text-xs">Cancelled</Badge>;
      default:
        return null;
    }
  };
  
  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };
  
  const handleAction = async (action: 'accept' | 'reject' | 'complete' | 'cancel') => {
    if (!user) return;
    
    setLoading(action);
    try {
      let result;
      
      switch (action) {
        case 'accept':
          result = await supabase.rpc('accept_trade', {
            p_trade_id: trade.id,
            p_message: message.trim() || null
          });
          break;
        case 'reject':
          result = await supabase.rpc('reject_trade', {
            p_trade_id: trade.id,
            p_reason: message.trim() || null
          });
          break;
        case 'complete':
          result = await supabase.rpc('complete_trade', {
            p_trade_id: trade.id
          });
          break;
        case 'cancel':
          result = await supabase.rpc('cancel_trade', {
            p_trade_id: trade.id,
            p_reason: message.trim() || null
          });
          break;
      }
      
      if (result.error) throw result.error;
      
      toast.success(`Trade ${action === 'accept' ? 'accepted' : action === 'reject' ? 'rejected' : action === 'complete' ? 'completed' : 'cancelled'} successfully!`);
      
      if (onStatusChange) {
        onStatusChange();
      }
    } catch (error: any) {
      console.error(`Error ${action}ing trade:`, error);
      toast.error(error.message || `Failed to ${action} trade`);
    } finally {
      setLoading(null);
    }
  };
  
  const renderStatusSpecificContent = () => {
    if (trade.status === 'pending') {
      // For the recipient of a pending trade
      if (!isUserInitiator) {
        return (
          <div className="space-y-4 mt-4">
            <Textarea
              placeholder="Add a message with your response... (optional)"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              className="w-full min-h-[80px]"
            />
            
            <div className="flex flex-wrap gap-2">
              <Button
                variant="default"
                onClick={() => handleAction('accept')}
                disabled={!!loading}
                className="flex-1 bg-green-600 hover:bg-green-700"
              >
                {loading === 'accept' ? (
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                ) : (
                  <CheckCircle className="h-4 w-4 mr-2" />
                )}
                Accept Trade
              </Button>
              
              <Button
                variant="destructive"
                onClick={() => handleAction('reject')}
                disabled={!!loading}
                className="flex-1"
              >
                {loading === 'reject' ? (
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                ) : (
                  <XCircle className="h-4 w-4 mr-2" />
                )}
                Reject
              </Button>
              
              <Button
                variant="outline"
                onClick={() => setShowCounterModal(true)}
                disabled={!!loading}
                className="flex-1"
              >
                <RefreshCw className="h-4 w-4 mr-2" />
                Counter
              </Button>
            </div>
          </div>
        );
      }
      
      // For the initiator of a pending trade
      return (
        <div className="space-y-4 mt-4">
          <Button
            variant="destructive"
            onClick={() => handleAction('cancel')}
            disabled={!!loading}
            className="w-full"
          >
            {loading === 'cancel' ? (
              <Loader2 className="h-4 w-4 animate-spin mr-2" />
            ) : (
              <XCircle className="h-4 w-4 mr-2" />
            )}
            Cancel Trade
          </Button>
        </div>
      );
    }
    
    if (trade.status === 'accepted') {
      return (
        <div className="space-y-4 mt-4">
          <Button
            variant="default"
            onClick={() => handleAction('complete')}
            disabled={!!loading}
            className="w-full bg-green-600 hover:bg-green-700"
          >
            {loading === 'complete' ? (
              <Loader2 className="h-4 w-4 animate-spin mr-2" />
            ) : (
              <CheckCircle className="h-4 w-4 mr-2" />
            )}
            Mark as Completed
          </Button>
          
          <div className="text-center text-sm text-muted-foreground mt-2">
            <Clock className="h-4 w-4 inline mr-1" />
            Please only mark as completed after you've exchanged books.
          </div>
        </div>
      );
    }
    
    return null;
  };
  
  return (
    <>
      <Card className={cn("w-full", className)}>
        <CardHeader>
          <div className="flex justify-between items-start">
            <div>
              <CardTitle>Trade with {otherUser.name}</CardTitle>
              <CardDescription>
                Created on {formatDate(trade.created_at)}
              </CardDescription>
            </div>
            <div className="flex flex-col items-end">
              {getStatusBadge()}
              {trade.is_direct_request && (
                <span className="text-xs text-muted-foreground mt-1">Direct Request</span>
              )}
              {trade.is_counteroffered && (
                <span className="text-xs text-muted-foreground mt-1">Counteroffered</span>
              )}
            </div>
          </div>
        </CardHeader>
        
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center">
              <Avatar className="h-10 w-10">
                <AvatarImage
                  src={otherUser.avatar || undefined}
                  alt={otherUser.name}
                />
                <AvatarFallback>
                  <User className="h-6 w-6" />
                </AvatarFallback>
              </Avatar>
              <div className="ml-3">
                <h3 className="text-sm font-medium">{otherUser.name}</h3>
              </div>
            </div>
            
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate(`/messages/${otherUser.id}`)}
            >
              <MessageCircle className="h-4 w-4 mr-2" />
              Message
            </Button>
          </div>
          
          <Separator />
          
          {/* Messages */}
          {(trade.initiator_message || trade.recipient_message) && (
            <div className="space-y-3">
              {trade.initiator_message && (
                <div className="bg-muted p-3 rounded-lg">
                  <div className="flex items-center mb-1">
                    <span className="text-xs font-medium">{trade.initiator_name}</span>
                    <span className="text-xs text-muted-foreground ml-2">
                      (Initiator)
                    </span>
                  </div>
                  <p className="text-sm">{trade.initiator_message}</p>
                </div>
              )}
              
              {trade.recipient_message && (
                <div className="bg-muted p-3 rounded-lg">
                  <div className="flex items-center mb-1">
                    <span className="text-xs font-medium">{trade.recipient_name}</span>
                    <span className="text-xs text-muted-foreground ml-2">
                      (Recipient)
                    </span>
                  </div>
                  <p className="text-sm">{trade.recipient_message}</p>
                </div>
              )}
            </div>
          )}
          
          <div className="space-y-3">
            <div>
              <h3 className="text-sm font-medium mb-2">Your books in this trade:</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {userItems.length > 0 ? (
                  userItems.map((item) => (
                    <TradeItemCard
                      key={item.id}
                      item={item}
                      isUser={true}
                    />
                  ))
                ) : (
                  <div className="col-span-full p-3 text-center text-muted-foreground">
                    No books selected
                  </div>
                )}
              </div>
            </div>
            
            <div>
              <h3 className="text-sm font-medium mb-2">{otherUser.name}'s books in this trade:</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {otherItems.length > 0 ? (
                  otherItems.map((item) => (
                    <TradeItemCard
                      key={item.id}
                      item={item}
                    />
                  ))
                ) : (
                  <div className="col-span-full p-3 text-center text-muted-foreground">
                    No books selected
                  </div>
                )}
              </div>
            </div>
          </div>
        </CardContent>
        
        <CardFooter>
          {renderStatusSpecificContent()}
        </CardFooter>
      </Card>
      
      {showCounterModal && (
        <TradeCreationModal
          open={showCounterModal}
          onOpenChange={setShowCounterModal}
          partner={otherUser}
          initialItems={otherItems}
        />
      )}
    </>
  );
} 