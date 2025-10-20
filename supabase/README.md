# Supabase Database Setup

This directory contains SQL migrations for setting up user authentication and onboarding in your Swift app.

## What's Included

The migration script sets up:

### 1. Profiles Table Extensions
- `linkedin_url` (TEXT, nullable) - Optional LinkedIn profile URL
- `job_description` (TEXT, nullable) - User's job description
- `onboarding_completed` (BOOLEAN, default false) - Overall onboarding status
- `voice_onboarding_completed` (BOOLEAN, default false) - Voice onboarding status
- `voice_session_id` (TEXT, nullable) - Link to voice session

### 2. Onboarding Sessions Table
Tracks voice conversations with ElevenLabs:
- `id` (UUID) - Primary key
- `user_id` (UUID) - Foreign key to auth.users
- `conversation_id` (TEXT) - ElevenLabs conversation ID
- `completed` (BOOLEAN) - Session completion status
- `transcript` (JSONB) - Conversation transcript
- `created_at`, `completed_at` (TIMESTAMP) - Session timestamps

### 3. Row Level Security (RLS) Policies
- Users can only view, insert, and update their own profile
- Users can only access their own onboarding sessions
- Automatic profile creation on user signup

### 4. Triggers & Functions
- Auto-creates profile when user signs up
- Auto-updates `updated_at` timestamp on profile changes

## How to Apply This Migration

### Option 1: Using Supabase Dashboard (Easiest)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the contents of `migrations/20250120_user_auth_onboarding.sql`
5. Paste into the SQL editor
6. Click **Run** to execute

### Option 2: Using Supabase CLI

1. Install Supabase CLI if you haven't already:
   ```bash
   brew install supabase/tap/supabase
   ```

2. Initialize Supabase in your project (if not already done):
   ```bash
   supabase init
   ```

3. Link to your remote project:
   ```bash
   supabase link --project-ref your-project-ref
   ```

4. Copy the migration file to the supabase/migrations directory (already done!)

5. Push the migration:
   ```bash
   supabase db push
   ```

### Option 3: Manual Migration

If you prefer to run migrations manually:

```bash
supabase db reset  # Resets local database and applies all migrations
```

## Verify Installation

After running the migration, verify in your Supabase dashboard:

1. Go to **Table Editor**
2. Check that `profiles` table has the new columns
3. Check that `onboarding_sessions` table exists
4. Go to **Authentication** > **Policies** to verify RLS policies

## Testing

You can test the setup by:

1. Creating a new user via Supabase Auth
2. Checking that a profile is automatically created
3. Verifying that users can only see their own data

## Swift Integration

Your Swift app should now be able to:

1. Sign up users with email/password and full name
2. Store LinkedIn URL and job description in profiles
3. Track onboarding progress
4. Store voice session data in onboarding_sessions

Example Swift code structure needed:
- `SupabaseService.swift` - Handle auth and database operations
- `UserProfile.swift` - Model matching the profiles table
- `OnboardingSession.swift` - Model matching the onboarding_sessions table

## Environment Variables

Make sure your Swift app has these Supabase credentials:

```swift
let SUPABASE_URL = "your-project-url"
let SUPABASE_ANON_KEY = "your-anon-key"
```

## Next Steps

1. Apply the migration using one of the options above
2. Update your SupabaseService.swift to use the new schema
3. Implement the onboarding flow in your Swift app
4. Connect to ElevenLabs for voice onboarding
