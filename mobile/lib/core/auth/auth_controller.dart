import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exceptions.dart';
import '../models/token_response.dart';
import '../models/user.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'token_storage.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthInitial());

  final Ref _ref;

  TokenStorage get _storage => _ref.read(tokenStorageProvider);
  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  // Returns true if the JWT's exp claim is in the past (or within `skewSeconds`).
  bool _isExpired(String accessToken, {int skewSeconds = 60}) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return true;
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final json = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is! int) return true;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return DateTime.now()
          .toUtc()
          .add(Duration(seconds: skewSeconds))
          .isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  Future<void> restore() async {
    debugPrint('AuthController.restore: start');
    try {
      final access = await _storage.readAccessToken();
      final userJson = await _storage.readUserJson();
      if (access == null ||
          access.isEmpty ||
          userJson == null ||
          userJson.isEmpty) {
        state = const AuthUnauthenticated();
        return;
      }

      // If the access token is expired or near-expiry, refresh proactively so
      // SignalR (and every other consumer) gets a fresh token from the start.
      if (_isExpired(access)) {
        debugPrint(
            'AuthController.restore: access token expired, refreshing...');
        final refreshToken = await _storage.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          await _storage.clear();
          state = const AuthUnauthenticated();
          return;
        }
        try {
          final fresh = await _repo.refresh(refreshToken);
          await _persist(fresh);
          unawaited(_repo.sessionStart().catchError((_) {}));
          state = AuthAuthenticated(fresh.user);
          debugPrint('AuthController.restore: refresh OK');
          return;
        } catch (e) {
          debugPrint('AuthController.restore: refresh failed: $e');
          await _storage.clear();
          state = const AuthUnauthenticated();
          return;
        }
      }

      final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      unawaited(_repo.sessionStart().catchError((_) {}));
      state = AuthAuthenticated(user);
      debugPrint('AuthController.restore: done with stored token');
    } catch (e, st) {
      debugPrint('AuthController.restore: error $e\n$st');
      state = const AuthUnauthenticated();
    }
  }

  Future<void> registerEmail(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AuthLoading();
    try {
      final token = await _repo.registerEmail(email, password, displayName);
      await _persist(token);
      state = AuthAuthenticated(token.user);
    } on ApiException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> loginEmail(String email, String password) async {
    state = const AuthLoading();
    try {
      final token = await _repo.loginEmail(email, password);
      await _persist(token);
      state = AuthAuthenticated(token.user);
    } on ApiException catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> loginGoogle() async {
    throw UnimplementedError('Google sign-in arrives in a later phase');
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      // ignore network failures during logout
    }
    await _storage.clear();
    state = const AuthUnauthenticated();
  }

  Future<void> forceLogout() async {
    await _storage.clear();
    state = const AuthUnauthenticated();
  }

  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }

  void updateUser(User user) {
    final current = state;
    if (current is AuthAuthenticated) {
      state = AuthAuthenticated(user);
      unawaited(
          _storage.writeUserJson(jsonEncode(user.toJson())).catchError((_) {}));
    }
  }

  Future<void> _persist(TokenResponse token) async {
    await _storage.write(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
      userJson: jsonEncode(token.user.toJson()),
    );
  }
}
