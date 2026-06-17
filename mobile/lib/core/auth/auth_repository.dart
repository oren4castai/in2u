import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/token_response.dart';
import '../models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<TokenResponse> registerEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authEmailRegister,
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
    return _parseToken(resp);
  }

  Future<TokenResponse> loginEmail(String email, String password) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authEmailLogin,
      data: {'email': email, 'password': password},
    );
    return _parseToken(resp);
  }

  Future<TokenResponse> loginGoogle(String idToken) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authOAuthGoogle,
      data: {'idToken': idToken},
    );
    return _parseToken(resp);
  }

  Future<TokenResponse> refresh(String refreshToken) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authRefresh,
      data: {'refreshToken': refreshToken},
    );
    return _parseToken(resp);
  }

  Future<void> logout() async {
    await _dio.post<void>(ApiEndpoints.authLogout);
  }

  Future<bool> sessionStart() async {
    final resp =
        await _dio.post<Map<String, dynamic>>(ApiEndpoints.authSessionStart);
    return resp.data?['resumed'] == true;
  }

  Future<User> getMe() async {
    final resp = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
    final data = resp.data;
    if (data == null) {
      throw ApiException(resp.statusCode ?? 0, 'Empty response');
    }
    return User.fromJson(data);
  }

  Future<User> updateMe({
    String? displayName,
    String? bio,
    int? birthYear,
    String? gender,
    String? preferGender,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (birthYear != null) body['birthYear'] = birthYear;
    if (gender != null) body['gender'] = gender;
    if (preferGender != null) body['preferGender'] = preferGender;
    final resp =
        await _dio.patch<Map<String, dynamic>>(ApiEndpoints.me, data: body);
    return User.fromJson(resp.data!);
  }

  Future<User> uploadPhoto(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: filename, contentType: DioMediaType('image', 'jpeg')),
    });
    final resp = await _dio.post<Map<String, dynamic>>(ApiEndpoints.mePhoto,
        data: formData);
    return User.fromJson(resp.data!);
  }

  Future<User> deletePhoto() async {
    final resp = await _dio.delete<Map<String, dynamic>>(ApiEndpoints.mePhoto);
    return User.fromJson(resp.data!);
  }

  Future<Uint8List?> fetchMyPhotoBytes(String userGuid) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final resp = await _dio.get<List<int>>(
        '${ApiEndpoints.photo(userGuid)}?t=$ts',
        options: Options(responseType: ResponseType.bytes),
      );
      if (resp.data == null || resp.data!.isEmpty) return null;
      return Uint8List.fromList(resp.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  TokenResponse _parseToken(Response<Map<String, dynamic>> resp) {
    final data = resp.data;
    if (data == null) {
      throw ApiException(resp.statusCode ?? 0, 'Empty response');
    }
    return TokenResponse.fromJson(data);
  }
}
