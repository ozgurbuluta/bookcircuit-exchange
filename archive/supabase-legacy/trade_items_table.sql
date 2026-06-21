-- Create trade_items table
CREATE TABLE IF NOT EXISTS public.trade_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id UUID REFERENCES public.trades(id) ON DELETE CASCADE NOT NULL,
  book_id UUID REFERENCES public.books(id) ON DELETE CASCADE NOT NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  interest_id UUID REFERENCES public.book_interests(id) ON DELETE SET NULL,
  item_type VARCHAR(20) NOT NULL -- 'requested' or 'offered'
);

-- Enable RLS on trade_items
ALTER TABLE public.trade_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trade_items

-- Users can view trade items for trades they're participating in
CREATE POLICY "Users can view trade items for their trades"
ON public.trade_items
FOR SELECT
USING (
  trade_id IN (
    SELECT id FROM public.trades 
    WHERE initiator_id = auth.uid() OR recipient_id = auth.uid()
  )
);

-- Users can insert trade items only for trades they initiate
CREATE POLICY "Users can insert trade items for trades they initiate"
ON public.trade_items
FOR INSERT
WITH CHECK (
  trade_id IN (
    SELECT id FROM public.trades WHERE initiator_id = auth.uid()
  )
);

-- Users can delete trade items only for trades they initiate and that are not yet accepted
CREATE POLICY "Users can delete trade items for proposed trades they initiate"
ON public.trade_items
FOR DELETE
USING (
  trade_id IN (
    SELECT id FROM public.trades 
    WHERE initiator_id = auth.uid() AND status IN ('request_pending', 'proposed')
  )
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS trade_items_trade_id_idx ON public.trade_items(trade_id);
CREATE INDEX IF NOT EXISTS trade_items_book_id_idx ON public.trade_items(book_id);
CREATE INDEX IF NOT EXISTS trade_items_owner_id_idx ON public.trade_items(owner_id);
CREATE INDEX IF NOT EXISTS trade_items_recipient_id_idx ON public.trade_items(recipient_id);
CREATE INDEX IF NOT EXISTS trade_items_item_type_idx ON public.trade_items(item_type); 