import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_exceptions.dart';
import 'package:dio/dio.dart';

final globalNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (_) => GlobalKey<NavigatorState>(),
);

final globalMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (_) => GlobalKey<ScaffoldMessengerState>(),
);

void showAppSnackBar(WidgetRef ref, String message) {
  final messenger = ref.read(globalMessengerKeyProvider).currentState;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showAppSnackBarFromRef(Ref ref, String message) {
  final messenger = ref.read(globalMessengerKeyProvider).currentState;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Show a user-friendly error message for exceptions.
///
/// Maps known API/network errors to short, non-technical messages.
void showAppError(WidgetRef ref, Object error, {String? fallback}) {
  String message;
  if (error is ApiException) {
    if (error is NetworkException || error.statusCode == 0) {
      message = 'Network error. Check your connection.';
    } else if (error is RateLimitedException) {
      message = error.message;
    } else if (error.statusCode >= 500) {
      message = 'Server error. Please try again later.';
    } else {
      // Use server-provided message for 4xx errors when present, but keep it short.
      message = error.message.isNotEmpty
          ? error.message
          : (fallback ?? 'Something went wrong.');
    }
  } else if (error is DioException && error.error is ApiException) {
    final ae = error.error as ApiException;
    showAppError(ref, ae, fallback: fallback);
    return;
  } else {
    message = fallback ?? 'Something went wrong.';
  }

  final messenger = ref.read(globalMessengerKeyProvider).currentState;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Return a concise, user-friendly message for an error object.
String friendlyErrorMessage(Object error, {String? fallback}) {
  if (error is ApiException) {
    if (error is NetworkException || error.statusCode == 0) {
      return 'Network error. Check your connection.';
    }
    if (error is RateLimitedException) return error.message;
    if (error.statusCode >= 500) return 'Server error. Please try again later.';
    return error.message.isNotEmpty
        ? error.message
        : (fallback ?? 'Something went wrong.');
  }
  if (error is DioException && error.error is ApiException) {
    return friendlyErrorMessage(error.error as ApiException,
        fallback: fallback);
  }
  final raw = error.toString();
  if (raw.isEmpty) return fallback ?? 'Something went wrong.';
  // Try to extract message after last colon or common prefixes
  final dioMatch =
      RegExp(r'DioException[^:]*:\s*(.+)', dotAll: true).firstMatch(raw);
  if (dioMatch != null) return dioMatch.group(1)!.trim();
  final apiMatch =
      RegExp(r'ApiException\(\d+\):\s*(.+)', dotAll: true).firstMatch(raw);
  if (apiMatch != null) return apiMatch.group(1)!.trim();
  final parts = raw.split(':');
  if (parts.length > 1) return parts.last.trim();
  return raw.trim();
}
