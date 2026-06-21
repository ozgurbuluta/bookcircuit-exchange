-- Create extension if not exists (only needed if not already installed)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create or update a function to search for books within a specified distance
CREATE OR REPLACE FUNCTION books_within_distance(
  lat double precision,
  lng double precision,
  distance_meters double precision
)
RETURNS SETOF books
LANGUAGE sql
STABLE
AS $$
  SELECT b.*
  FROM books b
  WHERE 
    -- Check if the book has location information
    b.location IS NOT NULL AND
    -- Use the postgis function to calculate exact distance in meters on a sphere
    ST_DistanceSphere(
      ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326),
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    ) <= distance_meters
  ORDER BY 
    -- Sort results by distance (closest first)
    ST_DistanceSphere(
      ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326),
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    );
$$;

-- Add a function to get distance between a book and a point
CREATE OR REPLACE FUNCTION get_book_distance(
  book_id UUID,
  lat double precision,
  lng double precision
)
RETURNS double precision
LANGUAGE sql
STABLE
AS $$
  SELECT 
    ST_DistanceSphere(
      ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326),
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)
    ) AS distance_meters
  FROM books b
  WHERE b.id = book_id AND b.lat IS NOT NULL AND b.lng IS NOT NULL;
$$;

-- Fix function to update existing books' location column
CREATE OR REPLACE FUNCTION update_existing_locations()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update the geography column from lat/lng values for existing records
  UPDATE books 
  SET location = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
  WHERE lat IS NOT NULL AND lng IS NOT NULL;
END;
$$;

-- Run the function to update existing locations
SELECT update_existing_locations();