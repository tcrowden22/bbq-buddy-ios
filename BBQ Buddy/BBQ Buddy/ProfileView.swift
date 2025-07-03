import SwiftUI
import ContactsUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var appSettings = AppSettings.shared
    @State private var showLogoutAlert = false
    @State private var profileImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            // Background gradient matching app theme
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
                    // Header
                    VStack(spacing: 16) {
                        // Profile Icon or User Photo
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.3))
                                .frame(width: 80, height: 80)
                            
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text("Profile")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            if let user = authManager.currentUser {
                                Text(user.email ?? "BBQ Enthusiast")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    
                    // Settings Card
                    VStack(spacing: 20) {
                        // Account Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Account")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                if let user = authManager.currentUser {
                                    ProfileRow(
                                        icon: "envelope.fill",
                                        title: "Email",
                                        value: user.email ?? "Not available"
                                    )
                                    
                                    ProfileRow(
                                        icon: "calendar",
                                        title: "Member Since",
                                        value: formatDate(user.createdAt)
                                    )
                                }
                                
                                ProfileRow(
                                    icon: "person.badge.key.fill",
                                    title: "Account Type",
                                    value: "BBQ Enthusiast"
                                )
                            }
                        }
                        
                        Divider()
                            .overlay(Color.white.opacity(0.3))
                        
                        // App Settings Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("App Settings")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    HStack(spacing: 12) {
                                        Image(systemName: "moon.fill")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.orange)
                                            .frame(width: 24)
                                        
                                        Text("Dark Mode")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $appSettings.isDarkMode)
                                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                                }
                                
                                ProfileRow(
                                    icon: "thermometer",
                                    title: "Temperature Unit",
                                    value: "Fahrenheit"
                                )
                                
                                ProfileRow(
                                    icon: "bell.fill",
                                    title: "Notifications",
                                    value: "Enabled"
                                )
                            }
                        }
                        
                        Divider()
                            .overlay(Color.white.opacity(0.3))
                        
                        // Actions Section
                        VStack(spacing: 16) {
                            // Privacy Policy
                            Button(action: {
                                // Open privacy policy
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    
                                    Text("Privacy Policy")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            
                            // Terms of Service
                            Button(action: {
                                // Open terms of service
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.plaintext.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    
                                    Text("Terms of Service")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            
                            // Sign Out Button
                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    
                                    Text("Sign Out")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    // Version Info
                    VStack(spacing: 8) {
                        Text("BBQ Buddy")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
            }
        }
        .onAppear {
            fetchContactImage()
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func fetchContactImage() {
        // Try to fetch the user's contact image by email
        guard let email = authManager.currentUser?.email else { return }
        let store = CNContactStore()
        let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
        let keys = [CNContactThumbnailImageDataKey as CNKeyDescriptor]
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
                if let data = contacts.first?.thumbnailImageData, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.profileImage = image
                    }
                }
            } catch {
                // No contact image found, fallback to default
            }
        }
    }
}

// MARK: - Profile Row Component
struct ProfileRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
} 