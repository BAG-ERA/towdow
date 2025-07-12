import 'package:openid_client/openid_client.dart';
import 'package:hive/hive.dart';
import '../models/caldav_account.dart';

class AuthTokenProvider {
  /// Returns a valid (non-expired) access token for the given account.
  static Future<String> getValidToken(CaldavAccount account) async {
    final now = DateTime.now().toUtc();
    if (account.accessToken != null && account.tokenExpiry != null && account.tokenExpiry!.isAfter(now.add(const Duration(seconds: 60)))) {
      return account.accessToken!;
    }
    // Refresh via OIDC refresh_token
    if (account.refreshToken == null || account.issuerUrl == null || account.clientId == null) {
      return account.accessToken ?? '';
    }
    try {
      final issuer = await Issuer.discover(Uri.parse(account.issuerUrl!));
      final client = Client(issuer, account.clientId!);
      final cred = client.createCredential(refreshToken: account.refreshToken);
      final token = await cred.getTokenResponse();
      // update Hive
      final updated = account.copyWith(
        accessToken: token.accessToken,
        tokenExpiry: DateTime.now().toUtc().add(token.expiresIn ?? const Duration(hours: 1)),
        refreshToken: token.refreshToken ?? account.refreshToken,
      );
      // Use dynamic box to avoid type mismatch if box was opened without type parameter
      final box = Hive.box('accounts');
      await box.put(account.id, updated);
      return token.accessToken ?? '';
    } catch (_) {
      return account.accessToken ?? '';
    }
  }

  /// Convenience by accountId
  static Future<String> getTokenByAccountId(String accountId) async {
    final box = Hive.box('accounts');
    final acc = box.get(accountId) as CaldavAccount?;
    if (acc == null) return '';
    return getValidToken(acc);
  }
} 