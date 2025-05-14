-- Create trade_history table
CREATE TABLE IF NOT EXISTS public.trade_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id UUID REFERENCES public.trades(id) ON DELETE CASCADE NOT NULL,
  action VARCHAR(30) NOT NULL, -- created, accepted, rejected, completed, cancelled, countered, etc.
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  details JSONB, -- Additional information about the action
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS on trade_history
ALTER TABLE public.trade_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trade_history

-- Users can view history for trades they're participating in
CREATE POLICY "Users can view history for their trades"
ON public.trade_history
FOR SELECT
USING (
  trade_id IN (
    SELECT id FROM public.trades 
    WHERE initiator_id = auth.uid() OR recipient_id = auth.uid()
  )
);

-- Only system can insert trade history (through functions)
-- This will be handled by database functions that track trade actions

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS trade_history_trade_id_idx ON public.trade_history(trade_id);
CREATE INDEX IF NOT EXISTS trade_history_actor_id_idx ON public.trade_history(actor_id);
CREATE INDEX IF NOT EXISTS trade_history_action_idx ON public.trade_history(action);
CREATE INDEX IF NOT EXISTS trade_history_created_at_idx ON public.trade_history(created_at); 