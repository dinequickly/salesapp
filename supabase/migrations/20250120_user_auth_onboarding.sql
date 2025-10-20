-- Migration: User Authentication and Onboarding Setup
-- Description: Extends profiles table and creates onboarding_sessions table with RLS policies

-- =====================================================
-- 1. CREATE OR EXTEND PROFILES TABLE
-- =====================================================

-- Create profiles table if it doesn't exist (with basic auth.users relationship)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add new columns for onboarding (will skip if columns already exist)
DO $$
BEGIN
  -- Add linkedin_url column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public'
                 AND table_name = 'profiles'
                 AND column_name = 'linkedin_url') THEN
    ALTER TABLE public.profiles ADD COLUMN linkedin_url TEXT;
  END IF;

  -- Add job_description column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public'
                 AND table_name = 'profiles'
                 AND column_name = 'job_description') THEN
    ALTER TABLE public.profiles ADD COLUMN job_description TEXT;
  END IF;

  -- Add onboarding_completed column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public'
                 AND table_name = 'profiles'
                 AND column_name = 'onboarding_completed') THEN
    ALTER TABLE public.profiles ADD COLUMN onboarding_completed BOOLEAN DEFAULT false NOT NULL;
  END IF;

  -- Add voice_onboarding_completed column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public'
                 AND table_name = 'profiles'
                 AND column_name = 'voice_onboarding_completed') THEN
    ALTER TABLE public.profiles ADD COLUMN voice_onboarding_completed BOOLEAN DEFAULT false NOT NULL;
  END IF;

  -- Add voice_session_id column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'public'
                 AND table_name = 'profiles'
                 AND column_name = 'voice_session_id') THEN
    ALTER TABLE public.profiles ADD COLUMN voice_session_id TEXT;
  END IF;
END $$;

-- =====================================================
-- 2. CREATE ONBOARDING_SESSIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.onboarding_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id TEXT,
  completed BOOLEAN DEFAULT false NOT NULL,
  transcript JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,

  -- Indexes for better query performance
  CONSTRAINT onboarding_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_user_id ON public.onboarding_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_created_at ON public.onboarding_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_onboarding_completed ON public.profiles(onboarding_completed);

-- =====================================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_sessions ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4. CREATE RLS POLICIES FOR PROFILES TABLE
-- =====================================================

-- Drop existing policies if they exist (to allow re-running migration)
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;

-- Policy: Users can view their own profile
CREATE POLICY "Users can view their own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policy: Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- =====================================================
-- 5. CREATE RLS POLICIES FOR ONBOARDING_SESSIONS TABLE
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own onboarding sessions" ON public.onboarding_sessions;
DROP POLICY IF EXISTS "Users can insert their own onboarding sessions" ON public.onboarding_sessions;
DROP POLICY IF EXISTS "Users can update their own onboarding sessions" ON public.onboarding_sessions;

-- Policy: Users can view their own onboarding sessions
CREATE POLICY "Users can view their own onboarding sessions"
  ON public.onboarding_sessions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own onboarding sessions
CREATE POLICY "Users can insert their own onboarding sessions"
  ON public.onboarding_sessions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own onboarding sessions
CREATE POLICY "Users can update their own onboarding sessions"
  ON public.onboarding_sessions
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- 6. CREATE FUNCTION TO AUTO-CREATE PROFILE ON USER SIGNUP
-- =====================================================

-- Drop function if it exists
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Function to automatically create profile when new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Trigger to call the function when a new user is created
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- 7. CREATE HELPER FUNCTION TO UPDATE UPDATED_AT
-- =====================================================

-- Drop function if it exists
DROP FUNCTION IF EXISTS public.handle_updated_at() CASCADE;

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;

-- Trigger to update updated_at on profile changes
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.onboarding_sessions TO authenticated;
