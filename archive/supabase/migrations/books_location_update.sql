-- Add index for postal code for faster searches
CREATE INDEX IF NOT EXISTS books_postal_code_idx ON books(postal_code);

-- Update the geography column from lat/lng values (for existing records)
UPDATE books 
SET location = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
WHERE lat IS NOT NULL AND lng IS NOT NULL AND location IS NULL;

-- Create spatial index on the geography column
DROP INDEX IF EXISTS books_location_idx;
CREATE INDEX books_location_idx ON books USING GIST(location);

-- Create a function to automatically update the geography column when lat/lng change
CREATE OR REPLACE FUNCTION update_book_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to keep the geography column updated
CREATE TRIGGER update_book_location_trigger
BEFORE INSERT OR UPDATE OF lat, lng ON books
FOR EACH ROW
EXECUTE FUNCTION update_book_location();