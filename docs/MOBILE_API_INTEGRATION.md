# Ciel Social - Mobile API Integration Guide

## 📱 Mobile API Security Architecture (iOS/Android)

```markdown
┌───────────────────────────────────────────────────────────────────────────────┐
│                  MOBILE API SECURITY ARCHITECTURE (iOS/Android)                 │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  📱 Mobile App  →  🔒 Certificate Pinning  →  🛡️ API Gateway  →  🔐 API       │
│                                                                               │
│  Features:                                                                   │
│  • API Key Authentication                                                    │
│  • Certificate Pinning (prevents MITM)                                        │
│  • JWT Token Refresh                                                          │
│  • Request Signing                                                            │
│  • Rate Limiting                                                             │
│  • WAF Protection                                                             │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

## 🎯 API Configuration for Mobile Apps

### Swift (iOS) - API Client Setup

```swift
// APIClient.swift
import Foundation
import Security

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://api.ciel-social.eu"
    private let apiKey = "YOUR_IOS_API_KEY" // From secure storage

    private init() {
        // Configure URLSession with certificate pinning
        configureSecureSession()
    }

    private func configureSecureSession() {
        // In production, use proper certificate pinning
        // This is a simplified example
    }

    func makeRequest<T: Decodable>(endpoint: String,
                                  method: String = "GET",
                                  body: Data? = nil,
                                  completion: @escaping (Result<T, APIError>) -> Void) {

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Ciel-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.httpBody = body
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                completion(.failure(.rateLimited))
                return
            }

            // Handle authentication errors
            if httpResponse.statusCode == 401 {
                completion(.failure(.unauthorized))
                return
            }

            // Handle other errors
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.serverError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }

        task.resume()
    }
}

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(Int)
    case noData
    case decodingError(Error)
}
```

### Kotlin (Android) - API Client Setup

```kotlin
// ApiClient.kt
import okhttp3.*
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.util.concurrent.TimeUnit

object ApiClient {
    private const val BASE_URL = "https://api.ciel-social.eu/"
    private const val API_KEY = "YOUR_ANDROID_API_KEY" // From secure storage

    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor { chain ->
            val original = chain.request()
            val requestBuilder = original.newBuilder()
                .header("Authorization", "Bearer $API_KEY")
                .header("Content-Type", "application/json")
                .header("User-Agent", "Ciel-Android/1.0")
                .header("Accept", "application/json")

            chain.proceed(requestBuilder.build())
        }
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        })
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        // Add certificate pinning in production
        .build()

    val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(BASE_URL)
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
}

interface ApiService {
    @GET("posts")
    suspend fun getPosts(): Response<List<Post>>

    @POST("auth/login")
    suspend fun login(@Body loginRequest: LoginRequest): Response<AuthResponse>

    @GET("users/me")
    suspend fun getCurrentUser(): Response<User>

    // Add other endpoints...
}

data class Post(val id: String, val content: String, val author: User)
data class User(val id: String, val username: String, val email: String)
data class LoginRequest(val email: String, val password: String)
data class AuthResponse(val token: String, val refreshToken: String)
```

## 🔐 Secure API Key Storage

### iOS (Keychain)

```swift
// KeychainHelper.swift
import Security

class KeychainHelper {
    static func save(key: String, data: Data) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]

        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }

    static func delete(key: String) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as [String: Any]

        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// Usage:
if let apiKeyData = "YOUR_API_KEY".data(using: .utf8) {
    KeychainHelper.save(key: "apiKey", data: apiKeyData)
}

if let savedKeyData = KeychainHelper.load(key: "apiKey"),
   let apiKey = String(data: savedKeyData, encoding: .utf8) {
    print("Retrieved API key: \(apiKey)")
}
```

### Android (EncryptedSharedPreferences)

```kotlin
// SecureStorage.kt
import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

class SecureStorage(context: Context) {
    private val sharedPreferences = EncryptedSharedPreferences.create(
        "secure_prefs",
        MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC),
        context,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveApiKey(apiKey: String) {
        sharedPreferences.edit().putString("api_key", apiKey).apply()
    }

    fun getApiKey(): String? {
        return sharedPreferences.getString("api_key", null)
    }

