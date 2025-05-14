-- Create trades table
CREATE TABLE IF NOT EXISTS public.trades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  initiator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'request_pending',  -- request_pending, proposed, accepted, completed, rejected, cancelled, countered
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  completion_method VARCHAR(20), -- in_person, mail
  meeting_location TEXT,
  meeting_time TIMESTAMPTZ,
  notes TEXT,
  trade_type VARCHAR(20) NOT NULL DEFAULT 'direct_request', -- direct_request, complete_trade
  is_counteroffer BOOLEAN DEFAULT false NOT NULL,
  original_trade_id UUID REFERENCES public.trades(id) ON DELETE SET NULL,
  last_modified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  expires_at TIMESTAMPTZ -- Optional expiration timestamp
);

-- Enable RLS on trades
ALTER TABLE public.trades ENABLE ROW LEVEL SECURITY;

-- Create trigger to update updated_at on trades
CREATE OR REPLACE FUNCTION update_trade_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_trade_updated_at
BEFORE UPDATE ON public.trades
FOR EACH ROW
EXECUTE FUNCTION update_trade_updated_at();

-- RLS Policies for trades

-- Users can view trades they're participating in
CREATE POLICY "Users can view their own trades"
ON public.trades
FOR SELECT
USING (
  initiator_id = auth.uid() OR recipient_id = auth.uid()
);

-- Users can insert trades they initiate
CREATE POLICY "Users can insert trades they initiate"
ON public.trades
FOR INSERT
WITH CHECK (
  initiator_id = auth.uid()
);

-- Users can update trades they're participating in
CREATE POLICY "Users can update trades they participate in"
ON public.trades
FOR UPDATE
USING (
  (initiator_id = auth.uid() OR recipient_id = auth.uid())
  AND (
    -- Initiator can modify if status is request_pending, proposed, or countered
    (initiator_id = auth.uid() AND status IN ('request_pending', 'proposed', 'countered'))
    OR
    -- Recipient can modify if status is request_pending, proposed, or countered
    (recipient_id = auth.uid() AND status IN ('request_pending', 'proposed', 'countered'))
    OR
    -- Both can modify accepted trades (to mark as completed or cancelled)
    status = 'accepted'
  )
);

-- Users can delete trades they create (but only if they're still in proposal stage)
CREATE POLICY "Users can delete trades they create if not yet accepted"
ON public.trades
FOR DELETE
USING (
  initiator_id = auth.uid() AND status IN ('request_pending', 'proposed')
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS trades_initiator_id_idx ON public.trades(initiator_id);
CREATE INDEX IF NOT EXISTS trades_recipient_id_idx ON public.trades(recipient_id);
CREATE INDEX IF NOT EXISTS trades_status_idx ON public.trades(status);
CREATE INDEX IF NOT EXISTS trades_created_at_idx ON public.trades(created_at);
CREATE INDEX IF NOT EXISTS trades_updated_at_idx ON public.trades(updated_at);
CREATE INDEX IF NOT EXISTS trades_original_trade_id_idx ON public.trades(original_trade_id); 