import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:stockflow/reusable_widgets/secrets.dart';

class EncryptionHelper {
  static final _key = encrypt.Key.fromUtf8(encryptionKey);
  static final _iv = encrypt.IV.fromLength(16);

  static String encryptText(String plainText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  static String decryptText(String encryptedText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
    return decrypted;
  }
}