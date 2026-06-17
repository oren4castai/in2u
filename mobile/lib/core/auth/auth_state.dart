import '../models/user.dart';

sealed class AuthState {
  const AuthState();

  bool get isInitial => this is AuthInitial;
  bool get isLoading => this is AuthLoading;
  bool get isAuthenticated => this is AuthAuthenticated;
  bool get isUnauthenticated => this is AuthUnauthenticated;

  User? get userOrNull =>
      this is AuthAuthenticated ? (this as AuthAuthenticated).user : null;
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}

class AuthError extends AuthState {
  final String message;
  final AuthState? previous;
  const AuthError(this.message, [this.previous]);
}
