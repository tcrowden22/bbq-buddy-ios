import SwiftUI
import UIKit

struct AssistantView: View {
    @StateObject private var viewModel = AssistantViewModel()
    @EnvironmentObject var appSettings: AppSettings
    @State private var showImagePicker = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom()
                }
            }
            
            // Input Bar
            VStack {
                Divider()
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Ask a question...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .padding(.vertical, 8)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .orange)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, keyboardHeight > 0 ? 5 : 8)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                keyboardHeight = 0
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerPlaceholder()
        }
    }
    
    private func scrollToBottom() {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageText = inputText
        inputText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(messageText, cookPlan: nil, temperatureHistory: [])
        }
    }
}

struct ChatHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("BBQ Assistant")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Online")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Text("Your personal BBQ expert")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding(12)
                .background(message.isUser ? Color.orange : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(16, corners: message.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct ImagePickerPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Image Picker")
                .font(.system(size: 24, weight: .bold))
            
            Text("Photo upload feature coming soon!")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

#Preview {
    AssistantView()
        .environmentObject(AppSettings.shared)
} 