import Foundation
import CryptoKit
import CommonCrypto
import Security
import LocalAuthentication

enum KasaError: LocalizedError {
    case wrongPassword
    case corrupt
    case invalidBackup
    case keychain(OSStatus)
    case deviceAuthUnavailable
    case message(String)

    var errorDescription: String? {
        switch self {
        case .wrongPassword: return "Şifre hatalı."
        case .corrupt: return "Veri dosyası okunamadı."
        case .invalidBackup: return "Bu dosya bir Şifrelerim yedeği değil."
        case .keychain(let s): return "Anahtar Zinciri hatası (\(s))."
        case .deviceAuthUnavailable: return "Bu iPhone'da parola tanımlı değil. Face ID ile açmak için iPhone Ayarlar'dan bir parola belirleyin."
        case .message(let m): return m
        }
    }
}

enum KasaCrypto {
    static let iterations = 600_000

    static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "Rastgele sayı üretilemedi")
        return Data(bytes)
    }

    /// PBKDF2-HMAC-SHA256 ile 256 bit anahtar türetir
    static func deriveKey(password: String, salt: Data, iterations: Int) -> SymmetricKey {
        let passwordBytes = Array(password.utf8)
        let saltBytes = [UInt8](salt)
        let keyLength = 32
        let passwordLength = passwordBytes.count
        let saltLength = saltBytes.count
        var derived = [UInt8](repeating: 0, count: keyLength)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password, passwordLength,
            saltBytes, saltLength,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(iterations),
            &derived, keyLength
        )
        precondition(status == Int32(kCCSuccess), "Anahtar türetilemedi")
        return SymmetricKey(data: Data(derived))
    }

    static func deriveKeyAsync(password: String, salt: Data, iterations: Int) async -> SymmetricKey {
        await Task.detached(priority: .userInitiated) {
            KasaCrypto.deriveKey(password: password, salt: salt, iterations: iterations)
        }.value
    }

    static func seal(_ data: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(data, using: key)
        guard let combined = box.combined else { throw KasaError.corrupt }
        return combined
    }

    static func open(_ combined: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }

    static func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    // MARK: Yedek biçimi (iv + ciphertext||tag)

    static func sealWebFormat(_ data: Data, key: SymmetricKey) throws -> (iv: Data, ct: Data) {
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(data, using: key, nonce: nonce)
        let iv = nonce.withUnsafeBytes { Data($0) }
        return (iv, box.ciphertext + box.tag)
    }

    static func openWebFormat(iv: Data, ct: Data, key: SymmetricKey) throws -> Data {
        guard ct.count > 16 else { throw KasaError.corrupt }
        let nonce = try AES.GCM.Nonce(data: iv)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ct.prefix(ct.count - 16), tag: ct.suffix(16))
        return try AES.GCM.open(box, using: key)
    }
}

/// Face ID / Touch ID / iPhone parolası bilgileri (bir kez hesaplanır)
enum DeviceAuth {
    static let biometryType: LABiometryType = {
        let ctx = LAContext()
        var err: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        return ctx.biometryType
    }()

    static var isAvailable: Bool {
        var err: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
    }

    static var name: String {
        switch biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        default: return "iPhone parolası"
        }
    }

    static var icon: String {
        switch biometryType {
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        default: return "lock.iphone"
        }
    }

    /// Face ID ister; başarısız olursa iOS kendiliğinden iPhone parolasını önerir
    static func authenticate(reason: String) async throws -> LAContext {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Vazgeç"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { throw KasaError.deviceAuthUnavailable }
        _ = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        return ctx
    }
}

/// Veri anahtarını Anahtar Zinciri'nde, Face ID veya iPhone parolası olmadan okunamayacak şekilde saklar.
/// Yalnızca bu cihazda tutulur, iCloud'a veya yedeğe gitmez.
enum DeviceKeychain {
    private static let service = "kasa.vault.devicekey"
    private static let account = "vault"

    static func save(_ key: Data) throws {
        delete()
        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil,
                                                           kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                           .userPresence,
                                                           &cfError) else {
            throw KasaError.deviceAuthUnavailable
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key,
            kSecAttrAccessControl as String: access,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if status == errSecAuthFailed || status == errSecNotAvailable { throw KasaError.deviceAuthUnavailable }
            throw KasaError.keychain(status)
        }
    }

    static func load(context: LAContext) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { throw KasaError.keychain(status) }
        return data
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Önceki sürümün Face ID anahtarı (yalnızca geçiş için okunur)
enum LegacyBiometricKeychain {
    private static let service = "kasa.vault.key"
    private static let account = "vault"

    static func load(context: LAContext) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { throw KasaError.keychain(status) }
        return data
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension Data {
    var base64: String { base64EncodedString() }
}
