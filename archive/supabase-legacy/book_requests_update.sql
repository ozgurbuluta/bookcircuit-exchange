-- Update book_requests table to link to trades
ALTER TABLE public.book_requests
ADD COLUMN IF NOT EXISTS trade_id UUID REFERENCES public.trades(id) ON DELETE SET NULL;

-- Create index on trade_id for faster joins
CREATE INDEX IF NOT EXISTS book_requests_trade_id_idx ON public.book_requests(trade_id); 