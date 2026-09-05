import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/features/progression/domain/progression_profile.dart';

abstract interface class ProgressionRepository {
  Future<ProgressionProfile> fetchProfile();
}

final class SupabaseProgressionRepository implements ProgressionRepository {
  const SupabaseProgressionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ProgressionProfile> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ProgressionRepositoryException(
        'Для просмотра прогресса необходимо войти в аккаунт.',
      );
    }

    try {
      final response = await _client.rpc<dynamic>('get_progression_state_v2');
      if (response is! Map) {
        throw const ProgressionRepositoryException(
          'Сервер вернул некорректный профиль.',
        );
      }
      return ProgressionProfile.fromJson(
        Map<String, dynamic>.from(response),
        userId: user.id,
        isGuest: user.isAnonymous,
      );
    } on PostgrestException catch (error) {
      throw ProgressionRepositoryException(
        error.message.contains('UNAUTHORIZED')
            ? 'Сессия истекла. Войдите в аккаунт снова.'
            : 'Не удалось загрузить профиль.',
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw ProgressionRepositoryException(
        'Сервер вернул некорректный профиль.',
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw ProgressionRepositoryException(
        'Сервер вернул некорректный профиль.',
        technicalMessage: error.toString(),
      );
    } on ProgressionRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw ProgressionRepositoryException(
        'Не удалось загрузить профиль. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }
}

final class ProgressionRepositoryException implements Exception {
  const ProgressionRepositoryException(this.message, {this.technicalMessage});

  final String message;
  final String? technicalMessage;

  @override
  String toString() => technicalMessage == null
      ? 'ProgressionRepositoryException: $message'
      : 'ProgressionRepositoryException: $message ($technicalMessage)';
}
