import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient matching BBQ Buddy theme
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        Color.red.opacity(0.3),
                        Color.orange.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 60)
                        
                        // Header
                        VStack(spacing: 16) {
                            // Logo
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 60, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 8) {
                                Text("BBQ Buddy")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(isSignUp ? "Create your account" : "Welcome back!")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // Auth Form
                        VStack(spacing: 24) {
                            // Email/Password Form
                            VStack(spacing: 16) {
                                // Email Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Email", systemImage: "envelope")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    TextField("Enter your email", text: $email)
                                        .textFieldStyle(AuthTextFieldStyle(isFocused: emailFocused))
                                        .keyboardType(.emailAddress)
                                        .textContentType(.emailAddress)
                                        .autocapitalization(.none)
                                        .focused($emailFocused)
                                }
                                
                                // Password Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Password", systemImage: "lock")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    SecureField("Enter your password", text: $password)
                                        .textFieldStyle(AuthTextFieldStyle(isFocused: passwordFocused))
                                        .textContentType(isSignUp ? .newPassword : .password)
                                        .focused($passwordFocused)
                                }
                                
                                // Forgot Password (Sign In only)
                                if !isSignUp {
                                    HStack {
                                        Spacer()
                                        Button("Forgot Password?") {
                                            showForgotPassword = true
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.orange)
                                    }
                                }
                            }
                            
                            // Error Message
                            if let errorMessage = authManager.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Email/Password Button
                            Button(action: {
                                Task {
                                    if isSignUp {
                                        await authManager.signUpWithEmail(email: email, password: password)
                                    } else {
                                        await authManager.signInWithEmail(email: email, password: password)
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                            .opacity(authManager.isLoading || email.isEmpty || password.isEmpty ? 0.6 : 1.0)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                                
                                Text("or")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                            }
                            
                            // Sign in with Apple
                            SignInWithAppleButton(
                                onRequest: { request in
                                    // This is handled by AuthManager
                                },
                                onCompletion: { _ in
                                    // This is handled by AuthManager
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                Task {
                                    await authManager.signInWithApple()
                                }
                            }
                            
                            // Toggle Sign Up/Sign In
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSignUp.toggle()
                                }
                                authManager.errorMessage = nil
                            }) {
                                HStack(spacing: 4) {
                                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(isSignUp ? "Sign In" : "Sign Up")
                                        .foregroundColor(.orange)
                                        .fontWeight(.semibold)
                                }
                                .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
}

// MARK: - Custom Text Field Style
struct AuthTextFieldStyle: TextFieldStyle {
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.orange : Color.white.opacity(0.2), lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var emailFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        Color.red.opacity(0.3),
                        Color.orange.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.orange)
                        
                        VStack(spacing: 8) {
                            Text("Reset Password")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Enter your email address and we'll send you a link to reset your password.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Email", systemImage: "envelope")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(AuthTextFieldStyle(isFocused: emailFocused))
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .focused($emailFocused)
                        }
                        
                        if let errorMessage = authManager.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(errorMessage.contains("sent") ? .green : .red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            Task {
                                await authManager.resetPassword(email: email)
                            }
                        }) {
                            HStack(spacing: 12) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                Text("Send Reset Link")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(authManager.isLoading || email.isEmpty)
                        .opacity(authManager.isLoading || email.isEmpty ? 0.6 : 1.0)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

#Preview {
    AuthView()
} 