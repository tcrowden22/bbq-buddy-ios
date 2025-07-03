import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showDetail = false
    @State private var showingDeleteAlert = false
    @State private var sessionToDelete: CookSession?
    
    var body: some View {
        ZStack {
            // Black to orange gradient background like SessionView
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
            
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Cook History")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 24)
                
                if viewModel.sessions.isEmpty {
                    Spacer()
                    Text("No cooking sessions yet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.sessions) { session in
                            Button(action: {
                                viewModel.selectedSession = session
                                viewModel.noteDraft = session.notes ?? ""
                                viewModel.aiFeedbackDraft = session.aiFeedback ?? ""
                                showDetail = true
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(session.meatType)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Weight: \(String(format: "%.1f", session.weight)) lbs")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Duration: \(durationString(from: session.startTime, to: session.endTime))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    if !session.temperatureReadings.isEmpty {
                                        TempChart(readings: session.temperatureReadings)
                                            .frame(height: 60)
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.loadSessions()
                    }
                }
            }
            .padding()
            .sheet(isPresented: $showDetail) {
                if let session = viewModel.selectedSession {
                    SessionDetailView(session: session, viewModel: viewModel)
                }
            }
            .alert("Delete Session", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        Task {
                            await viewModel.deleteSession(session)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this cooking session? This action cannot be undone.")
            }
        }
        .onAppear {
            Task {
                await viewModel.loadSessions()
            }
        }
    }
    
    func durationString(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct TempChart: View {
    let readings: [CookSession.TemperatureReading]
    var body: some View {
        GeometryReader { geo in
            let temps = readings.map { $0.temperature }
            let minT = temps.min() ?? 0
            let maxT = temps.max() ?? 1
            let points = readings.enumerated().map { (i, r) in
                CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(max(readings.count-1,1)),
                        y: geo.size.height * CGFloat(1 - (r.temperature - minT) / max(1, maxT - minT)))
            }
            Path { path in
                if let first = points.first {
                    path.move(to: first)
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                }
            }
            .stroke(Color.accentColor, lineWidth: 2)
        }
    }
}

struct SessionDetailView: View {
    let session: CookSession
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notes")) {
                    TextEditor(text: $viewModel.noteDraft)
                    Button("Save Note") {
                        viewModel.addNote(to: session, note: viewModel.noteDraft)
                    }
                }
                Section(header: Text("AI Feedback")) {
                    if let feedback = session.aiFeedback {
                        Text(feedback)
                            .padding(6)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .cornerRadius(8)
                    }
                    if isAnalyzing {
                        ProgressView("Analyzing photo...")
                    }
                    Button("Upload Photo for Analysis") {
                        showImagePicker = true
                    }
                }
            }
            .navigationTitle(session.meatType)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, onImagePicked: { image in
                    isAnalyzing = true
                    viewModel.analyzePhoto(for: session, photo: image)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isAnalyzing = false
                    }
                })
            }
        }
    }
}

// Simple UIKit-based image picker for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
                parent.onImagePicked(img)
            }
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    HistoryView()
} 