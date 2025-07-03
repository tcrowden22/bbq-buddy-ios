import Foundation

struct SupabaseConfig {
    // MARK: - Supabase Configuration
    // Replace these with your actual Supabase project values
    static let supabaseURL = "https://dmptcbzmifabmcnaebey.supabase.co" // e.g., "https://xyzcompany.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtcHRjYnptaWZhYm1jbmFlYmV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0NzY3MzQsImV4cCI6MjA2NzA1MjczNH0.H7ROEa9ah_fHx4XSbbmbkgNT6phlxC1iXIFAAwkAeEw" // Your anon/public key from Settings > API
    
    // MARK: - Apple Sign In Configuration
    // This should match your Apple Services ID configured in Supabase Dashboard
    static let appleRedirectURL = "\(supabaseURL)/auth/v1/callback"
    
    // MARK: - Validation
    static var isConfigured: Bool {
        return !supabaseURL.contains("YOUR_") && !supabaseAnonKey.contains("YOUR_")
    }
}

/*
 SETUP INSTRUCTIONS:
 
 1. Go to your Supabase Dashboard (https://app.supabase.com)
 2. Select your project
 3. Go to Settings > API
 4. Copy your Project URL and replace "YOUR_SUPABASE_PROJECT_URL"
 5. Copy your anon/public key and replace "YOUR_SUPABASE_ANON_KEY"
 
 For Apple Sign In:
 1. Go to Authentication > Providers in Supabase Dashboard
 2. Enable Apple provider
 3. Configure with your Apple Developer details:
    - Services ID
    - Team ID
    - Key ID
    - Private Key
 4. Set redirect URL to: https://YOUR_PROJECT.supabase.co/auth/v1/callback
 
 For iOS App:
 1. Add "Sign in with Apple" capability in Xcode
 2. Make sure your Bundle ID matches what's configured in Apple Developer Portal
 */ 