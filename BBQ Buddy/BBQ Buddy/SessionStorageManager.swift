import Foundation
import Supabase
// Add import for Models.swift if needed, or just rely on module scope

// Use the shared ChatMessage model from CookPlannerView.swift
// If you want to move it to a shared file, do so and import it here
// import CookPlannerView (if needed)

// MARK: - Models
// Remove the local definition of struct ChatMessage

struct ChatSession: Codable, Identifiable {
    let id: UUID
    let sessionName: String
    let createdAt: Date
    let messages: [ChatMessage]
    let metadata: [String: String]
}

// For decoding Supabase rows
private struct ChatSessionRecord: Decodable {
    let id: String
    let user_id: String
    let session_name: String
    let created_at: String
    let messages: String
    let metadata: String
}

// For inserting new sessions
private struct ChatSessionInsert: Encodable {
    let id: String
    let user_id: String
    let session_name: String
    let created_at: String
    let messages: String
    let metadata: String
}

// Helper for encoding/decoding [String: Any]
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else if let arrVal = try? container.decode([AnyCodable].self) {
            value = arrVal.map { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let dictVal as [String: Any]:
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        case let arrVal as [Any]:
            try container.encode(arrVal.map { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - SessionStorageManager
@MainActor
class SessionStorageManager {
    static let shared = SessionStorageManager()
    private let client: SupabaseClient
    private init() {
        client = SupabaseClient(supabaseURL: URL(string: SupabaseConfig.supabaseURL)!, supabaseKey: SupabaseConfig.supabaseAnonKey)
    }
    
    // Save a session
    func saveSession(sessionName: String, messages: [ChatMessage], metadata: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        print("[SessionStorageManager] saveSession called with name: \(sessionName)")
        print("[SessionStorageManager] Messages count: \(messages.count)")
        print("[SessionStorageManager] Metadata: \(metadata)")
        
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            print("[SessionStorageManager] Error: No user ID found when saving session.")
            print("[SessionStorageManager] AuthManager.shared.isAuthenticated: \(AuthManager.shared.isAuthenticated)")
            print("[SessionStorageManager] AuthManager.shared.currentUser: \(String(describing: AuthManager.shared.currentUser))")
            completion(.failure(NSError(domain: "NoUserID", code: 0)))
            return
        }
        
        print("[SessionStorageManager] User ID found: \(userId)")
        
        let sessionId = UUID()
        let createdAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        print("[SessionStorageManager] Starting encoding...")
        
        guard let messagesData = try? encoder.encode(messages),
              let messagesString = String(data: messagesData, encoding: .utf8),
              let metadataData = try? encoder.encode(metadata),
              let metadataString = String(data: metadataData, encoding: .utf8) else {
            print("[SessionStorageManager] Error encoding messages or metadata.")
            completion(.failure(NSError(domain: "EncodingError", code: 0)))
            return
        }
        
        print("[SessionStorageManager] Encoding successful")
        print("[SessionStorageManager] Messages JSON length: \(messagesString.count)")
        print("[SessionStorageManager] Metadata JSON length: \(metadataString.count)")
        
        let chatSession = ChatSessionInsert(
            id: sessionId.uuidString,
            user_id: userId,
            session_name: sessionName,
            created_at: ISO8601DateFormatter().string(from: createdAt),
            messages: messagesString,
            metadata: metadataString
        )
        
        print("[SessionStorageManager] ChatSessionInsert created with ID: \(sessionId.uuidString)")
        
        Task {
            do {
                print("[SessionStorageManager] Starting database insert...")
                try await client.database
                    .from("chat_sessions")
                    .insert(chatSession)
                    .execute()
                print("[SessionStorageManager] Database insert successful!")
                completion(.success(()))
            } catch {
                print("[SessionStorageManager] Error saving session: \(error)")
                print("[SessionStorageManager] Error type: \(type(of: error))")
                if let supabaseError = error as? any Error {
                    print("[SessionStorageManager] Error description: \(supabaseError.localizedDescription)")
                }
                completion(.failure(error))
            }
        }
    }
    
    // Load all sessions for the current user
    func loadSessionsForUser(completion: @escaping (Result<[ChatSession], Error>) -> Void) {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            print("[SessionStorageManager] Error: No user ID found when loading sessions.")
            completion(.failure(NSError(domain: "NoUserID", code: 0)))
            return
        }
        
        Task {
            do {
                let response = try await client.database
                    .from("chat_sessions")
                    .select("*")
                    .eq("user_id", value: userId)
                    .execute()
                
                let data = response.data
                let records = try JSONDecoder().decode([ChatSessionRecord].self, from: data)
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let sessions: [ChatSession] = records.compactMap { record in
                    guard let id = UUID(uuidString: record.id),
                          let createdAt = ISO8601DateFormatter().date(from: record.created_at),
                          let messagesData = record.messages.data(using: .utf8),
                          let messages = try? decoder.decode([ChatMessage].self, from: messagesData),
                          let metadataData = record.metadata.data(using: .utf8),
                          let metadata = try? decoder.decode([String: String].self, from: metadataData)
                    else { return nil }
                    return ChatSession(id: id, sessionName: record.session_name, createdAt: createdAt, messages: messages, metadata: metadata)
                }
                completion(.success(sessions))
            } catch {
                print("[SessionStorageManager] Error loading sessions: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // Load a session by ID
    func loadSessionById(id: UUID, completion: @escaping (Result<ChatSession?, Error>) -> Void) {
        Task {
            do {
                let response = try await client.database
                    .from("chat_sessions")
                    .select("*")
                    .eq("id", value: id.uuidString)
                    .single()
                    .execute()
                
                let data = response.data
                let record = try JSONDecoder().decode(ChatSessionRecord.self, from: data)
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                guard let uuid = UUID(uuidString: record.id),
                      let createdAt = ISO8601DateFormatter().date(from: record.created_at),
                      let messagesData = record.messages.data(using: .utf8),
                      let messages = try? decoder.decode([ChatMessage].self, from: messagesData),
                      let metadataData = record.metadata.data(using: .utf8),
                      let metadata = try? decoder.decode([String: String].self, from: metadataData)
                else {
                    completion(.success(nil))
                    return
                }
                let session = ChatSession(id: uuid, sessionName: record.session_name, createdAt: createdAt, messages: messages, metadata: metadata)
                completion(.success(session))
            } catch {
                print("[SessionStorageManager] Error loading session by ID: \(error)")
                completion(.failure(error))
            }
        }
    }

    // Append a message to an existing session's messages array
    func appendMessage(to sessionId: UUID, message: ChatMessage) async throws {
        // Load the session
        let session: ChatSession? = try await withCheckedThrowingContinuation { continuation in
            self.loadSessionById(id: sessionId) { result in
                switch result {
                case .success(let session):
                    continuation.resume(returning: session)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        guard let session = session else {
            print("[SessionStorageManager] Error: Session not found for id \(sessionId)")
            throw NSError(domain: "SessionNotFound", code: 0)
        }
        // Make a mutable copy and append
        var updatedMessages = session.messages
        updatedMessages.append(message)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let messagesData = try? encoder.encode(updatedMessages),
              let messagesString = String(data: messagesData, encoding: .utf8) else {
            print("[SessionStorageManager] Error encoding messages for update.")
            throw NSError(domain: "EncodingError", code: 0)
        }
        // Update the row (async/await)
        try await client.database
            .from("chat_sessions")
            .update(["messages": messagesString])
            .eq("id", value: sessionId.uuidString)
            .execute()
    }

    // Create a new session with a single initial message
    func createNewSession(name: String, initialMessage: ChatMessage, metadata: [String: String]) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            print("[SessionStorageManager] Error: No user ID found when creating session.")
            throw NSError(domain: "NoUserID", code: 0)
        }
        let sessionId = UUID()
        let createdAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let messagesData = try? encoder.encode([initialMessage]),
              let messagesString = String(data: messagesData, encoding: .utf8),
              let metadataData = try? encoder.encode(metadata),
              let metadataString = String(data: metadataData, encoding: .utf8) else {
            print("[SessionStorageManager] Error encoding messages or metadata for new session.")
            throw NSError(domain: "EncodingError", code: 0)
        }
        let chatSession = ChatSessionInsert(
            id: sessionId.uuidString,
            user_id: userId,
            session_name: name,
            created_at: ISO8601DateFormatter().string(from: createdAt),
            messages: messagesString,
            metadata: metadataString
        )
        
        try await client.database
            .from("chat_sessions")
            .insert(chatSession)
            .execute()
    }
} 