# BBQ Buddy - Supabase Authentication Setup Guide

This guide will help you integrate Supabase authentication with email/password and Sign in with Apple into your BBQ Buddy iOS app.

## 📋 Overview

The authentication system includes:
- ✅ Email/password login and signup
- ✅ Sign in with Apple
- ✅ Secure session management with Keychain
- ✅ Automatic token refresh
- ✅ Password reset functionality
- ✅ Profile management with logout

## 🚀 Quick Setup

### Step 1: Install Supabase SDK

**Option A: Using Xcode (Recommended)**
1. Open `BBQ Buddy.xcodeproj` in Xcode
2. Go to `File` > `Add Package Dependencies`
3. Enter: `https://github.com/supabase/supabase-swift`
4. Select "Up to Next Major Version" with version `2.5.1`
5. Click `Add Package` and select `Supabase`

**Option B: Using Swift Package Manager**
```bash
swift package resolve
```

### Step 2: Configure Supabase Project

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Create a new project or select existing one
3. Go to `Settings` > `API`
4. Copy your `Project URL` and `anon/public key`

### Step 3: Update Configuration

Edit `SupabaseConfig.swift`:
```swift
struct SupabaseConfig {
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your_anon_key_here"
}
```

### Step 4: Enable Apple Sign In

**In Supabase Dashboard:**
1. Go to `Authentication` > `Providers`
2. Enable `Apple` provider
3. Configure with your Apple Developer details:
   - Services ID (e.g., `com.yourcompany.bbqbuddy.signin`)
   - Team ID
   - Key ID
   - Private Key (.p8 file content)
4. Set redirect URL: `https://your-project.supabase.co/auth/v1/callback`

**In Xcode:**
1. Select your target
2. Go to `Signing & Capabilities`
3. Click `+ Capability`
4. Add `Sign in with Apple`

**In Apple Developer Portal:**
1. Create an App ID with Sign in with Apple capability
2. Create a Services ID for web authentication
3. Create a Sign in with Apple Key
4. Configure the Services ID with your Supabase redirect URL

## 📱 Files Added

### Core Authentication
- `AuthManager.swift` - Main authentication manager
- `AuthView.swift` - Login/signup UI
- `ProfileView.swift` - User profile and logout
- `SupabaseConfig.swift` - Configuration file

### Updated Files
- `BBQ_BuddyApp.swift` - Authentication integration
- `ContentView.swift` - Added profile tab

## 🔧 How It Works

### AuthManager Features
```swift
// Email/password authentication
await authManager.signInWithEmail(email: email, password: password)
await authManager.signUpWithEmail(email: email, password: password)

// Apple Sign In
await authManager.signInWithApple()

// Session management
await authManager.restoreSession()
await authManager.signOut()

// Password reset
await authManager.resetPassword(email: email)
```

### Session Persistence
- Sessions are automatically stored in Keychain
- Tokens refresh automatically
- Auth state is observed throughout the app
- Logout clears all stored data

### UI Components
- Responsive design matching BBQ Buddy theme
- Loading states and error handling
- Forgot password flow
- Profile management

## 🛡️ Security Features

1. **Secure Storage**: Sessions stored in iOS Keychain
2. **Auto-refresh**: Tokens refresh automatically before expiration
3. **State Management**: Real-time auth state updates
4. **Error Handling**: Comprehensive error messages
5. **Input Validation**: Email and password validation

## 🧪 Testing

### Test Email Authentication
1. Run the app
2. Tap "Sign Up" 
3. Enter email/password
4. Check email for confirmation (if enabled)
5. Sign in with same credentials

### Test Apple Sign In
1. Ensure you're signed into iCloud on device/simulator
2. Tap "Sign in with Apple"
3. Follow Apple authentication flow
4. Verify user is signed in

### Test Session Persistence
1. Sign in to the app
2. Force quit the app
3. Reopen - should remain signed in
4. Test logout functionality

## 🔍 Troubleshooting

### Common Issues

**"Supabase not configured" error:**
- Update `SupabaseConfig.swift` with your actual credentials

**Apple Sign In not working:**
- Verify Services ID matches Supabase configuration
- Check redirect URL is exactly: `https://your-project.supabase.co/auth/v1/callback`
- Ensure Sign in with Apple capability is added in Xcode

**Email confirmation required:**
- Check Supabase Auth settings
- Disable email confirmation for testing: `Auth` > `Settings` > Disable "Enable email confirmations"

**Compilation errors:**
- Clean build folder: `Product` > `Clean Build Folder`
- Ensure Supabase package is properly installed

### Debug Tips

1. **Check Supabase logs**: Dashboard > Logs
2. **Monitor auth state**: Add breakpoints in `observeAuthChanges()`
3. **Verify credentials**: Test in Supabase Dashboard
4. **Apple Sign In logs**: Check Xcode console for detailed errors

## 🎯 Next Steps

1. **Customize UI**: Modify `AuthView.swift` colors/styling
2. **Add user profiles**: Extend with user metadata
3. **Social providers**: Add Google, Facebook, etc.
4. **Role-based access**: Implement user roles
5. **Push notifications**: Add notification preferences

## 📚 Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Apple Sign In Guide](https://developer.apple.com/sign-in-with-apple/)
- [Supabase Swift SDK](https://github.com/supabase/supabase-swift)

---

## 💡 Usage in Your App

Once setup is complete, users will:
1. See `AuthView` when not authenticated
2. Sign in with email/password or Apple ID
3. Access all BBQ Buddy features when authenticated
4. Manage profile and logout from Profile tab
5. Sessions persist across app restarts

The authentication is now fully integrated with your BBQ planning and monitoring features! 🔥 