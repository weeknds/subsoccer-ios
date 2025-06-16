# Supabase Setup Instructions for SubSoccer

## Step 1: Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Sign up or log in to your account
3. Click "New Project"
4. Choose your organization
5. Enter project details:
   - **Name**: SubSoccer
   - **Database Password**: Create a strong password (save this!)
   - **Region**: Choose closest to your location
6. Click "Create new project"
7. Wait for the project to be provisioned (2-3 minutes)

## Step 2: Configure Authentication

1. In your Supabase dashboard, go to **Authentication > Settings**
2. Under "Auth Providers", ensure **Email** is enabled
3. Configure Email settings:
   - **Enable email confirmations**: OFF (for development)
   - **Enable email change confirmations**: OFF (for development)
   - **Secure email change**: OFF (for development)
4. Under "Email Templates", you can customize the magic link email if desired

## Step 3: Set up Database Schema

1. Go to **SQL Editor** in your Supabase dashboard
2. Create a new query
3. Copy and paste the entire contents of `supabase-setup.sql` 
4. Click "Run" to execute the SQL
5. Verify all tables were created by going to **Table Editor**

You should see these tables:
- teams
- players  
- matches
- player_stats
- training_sessions
- training_attendance
- training_drills

## Step 4: Get Project Credentials

1. Go to **Settings > API** in your Supabase dashboard
2. Copy these values:
   - **Project URL** (starts with https://...)
   - **anon public key** (starts with eyJ...)

## Step 5: Update iOS App Configuration

1. Open `Services/SupabaseService.swift` in Xcode
2. Replace the placeholder values:

```swift
private let supabaseUrl = "YOUR_PROJECT_URL_HERE"
private let supabaseKey = "YOUR_ANON_KEY_HERE"
```

With your actual values:

```swift
private let supabaseUrl = "https://your-project-ref.supabase.co"
private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

## Step 6: Add Supabase Swift Package

1. In Xcode, go to **File > Add Package Dependencies**
2. Enter the URL: `https://github.com/supabase/supabase-swift`
3. Choose "Up to Next Major Version" with version 2.0.0 or later
4. Click "Add Package"
5. Select **Supabase** target and click "Add Package"

## Step 7: Test Authentication

1. Build and run the app
2. Go to Settings tab
3. Tap "Sign In"
4. Enter your email address
5. Check your email for the magic link/OTP code
6. Enter the code to complete authentication
7. Verify you see "Signed In" status in Settings

## Step 8: Test Sync Functionality

1. Create a team with some players
2. In Settings, tap "Sync Now"
3. Check your Supabase dashboard **Table Editor** to verify data was synced
4. Try creating data on another device/simulator and syncing

## Security Notes

- Row Level Security (RLS) is enabled on all tables
- Users can only access their own data
- All operations are filtered by user_id
- Email/OTP authentication provides secure passwordless login

## Troubleshooting

### Common Issues:

1. **"Failed to send magic link"**
   - Check your email provider isn't blocking Supabase emails
   - Verify email is correctly entered
   - Check Supabase project status

2. **"Sync failed"**
   - Verify internet connection
   - Check Supabase project URL and keys are correct
   - Ensure user is authenticated

3. **"No data syncing"**
   - Verify RLS policies are correctly applied
   - Check user_id is being set correctly
   - Review Supabase logs in dashboard

### Development vs Production

For production use:
1. Enable email confirmations in Auth settings
2. Set up custom SMTP for email delivery
3. Configure custom domain if needed
4. Review and test all RLS policies
5. Set up proper monitoring and alerts

## Next Steps

Once setup is complete, Phase 7 will be fully functional with:
- ✅ User authentication via email/OTP
- ✅ Automatic data synchronization  
- ✅ Offline-first functionality
- ✅ Conflict resolution
- ✅ Multi-device support