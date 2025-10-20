# Supabase Setup Summary

## What's Been Created

### 1. Database Migration
**Location**: `supabase/migrations/20250120_user_auth_onboarding.sql`

This migration creates:
- Extended `profiles` table with onboarding fields
- New `onboarding_sessions` table for voice conversation tracking
- Row Level Security (RLS) policies for data protection
- Automatic triggers for profile creation and timestamps

### 2. Swift Models (Already Exist)
Your Swift models are already perfectly aligned with the database schema:

**UserProfile.swift** - Maps to `profiles` table
```swift
- id (String/UUID)
- email (String?)
- fullName (String?)
- linkedinURL (String?)
- jobDescription (String?)
- onboardingCompleted (Bool)
- voiceOnboardingCompleted (Bool)
- voiceSessionId (String?)
```

**OnboardingSession.swift** - Maps to `onboarding_sessions` table
```swift
- id (UUID)
- userId (UUID)
- conversationId (String?)
- completed (Bool)
- transcript ([TranscriptMessage]?)
- createdAt (Date?)
- completedAt (Date?)
```

**OnboardingStep.swift** - Manages onboarding flow
```swift
enum OnboardingStep {
    case account       // Email/password sign-up
    case jobRole       // Job description entry
    case linkedin      // LinkedIn URL (optional)
    case voice         // ElevenLabs voice session
    case completed     // Route to main app
}
```

### 3. SupabaseService (Already Implemented)
**Location**: `FirebaseStarterApp/SalesIntelligence/Core/Services/SupabaseService.swift`

Already includes all necessary methods:
- `signUp(email:password:fullName:)` - Create account with full name
- `updateJobDescription(_:)` - Store job role
- `updateLinkedInURL(_:)` - Store LinkedIn profile (optional)
- `ensureVoiceSession()` - Create/fetch voice onboarding session
- `completeVoiceOnboarding(conversationId:transcript:)` - Mark voice onboarding done
- Auto-manages onboarding step progression

## How to Deploy

### Step 1: Apply Database Migration

Choose one method:

#### Method A: Supabase Dashboard (Easiest)
1. Open your [Supabase Dashboard](https://app.supabase.com)
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy/paste contents from: `supabase/migrations/20250120_user_auth_onboarding.sql`
5. Click **Run**

#### Method B: Supabase CLI
```bash
# Install CLI
brew install supabase/tap/supabase

# Link your project
supabase link --project-ref YOUR_PROJECT_REF

# Push migration
supabase db push
```

### Step 2: Verify in Supabase Dashboard

1. Go to **Table Editor**
   - Check `profiles` table has new columns
   - Check `onboarding_sessions` table exists

2. Go to **Authentication** > **Policies**
   - Verify RLS is enabled
   - Check policies exist for both tables

### Step 3: Configure Swift App

Check that `Constants.swift` has your Supabase credentials:

```swift
enum Supabase {
    static let urlString = "https://YOUR_PROJECT.supabase.co"
    static let anonKey = "YOUR_ANON_KEY"
}
```

## Onboarding Flow

Your app now supports this complete flow:

1. **Account Creation** (`OnboardingStep.account`)
   - User enters email, password, full name
   - `SupabaseService.signUp()` creates auth user + profile
   - Auto-advances to next step

2. **Job Role** (`OnboardingStep.jobRole`)
   - User enters job description
   - `SupabaseService.updateJobDescription()` saves to profile
   - Auto-advances to LinkedIn

3. **LinkedIn Profile** (`OnboardingStep.linkedin`)
   - Optional LinkedIn URL entry
   - User can skip
   - `SupabaseService.updateLinkedInURL()` saves if provided
   - Auto-advances to voice onboarding

4. **Voice Onboarding** (`OnboardingStep.voice`)
   - `SupabaseService.ensureVoiceSession()` creates session record
   - Connect to ElevenLabs WebSocket with conversation ID
   - Stream audio and receive transcript
   - `SupabaseService.completeVoiceOnboarding()` marks complete
   - Auto-advances to completed

5. **Completed** (`OnboardingStep.completed`)
   - Route user to main app
   - `profile.onboardingCompleted == true`

## Security Features

### Row Level Security (RLS)
All database access is protected:
- Users can only read/write their own profile
- Users can only access their own onboarding sessions
- Automatic via JWT token in Supabase client

### Data Access
The migration includes these RLS policies:
```sql
-- Profiles
- "Users can view their own profile" (SELECT)
- "Users can update their own profile" (UPDATE)
- "Users can insert their own profile" (INSERT)

-- Onboarding Sessions
- "Users can view their own onboarding sessions" (SELECT)
- "Users can insert their own onboarding sessions" (INSERT)
- "Users can update their own onboarding sessions" (UPDATE)
```

## ElevenLabs Integration

Your voice onboarding connects to ElevenLabs:

1. Call `SupabaseService.ensureVoiceSession()` to get session ID
2. Use session ID to track the conversation
3. Connect to ElevenLabs WebSocket agent
4. Store conversation_id and transcript
5. Call `completeVoiceOnboarding()` when done

Example flow in your view controller:
```swift
// Start voice session
let session = try await SupabaseService.shared.ensureVoiceSession()

// Connect to ElevenLabs with session.id
let conversationId = await ElevenLabsService.shared.startConversation()

// When complete
try await SupabaseService.shared.completeVoiceOnboarding(
    conversationId: conversationId,
    transcript: capturedMessages
)
```

## Next Steps

1. ✅ **Deploy Migration** - Run the SQL script in Supabase
2. ✅ **Test Sign-up** - Create a test user in your app
3. ✅ **Verify Data** - Check Supabase dashboard that profile was created
4. ✅ **Test Onboarding Flow** - Complete all onboarding steps
5. ⏭️  **Test ElevenLabs** - Integrate voice session when ready

## Troubleshooting

### Profile not created after sign-up
- Check that trigger `on_auth_user_created` exists
- Verify RLS policies allow INSERT
- Check Supabase logs in dashboard

### Can't read/write profile data
- Verify user is authenticated (`SupabaseService.shared.session != nil`)
- Check RLS policies are enabled
- Ensure anon key is configured correctly

### Voice session errors
- Verify `onboarding_sessions` table exists
- Check foreign key to `auth.users` is valid
- Ensure UUID format matches between Swift and Postgres

## Support

- Supabase Docs: https://supabase.com/docs
- Swift Supabase Client: https://github.com/supabase-community/supabase-swift
- ElevenLabs API: https://elevenlabs.io/docs
