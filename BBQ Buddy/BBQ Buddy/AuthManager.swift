import Foundation
import AuthenticationServices
import SwiftUI
import Supabase

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase: SupabaseClient
    
    override init() {
        // Initialize Supabase client using configuration
        guard SupabaseConfig.isConfigured else {
            fatalError("Supabase not configured. Please update SupabaseConfig.swift with your project credentials.")
        }
        
        let supabaseURL = URL(string: SupabaseConfig.supabaseURL)!
        let supabaseAnonKey = SupabaseConfig.supabaseAnonKey
        
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey
        )
        
        super.init()
        
        // Listen for auth state changes
        Task {
            await observeAuthChanges()
        }
        
        // Restore session on app launch
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - Auth State Observer
    private func observeAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                self.currentUser = session?.user
                self.isAuthenticated = true
                self.errorMessage = nil
            case .signedOut:
                self.currentUser = nil
                self.isAuthenticated = false
            case .passwordRecovery, .tokenRefreshed, .userUpdated:
                break
            case .initialSession:
                if let user = session?.user {
                    self.currentUser = user
                    self.isAuthenticated = true
                } else {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            case .userDeleted:
                self.currentUser = nil
                self.isAuthenticated = false
            case .mfaChallengeVerified:
                break
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            currentUser = session.user
            isAuthenticated = true
            
        } catch {
            errorMessage = error.localizedDescription
            print("Email sign in error: \(error)")
        }
        
        isLoading = false
    }
    
    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            // Check if email confirmation is required
            if session.user.emailConfirmedAt == nil {
                errorMessage = "Please check your email and click the confirmation link."
            } else {
                currentUser = session.user
                isAuthenticated = true
            }
            
        } catch {
            errorMessage = error.localizedDescription
            print("Email sign up error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Sign in with Apple
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let appleIDCredential = try await requestAppleIDCredential()
            
            guard let identityToken = appleIDCredential.identityToken,
                  let identityTokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Failed to get Apple ID token"
                isLoading = false
                return
            }
            
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: identityTokenString
                )
            )
            
            currentUser = session.user
            isAuthenticated = true
            
        } catch {
            errorMessage = error.localizedDescription
            print("Apple sign in error: \(error)")
        }
        
        isLoading = false
    }
    
    private func requestAppleIDCredential() async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = AppleSignInDelegate { result in
                continuation.resume(with: result)
            }
            authorizationController.presentationContextProvider = AppleSignInPresentationContextProvider()
            authorizationController.performRequests()
        }
    }
    
    // MARK: - Session Management
    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            // No valid session found
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    func signOut() async {
        isLoading = true
        
        do {
            try await supabase.auth.signOut()
            currentUser = nil
            isAuthenticated = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Sign out error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            errorMessage = "Password reset email sent. Please check your inbox."
        } catch {
            errorMessage = error.localizedDescription
            print("Password reset error: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(appleIDCredential))
        } else {
            completion(.failure(AuthError.invalidCredential))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - Apple Sign In Presentation Context Provider
private class AppleSignInPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("Unable to get window")
        }
        return window
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case invalidCredential
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credential received"
        }
    }
} 
