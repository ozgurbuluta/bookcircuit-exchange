-- Create a function that returns books with their distances
CREATE OR REPLACE FUNCTION get_books_with_distances(
  lat double precision,
  lng double precision,
  max_distance_km double precision
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  location_text TEXT,
  book_lat double precision,
  book_lng double precision,
  distance_meters double precision,
  distance_km double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    b.id,
    b.title,
    b.location_text,
    b.lat AS book_lat,
    b.lng AS book_lng,
    ST_DistanceSphere(
      ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326),
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    ) AS distance_meters,
    ST_DistanceSphere(
      ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326),
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    ) / 1000.0 AS distance_km
  FROM books b
  WHERE 
    b.lat IS NOT NULL AND 
    b.lng IS NOT NULL AND
    -- Filter by max distance in kilometers
    ST_DistanceSphere(
      ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326),
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    ) <= (max_distance_km * 1000) -- Convert km to meters
  ORDER BY distance_meters ASC;
$$;

-- Check if any books have null location but have lat/lng
CREATE OR REPLACE FUNCTION check_missing_locations()
RETURNS TABLE (
  id UUID,
  title TEXT,
  book_lat double precision,
  book_lng double precision,
  has_geography boolean
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    b.id,
    b.title,
    b.lat,
    b.lng,
    b.location IS NOT NULL AS has_geography
  FROM books b
  WHERE b.lat IS NOT NULL AND b.lng IS NOT NULL
  ORDER BY b.id;
$$;

-- Fix function to manually set geography column for all books
CREATE OR REPLACE FUNCTION fix_all_locations()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Force update the geography column for ALL books with lat/lng
  UPDATE books 
  SET location = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
  WHERE lat IS NOT NULL AND lng IS NOT NULL;
  
  -- Return a message about the number of books updated
  RAISE NOTICE 'Updated location column for all books with lat/lng values';
END;
$$;

-- Execute the fix function
SELECT fix_all_locations(); 