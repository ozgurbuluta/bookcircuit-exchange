# Supabase Setup for BookCircuit

This directory contains database migration scripts and setup instructions for the BookCircuit application.

## Database Setup

Follow these steps to set up your Supabase project for the BookCircuit application:

### 1. Create a Supabase Project

1. Go to [Supabase](https://supabase.com/) and sign in
2. Create a new project
3. Note your project URL and anon key (available in Project Settings > API)
4. Add these credentials to your `.env` file:

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

### 2. Set Up the Profiles Table

You can set up the profiles table by executing the SQL in `migrations/profiles_table.sql` in the Supabase SQL Editor.

Alternatively, follow these steps manually:

1. Go to the SQL Editor in your Supabase dashboard
2. Create the profiles table with the following schema:

```sql
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  bio TEXT,
  location TEXT,
  favorite_genre TEXT,
  website TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

3. Set up Row Level Security (RLS) to control access to the profiles table:

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can view any profile
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles
  FOR SELECT
  USING (true);

-- Users can only update their own profile
CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- Users can only insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);
```

### 3. Set Up Storage for Profile Images

1. Go to the Storage section in your Supabase dashboard
2. Create a new bucket called `avatars`
3. Set the bucket's privacy to public (or configure as needed)
4. Configure CORS if necessary (for production use)

### 4. Configure Authentication

1. Go to the Authentication section in your Supabase dashboard
2. Under Authentication > Settings, configure email confirmation options as needed
3. Set up any additional authentication providers (Google, Facebook, etc.) if desired

## Additional Tables

In the future, you may want to add tables for:

- Books (for users to add books they own)
- Trades (for tracking book exchanges)
- Messages (for communication between users)

SQL for these tables will be added to the migrations directory as they are developed.

## Local Development

During local development, you can use the Supabase CLI for local development if needed. [Learn more about the Supabase CLI](https://supabase.com/docs/guides/cli). 