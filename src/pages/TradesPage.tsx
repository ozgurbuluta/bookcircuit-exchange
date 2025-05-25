import { useState, useEffect, useMemo } from 'react';
import { Link, useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, RefreshCw, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/context/AuthContext';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Card } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { Skeleton } from '@/components/ui/skeleton';
import { ScrollArea } from '@/components/ui/scroll-area';
import { TradeDetails, TradeDetailsCard } from '@/components/trading/TradeDetailsCard';

export default function TradesPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const params = useParams();
  const tradeId = params.tradeId;
  
  const [activeTab, setActiveTab] = useState('all');
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [trades, setTrades] = useState<TradeDetails[]>([]);
  const [selectedTrade, setSelectedTrade] = useState<TradeDetails | null>(null);
  
  // Filter trades based on the active tab
  const filteredTrades = useMemo(() => {
    if (activeTab === 'all') {
      return trades;
    }
    if (activeTab === 'pending') {
      // Include both 'pending' and 'request_pending' in the Pending tab
      return trades.filter(t => t.status === 'pending' || t.status === 'request_pending' as any);
    }
    if (activeTab === 'accepted') {
      return trades.filter(t => t.status === 'accepted');
    }
    if (activeTab === 'completed') {
      return trades.filter(t => t.status === 'completed');
    }
    if (activeTab === 'other') {
      return trades.filter(t => !['pending', 'request_pending', 'accepted', 'completed'].includes(t.status));
    }
    return trades;
  }, [trades, activeTab]);
  
  // Fetch all trades
  const fetchTrades = async (showRefreshToast = false) => {
    if (!user) return;
    
    if (showRefreshToast) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }
    
    try {
      const { data, error } = await supabase
        .rpc('get_user_trades', { 
          p_status_filter: activeTab === 'all' ? null : activeTab
        });
      
      if (error) throw error;

      // Map the data from the RPC function to the expected TradeDetails format
      const formattedTrades: TradeDetails[] = (data || []).map(trade => ({
        id: trade.trade_id,
        status: trade.status as any,
        created_at: trade.created_at,
        updated_at: trade.updated_at,
        initiator_id: trade.initiator_id,
        initiator_name: trade.initiator_name,
        initiator_avatar: trade.initiator_avatar,
        recipient_id: trade.recipient_id,
        recipient_name: trade.recipient_name,
        recipient_avatar: trade.recipient_avatar,
        initiator_message: trade.notes,
        recipient_message: '',
        initiator_items: [], // We'll have to extract these from requested_books/offered_books
        recipient_items: [], // We'll have to extract these from requested_books/offered_books
        is_direct_request: trade.trade_type === 'direct_request',
        is_counteroffered: trade.is_counteroffer || false
      }));
      
      setTrades(formattedTrades);
      
      // If a tradeId is provided, select that trade
      if (tradeId) {
        const foundTrade = formattedTrades.find(t => t.id === tradeId);
        if (foundTrade) {
          setSelectedTrade(foundTrade);
        } else {
          // If trade not found, redirect to main trades page
          navigate('/trades');
          toast.error('Trade not found');
        }
      } else if (formattedTrades.length > 0 && !selectedTrade) {
        // Select the first trade by default
        setSelectedTrade(formattedTrades[0]);
      }
      
      if (showRefreshToast) {
        toast.success('Trades refreshed');
      }
    } catch (error: any) {
      console.error('Error fetching trades:', error);
      toast.error(error.message || 'Failed to load trades');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };
  
  // Initial load
  useEffect(() => {
    if (user) {
      fetchTrades();
    } else {
      // If no user, and ProtectedRoute somehow allowed rendering,
      // ensure we are not stuck in a loading state.
      // This case should ideally be handled by ProtectedRoute.
      setLoading(false);
    }
  }, [user]);
  
  // Handle trade selection
  const handleTradeSelect = (trade: TradeDetails) => {
    setSelectedTrade(trade);
    navigate(`/trades/${trade.id}`);
  };
  
  // Handle trade status change
  const handleTradeStatusChange = () => {
    fetchTrades(true);
  };
  
  if (!user) {
    return (
      <div className="container max-w-6xl py-8">
        <h1 className="text-2xl font-bold mb-6">Trades</h1>
        <Card className="p-8 text-center">
          <p>Please log in to view your trades.</p>
          <Button className="mt-4" onClick={() => navigate('/login')}>
            Log In
          </Button>
        </Card>
      </div>
    );
  }
  
  return (
    <div className="container max-w-6xl py-8">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-2">
          <Link to="/">
            <Button variant="ghost" size="sm">
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Home
            </Button>
          </Link>
          <h1 className="text-2xl font-bold">Trades</h1>
        </div>
        
        <Button
          variant="outline"
          size="sm"
          onClick={() => fetchTrades(true)}
          disabled={refreshing}
        >
          {refreshing ? (
            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
          ) : (
            <RefreshCw className="h-4 w-4 mr-2" />
          )}
          Refresh
        </Button>
      </div>
      
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="col-span-1">
            <Skeleton className="h-[600px] w-full" />
          </div>
          <div className="col-span-1 md:col-span-2">
            <Skeleton className="h-[600px] w-full" />
          </div>
        </div>
      ) : trades.length === 0 ? (
        <Card className="p-8 text-center">
          <h2 className="text-xl font-medium mb-2">No Trades Found</h2>
          <p className="text-muted-foreground mb-6">
            You don't have any trades yet. Start by requesting a book or creating a trade proposal.
          </p>
          <Button onClick={() => navigate('/')}>
            Browse Books
          </Button>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Trade list panel */}
          <div className="col-span-1 flex flex-col">
            <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
              <TabsList className="grid grid-cols-5 mb-2">
                <TabsTrigger value="all">All</TabsTrigger>
                <TabsTrigger value="pending">Pending</TabsTrigger>
                <TabsTrigger value="accepted">Accepted</TabsTrigger>
                <TabsTrigger value="completed">Completed</TabsTrigger>
                <TabsTrigger value="other">Other</TabsTrigger>
              </TabsList>
            </Tabs>
            
            <ScrollArea className="h-[calc(100vh-220px)] border rounded-md">
              {filteredTrades.length === 0 ? (
                <div className="p-4 text-center text-muted-foreground">
                  No trades found for this filter
                </div>
              ) : (
                <div className="p-1">
                  {filteredTrades.map((trade, index) => (
                    <div key={trade.id}>
                      <div
                        className={`p-3 hover:bg-muted cursor-pointer rounded-md ${
                          selectedTrade?.id === trade.id ? 'bg-muted' : ''
                        }`}
                        onClick={() => handleTradeSelect(trade)}
                      >
                        <div className="flex justify-between items-start">
                          <div>
                            <h3 className="font-medium">
                              {user.id === trade.initiator_id
                                ? `Trade with ${trade.recipient_name}`
                                : `Trade with ${trade.initiator_name}`}
                            </h3>
                            <p className="text-sm text-muted-foreground">
                              {new Date(trade.created_at).toLocaleDateString()}
                            </p>
                          </div>
                          
                          <div>
                            {/* Handle pending status display */}
                            {trade.status === 'pending' && (
                              <span className="text-xs inline-flex items-center rounded-full bg-yellow-100 px-2.5 py-0.5 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300">
                                Pending
                              </span>
                            )}
                            {trade.status === 'accepted' && (
                              <span className="text-xs inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-green-800 dark:bg-green-900 dark:text-green-300">
                                Accepted
                              </span>
                            )}
                            {trade.status === 'completed' && (
                              <span className="text-xs inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-green-800 dark:bg-green-900 dark:text-green-300">
                                Completed
                              </span>
                            )}
                            {trade.status === 'rejected' && (
                              <span className="text-xs inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-red-800 dark:bg-red-900 dark:text-red-300">
                                Rejected
                              </span>
                            )}
                            {trade.status === 'cancelled' && (
                              <span className="text-xs inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-red-800 dark:bg-red-900 dark:text-red-300">
                                Cancelled
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                      {index < filteredTrades.length - 1 && <Separator />}
                    </div>
                  ))}
                </div>
              )}
            </ScrollArea>
          </div>
          
          {/* Trade details panel */}
          <div className="col-span-1 md:col-span-2">
            {selectedTrade ? (
              <TradeDetailsCard
                trade={selectedTrade}
                onStatusChange={handleTradeStatusChange}
              />
            ) : (
              <Card className="p-8 text-center h-full flex flex-col justify-center">
                <p className="text-muted-foreground">
                  Select a trade to view details
                </p>
              </Card>
            )}
          </div>
        </div>
      )}
    </div>
  );
} 