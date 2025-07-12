import 'dart:typed_data';

/// Represents the encryption context – either user-specific or project-specific.
abstract class EncryptionScope {
  const EncryptionScope();
}

class UserScope extends EncryptionScope {
  const UserScope();
}

class ProjectScope extends EncryptionScope {
  final String projectUuid;
  const ProjectScope(this.projectUuid);
}

/// For now, encryption/decryption are NO-OP to keep the integration path simple.
/// Real AES-256 implementation will replace these once crypto key management is
/// finalised.
class EncryptionUtil {
  static Future<Uint8List> encrypt(Uint8List data, {required EncryptionScope scope}) async {
    // TODO: Implement AES-256 encryption.
    return data;
  }

  static Future<List<int>> decrypt(List<int> encrypted) async {
    // TODO: Implement AES-256 decryption.
    return encrypted;
  }
} 