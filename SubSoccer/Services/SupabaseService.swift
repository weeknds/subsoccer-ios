import Foundation
import Supabase
import AuthenticationServices
import CryptoKit


// MARK: - Supabase Service
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let supabaseUrl = "https://fdkoehbbtbycvipclgvx.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZka29laGJidGJ5Y3ZpcGNsZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNjI0NzMsImV4cCI6MjA2NTYzODQ3M30.g1PNSuc33xWWYUIhBg1Z5zhQp0zUrGmIMN40foylHGA"
    
    // Real Supabase client
    lazy var client: SupabaseClient = {
        guard let url = URL(string: supabaseUrl) else {
            fatalError("Invalid Supabase URL: \(supabaseUrl)")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )
    }()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        // Check if user is already authenticated
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Authentication
    
    @MainActor
    func checkAuthStatus() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }
    
    // MARK: - Email/Password Authentication
    
    @MainActor
    func signUpWithEmail(_ email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        let user = response.user
        currentUser = user
        isAuthenticated = true
    }
    
    @MainActor
    func signInWithEmail(_ email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        currentUser = session.user
        isAuthenticated = true
    }
    
    // MARK: - OTP Authentication (kept for backward compatibility)
    
    @MainActor
    func signInWithEmailOTP(_ email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }
    
    @MainActor
    func verifyOTP(email: String, token: String) async throws {
        let session = try await client.auth.verifyOTP(email: email, token: token, type: .email)
        currentUser = session.user
        isAuthenticated = true
    }
    
    // MARK: - Apple Sign-In Authentication
    
    func generateNonce() -> String {
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = 32
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
    
    @MainActor
    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
        currentUser = session.user
        isAuthenticated = true
    }
    
    @MainActor
    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - Database Operations (Mock implementations)
    
    func syncTeams() async throws -> [RemoteTeam] {
        // Mock implementation - return empty array
        return []
    }
    
    func syncPlayers(for teamId: String) async throws -> [RemotePlayer] {
        // Mock implementation - return empty array
        return []
    }
    
    func syncMatches(for teamId: String) async throws -> [RemoteMatch] {
        // Mock implementation - return empty array
        return []
    }
    
    func syncTrainingSessions(for teamId: String) async throws -> [RemoteTrainingSession] {
        // Mock implementation - return empty array
        return []
    }
    
    // MARK: - Upload Operations (Mock implementations)
    
    func uploadTeam(_ team: RemoteTeam) async throws {
        // Mock implementation - do nothing
    }
    
    func uploadPlayer(_ player: RemotePlayer) async throws {
        // Mock implementation - do nothing
    }
    
    func uploadMatch(_ match: RemoteMatch) async throws {
        // Mock implementation - do nothing
    }
    
    func uploadTrainingSession(_ session: RemoteTrainingSession) async throws {
        // Mock implementation - do nothing
    }
}

// MARK: - Remote Models

struct RemoteTeam: Codable, Identifiable {
    let id: String
    let name: String
    let created_at: Date
    let updated_at: Date
    let user_id: String
}

struct RemotePlayer: Codable, Identifiable {
    let id: String
    let name: String
    let jersey_number: Int
    let position: String
    let profile_image_url: String?
    let team_id: String
    let created_at: Date
    let updated_at: Date
}

struct RemoteMatch: Codable, Identifiable {
    let id: String
    let date: Date
    let duration: Int
    let number_of_halves: Int
    let has_overtime: Bool
    let team_id: String
    let created_at: Date
    let updated_at: Date
}

struct RemoteTrainingSession: Codable, Identifiable {
    let id: String
    let title: String?
    let date: Date?
    let duration: Int
    let location: String?
    let notes: String?
    let type: String?
    let team_id: String
    let created_at: Date
    let updated_at: Date
}

struct RemotePlayerStats: Codable, Identifiable {
    let id: String
    let minutes_played: Int
    let goals: Int
    let assists: Int
    let player_id: String
    let match_id: String
    let created_at: Date
    let updated_at: Date
}

struct RemoteTrainingAttendance: Codable, Identifiable {
    let id: String
    let is_present: Bool
    let notes: String?
    let player_id: String
    let session_id: String
    let created_at: Date
    let updated_at: Date
}

struct RemoteTrainingDrill: Codable, Identifiable {
    let id: String
    let name: String?
    let description: String?
    let duration: Int
    let order: Int
    let session_id: String
    let created_at: Date
    let updated_at: Date
}