    fun clearApiKey() {
        sharedPreferences.edit().remove("api_key").apply()
    }
}

// Usage:
val secureStorage = SecureStorage(context)
secureStorage.saveApiKey("YOUR_API_KEY")
val apiKey = secureStorage.getApiKey()
```

## 🛡️ Certificate Pinning (Advanced Security)

### iOS Certificate Pinning

```swift
// CertificatePinning.swift
import Foundation

class CertificatePinning {
    static func createPinnedSession() -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: CertificatePinningDelegate(), delegateQueue: nil)
        return session
    }
}

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // Your API's certificate public key hash (get from your SSL certificate)
        let expectedPublicKeyHash = "YOUR_CERTIFICATE_PUBLIC_KEY_HASH"

        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverPublicKey = SecCertificateCopyKey(serverCertificate)
        let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey!, nil)

        let serverPublicKeyHash = serverPublicKeyData?.sha256()

        if serverPublicKeyHash == expectedPublicKeyHash {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

extension Data {
    func sha256() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
```

### Android Certificate Pinning

```kotlin
// CertificatePinner.kt
import okhttp3.CertificatePinner

object CertificatePinner {
    fun create(): CertificatePinner {
        // Get your certificate's public key hash from:
        // openssl s_client -connect api.ciel-social.eu:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
        val certificateHash = "sha256/YOUR_CERTIFICATE_HASH_HERE"

        return CertificatePinner.Builder()
            .add("api.ciel-social.eu", certificateHash)
            .build()
    }
}

// Update your OkHttpClient:
val certificatePinner = CertificatePinner.create()
val okHttpClient = OkHttpClient.Builder()
    .certificatePinner(certificatePinner)
    // ... other configuration
    .build()
```

## 🔑 API Key Rotation Strategy

```markdown
┌─────────────────────────────────────────────────────────────┐
│ API KEY ROTATION STRATEGY FOR MOBILE APPS                   │
├─────────────────────────────────────────────────────────────┤
│ 1. Deploy app with API Key v1                               │
│ 2. After 6 months, add API Key v2 to Terraform              │
│ 3. Update backend to accept both v1 and v2                  │
│ 4. Release app update with API Key v2                       │
│ 5. After 90% adoption, remove API Key v1                    │
│ 6. Repeat cycle every 6-12 months                          │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Error Handling and Retry Logic

### Swift Error Handling

```swift
// NetworkManager.swift
class NetworkManager {
    static let shared = NetworkManager()
    private let apiClient = APIClient.shared
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0

    func fetchData<T: Decodable>(endpoint: String, completion: @escaping (Result<T, APIError>) -> Void) {
        attemptRequest(endpoint: endpoint, retryCount: 0, completion: completion)
    }

    private func attemptRequest<T: Decodable>(endpoint: String, retryCount: Int, completion: @escaping (Result<T, APIError>) -> Void) {
        apiClient.makeRequest(endpoint: endpoint) { (result: Result<T, APIError>) in
            switch result {
            case .success(let data):
                completion(.success(data))

            case .failure(let error):
                if retryCount < self.maxRetries && self.shouldRetry(error: error) {
                    DispatchQueue.global().asyncAfter(deadline: .now() + self.retryDelay) {
                        self.attemptRequest(endpoint: endpoint, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    private func shouldRetry(error: APIError) -> Bool {
        switch error {
        case .networkError, .rateLimited, .serverError(500...599):
            return true
        default:
            return false
        }
    }
}
```

### Kotlin Error Handling

```kotlin
// NetworkManager.kt
class NetworkManager(private val context: Context) {
    private val apiService: ApiService = ApiClient.retrofit.create(ApiService::class.java)
    private val maxRetries = 3
    private val retryDelay = 2000L // 2 seconds

    suspend fun <T> makeApiCall(call: suspend () -> Response<T>): Result<T> {
        var lastError: Exception? = null

        repeat(maxRetries) { attempt ->
            try {
                val response = call()
                if (response.isSuccessful) {
                    return Result.success(response.body()!!)
                } else {
                    lastError = when (response.code()) {
                        401 -> ApiException.Unauthorized
                        403 -> ApiException.Forbidden
                        429 -> ApiException.RateLimited
                        in 500..599 -> ApiException.ServerError(response.code())
                        else -> ApiException.Unknown(response.message())
                    }
                }
            } catch (e: Exception) {
                lastError = e
            }

            if (attempt < maxRetries - 1 && shouldRetry(lastError)) {
                delay(retryDelay)
            }
        }

        return Result.failure(lastError!!)
    }

    private fun shouldRetry(error: Exception?): Boolean {
        return when (error) {
            is IOException, is ApiException.RateLimited, is ApiException.ServerError -> true
            else -> false
        }
    }

    // Usage:
    suspend fun getPosts(): Result<List<Post>> {
        return makeApiCall { apiService.getPosts() }
    }
}

sealed class ApiException(message: String) : Exception(message) {
    object Unauthorized : ApiException("Unauthorized")
    object Forbidden : ApiException("Forbidden")
    object RateLimited : ApiException("Rate limited")
    class ServerError(val code: Int) : ApiException("Server error: $code")
    class Unknown(message: String) : ApiException(message)
}
```

## 📸 Stories Integration Guide

### Stories Feature Overview

The Ciel Stories feature allows users to share temporary photo content that disappears after 24 hours. Key features:

- **Photo-only stories** (no videos)
- **24-hour expiration**
- **Privacy controls** (Public, Friends Only, Close Friends Only)
- **Reactions** (emoji-only, no DMs)
- **View tracking**
- **Story highlights** (permanent collections)

### Swift Implementation Example

```swift
// StoryService.swift
class StoryService {
    static let shared = StoryService()
    private let apiClient = APIClient.shared

    func createStory(mediaId: String, caption: String?, visibility: StoryVisibility, completion: @escaping (Result<Story, APIError>) -> Void) {
        let endpoint = "/stories"
        let body: [String: Any] = [
            "media_id": mediaId,
            "caption": caption ?? NSNull(),
            "visibility": visibility.rawValue
        ]
        
        apiClient.makeRequest(endpoint: endpoint, method: "POST", body: body, completion: completion)
    }

    func getUserStories(userId: String, limit: Int = 20, cursor: String? = nil, completion: @escaping (Result<[Story], APIError>) -> Void) {
        var queryParams = ["limit": String(limit)]
        if let cursor = cursor {
            queryParams["cursor"] = cursor
        }
        
        let endpoint = "/users/" + userId + "/stories"
        apiClient.makeRequest(endpoint: endpoint, method: "GET", queryParams: queryParams, completion: completion)
    }

    func addReaction(storyId: String, emoji: String, completion: @escaping (Result<Void, APIError>) -> Void) {
        let endpoint = "/stories/" + storyId + "/reactions"
        let body: [String: Any] = ["emoji": emoji]
        
        apiClient.makeRequest(endpoint: endpoint, method: "POST", body: body) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getStoriesFeed(limit: Int = 20, cursor: String? = nil, completion: @escaping (Result<[Story], APIError>) -> Void) {
        var queryParams = ["limit": String(limit)]
        if let cursor = cursor {
            queryParams["cursor"] = cursor
        }
        
        let endpoint = "/feed/stories"
        apiClient.makeRequest(endpoint: endpoint, method: "GET", queryParams: queryParams, completion: completion)
    }
}

// Story Model
enum StoryVisibility: String, Codable {
    case public = "public"
    case friendsOnly = "friends_only"
    case closeFriendsOnly = "close_friends_only"
}

struct Story: Codable {
    let id: String
    let userId: String
    let mediaId: String
    let caption: String?
    let createdAt: String
    let expiresAt: String
    let visibility: StoryVisibility
    let viewCount: Int
    let reactionCount: Int
    let isHighlight: Bool
    let highlightName: String?
}

struct StoryReaction: Codable {
    let id: String
    let storyId: String
    let userId: String
    let emoji: String
    let createdAt: String
}

struct StoryMetrics: Codable {
    let viewCount: Int
    let reactionCount: Int
    let reactionsByEmoji: [[String]]
    let viewerIds: [String]
}
```

### Kotlin Implementation Example

```kotlin
// StoryService.kt
class StoryService(private val apiClient: APIClient) {
    
    suspend fun createStory(mediaId: String, caption: String?, visibility: StoryVisibility): Story {
        val request = StoryCreateRequest(mediaId, caption, visibility)
        return apiClient.post("/stories", request)
    }

    suspend fun getUserStories(userId: String, limit: Int = 20, cursor: String? = null): List<Story> {
        val params = mutableMapOf("limit" to limit.toString())
        cursor?.let { params["cursor"] = it }
        return apiClient.get("/users/$userId/stories", params)
    }

    suspend fun addReaction(storyId: String, emoji: String) {
        val request = AddReactionRequest(emoji)
        apiClient.post("/stories/$storyId/reactions", request)
    }

    suspend fun getStoriesFeed(limit: Int = 20, cursor: String? = null): List<Story> {
        val params = mutableMapOf("limit" to limit.toString())
        cursor?.let { params["cursor"] = it }
        return apiClient.get("/feed/stories", params)
    }

    suspend fun markStorySeen(storyId: String) {
        apiClient.post("/stories/$storyId/seen", null)
    }

    suspend fun getStoryMetrics(storyId: String): StoryMetrics {
        return apiClient.get("/stories/$storyId/metrics")
    }
}

data class StoryCreateRequest(
    val media_id: String,
    val caption: String?,
    val visibility: StoryVisibility
)

data class AddReactionRequest(
    val emoji: String
)

enum class StoryVisibility {
    PUBLIC, FRIENDS_ONLY, CLOSE_FRIENDS_ONLY
}

data class Story(
    val id: String,
    val user_id: String,
    val media_id: String,
    val caption: String?,
    val created_at: String,
    val expires_at: String,
    val visibility: StoryVisibility,
    val view_count: Int,
    val reaction_count: Int,
    val is_highlight: Boolean,
    val highlight_name: String?
)

data class StoryReaction(
    val id: String,
    val story_id: String,
    val user_id: String,
    val emoji: String,
    val created_at: String
)

data class StoryMetrics(
    val view_count: Int,
    val reaction_count: Int,
    val reactions_by_emoji: List<List<String>>,
    val viewer_ids: List<String>
)
```

### UI Integration Best Practices

#### Story Creation Flow

1. **Media Selection**: Allow users to select photos from gallery or camera
2. **Caption Input**: Optional text caption (max 200 characters)
3. **Privacy Selection**: Let users choose visibility (Public/Friends/Close Friends)
4. **Preview**: Show story preview before posting
5. **Post**: Upload and create story

#### Story Viewing Flow

1. **Story Feed**: Show stories from followed users in chronological order
2. **Story Viewer**: Full-screen story viewer with tap navigation
3. **Reactions**: Show reaction buttons/emoji picker
4. **View Indicators**: Show who viewed the story (for story owners)
5. **Expiration**: Show countdown timer for remaining story lifetime

#### Performance Optimization

- **Prefetching**: Load next stories in background
- **Caching**: Cache story images and metadata
- **Lazy Loading**: Load stories progressively
- **Image Optimization**: Use appropriate image sizes and compression

#### Error Handling

- **Network Errors**: Show retry options for failed loads
- **Access Denied**: Handle private story access gracefully
- **Story Expired**: Remove expired stories from UI
- **Rate Limits**: Show user-friendly rate limit messages

### Story Analytics Integration

```swift
// AnalyticsService.swift
func trackStoryCreated() {
    analytics.logEvent("story_created", parameters: [
        "user_id": currentUserId,
        "visibility": storyVisibility.rawValue
    ])
}

func trackStoryViewed(storyId: String, userId: String) {
    analytics.logEvent("story_viewed", parameters: [
        "story_id": storyId,
        "user_id": userId
    ])
}

func trackStoryReactionAdded(storyId: String, emoji: String) {
    analytics.logEvent("story_reaction_added", parameters: [
        "story_id": storyId,
        "emoji": emoji
    ])
}
```

### Security Considerations

1. **Media Upload Security**:
   - Validate image file types and sizes
   - Use HTTPS for all media uploads
   - Implement proper content-type validation

2. **Privacy Enforcement**:
   - Respect visibility settings in UI
   - Hide private stories from unauthorized users
   - Cache invalidation for access changes

3. **Data Protection**:
   - Encrypt sensitive story data
   - Secure media cache on device
   - Implement proper cleanup for expired stories

### Testing Recommendations

1. **Unit Tests**: Test service methods and view models
2. **Integration Tests**: Test API integration and error handling
3. **UI Tests**: Test story creation and viewing flows
4. **Performance Tests**: Test with large story feeds
5. **Edge Cases**: Test expired stories, access control, rate limits

## 🛡️ Mobile-Specific Security Recommendations

### 1. API Key Management
- **Never hardcode keys** in source code
- **Use build-time injection** for API keys
- **Implement key rotation** every 6-12 months
- **Store keys securely** in Keychain (iOS) or EncryptedSharedPreferences (Android)

### 2. Network Security
- **Use HTTPS only** - never HTTP
- **Implement certificate pinning** to prevent MITM attacks
- **Disable cleartext traffic** in Android manifest
- **Use ATS (App Transport Security)** in iOS

### 3. Authentication Flow
```markdown
┌─────────────────────────────────────────────────────────────┐
│ MOBILE AUTHENTICATION FLOW                                   │
├─────────────────────────────────────────────────────────────┤
│ 1. User logs in with email/password                          │
│ 2. Server returns JWT + Refresh Token                       │
│ 3. Store tokens securely                                    │
│ 4. Use JWT for authenticated requests                       │
│ 5. Refresh token when JWT expires                           │
│ 6. Invalidate tokens on logout                              │
└─────────────────────────────────────────────────────────────┘
```

### 4. Rate Limiting Handling
- **Implement exponential backoff** for rate-limited requests
- **Show user-friendly messages** when rate limited
- **Queue requests** during rate limiting periods
- **Monitor rate limit headers** to anticipate limits

### 5. Offline Support
- **Cache responses** for offline use
- **Queue requests** when offline
- **Sync when connection restored**
- **Handle conflicts** gracefully

## 📋 Deployment Checklist

1. **Generate API Keys**:
   ```bash
   # Generate keys for iOS and Android
   openssl rand -hex 16  # iOS key
   openssl rand -hex 16  # Android key
   ```

2. **Update Terraform**:
   ```hcl
   api_keys = [
     "ios-app-key-here",
     "android-app-key-here"
   ]
   ```

3. **Deploy Infrastructure**:
   ```bash
   cd terraform/environments/prod
   terraform apply
   ```

4. **Get API Gateway Info**:
   ```bash
   terraform output api_gateway_ip
   ```

5. **Configure DNS**:
   - Point `api.ciel-social.eu` to the API gateway IP
   - Verify SSL certificate is working

6. **Test API Connectivity**:
   ```bash
   # Test iOS API key
   curl -H "Authorization: Bearer ios-app-key-here" \
        https://api.ciel-social.eu/health

   # Test Android API key
   curl -H "Authorization: Bearer android-app-key-here" \
        https://api.ciel-social.eu/health
   ```

7. **Implement in Apps**:
   - Add API keys to secure storage
   - Configure network clients
   - Implement certificate pinning
   - Add error handling

## 🚀 Mobile App Security Best Practices

| Category | Recommendation | Implementation |
|----------|---------------|----------------|
| **API Keys** | Never hardcode | Use build-time injection + secure storage |
| **Network** | HTTPS only | Disable cleartext, use certificate pinning |
| **Authentication** | JWT + Refresh | Secure token storage, regular rotation |
| **Error Handling** | Graceful degradation | Retry logic, user-friendly messages |
| **Rate Limiting** | Respect limits | Exponential backoff, request queuing |
| **Offline** | Cache & sync | Local database, conflict resolution |
| **Updates** | Secure delivery | Code signing, integrity checks |

## 🎯 Summary

This mobile-optimized security setup ensures that only your iOS and Android applications can access the API while maintaining high security standards. The configuration is specifically tailored for native mobile apps, with appropriate rate limits, no unnecessary CORS complexity, and robust authentication mechanisms.

**Key Features:**
- ✅ API Key Authentication
- ✅ Certificate Pinning
- ✅ WAF Protection
- ✅ Rate Limiting
- ✅ Secure Storage
- ✅ Error Handling
- ✅ Offline Support

The infrastructure is now ready for your mobile applications to connect securely!