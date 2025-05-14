-- Update books table to add new columns for trading
ALTER TABLE public.books
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'available' NOT NULL,
ADD COLUMN IF NOT EXISTS current_trade_id UUID REFERENCES public.trades(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS trade_count INTEGER DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS interest_count INTEGER DEFAULT 0 NOT NULL;

-- Create index on the status field for faster queries
CREATE INDEX IF NOT EXISTS books_status_idx ON public.books(status);
CREATE INDEX IF NOT EXISTS books_current_trade_id_idx ON public.books(current_trade_id);

-- Create function to update interest count when interests are added or removed
CREATE OR REPLACE FUNCTION update_book_interest_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment the interest count
    UPDATE public.books
    SET interest_count = interest_count + 1
    WHERE id = NEW.book_id;
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement the interest count, but don't go below 0
    UPDATE public.books
    SET interest_count = GREATEST(interest_count - 1, 0)
    WHERE id = OLD.book_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to update interest count
CREATE TRIGGER increment_book_interest_count
AFTER INSERT ON public.book_interests
FOR EACH ROW
EXECUTE FUNCTION update_book_interest_count();

CREATE TRIGGER decrement_book_interest_count
AFTER DELETE ON public.book_interests
FOR EACH ROW
EXECUTE FUNCTION update_book_interest_count(); 