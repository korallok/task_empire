import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';

abstract interface class CityRepository {
  Future<CityStateData> fetchCity();

  Future<void> buildBuilding({
    required CityBuildingType type,
    required CityTileCoordinate tile,
  });

  Future<void> upgradeBuilding(String buildingId);
}

final class SupabaseCityRepository implements CityRepository {
  const SupabaseCityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CityStateData> fetchCity() async {
    _requireAuthenticatedUser();

    try {
      final response = await _client.rpc<dynamic>('get_city_state');
      if (response is! Map) {
        throw const CityRepositoryException(
          'Сервер вернул некорректное состояние города.',
        );
      }
      return CityStateData.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (error) {
      throw CityRepositoryException(
        _messageForDatabaseError(
          error,
          fallback: 'Не удалось загрузить город.',
        ),
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw CityRepositoryException(
        'Сервер вернул некорректное состояние города.',
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw CityRepositoryException(
        'Сервер вернул некорректное состояние города.',
        technicalMessage: error.toString(),
      );
    } on CityRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw CityRepositoryException(
        'Не удалось загрузить город. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  Future<void> buildBuilding({
    required CityBuildingType type,
    required CityTileCoordinate tile,
  }) async {
    _requireAuthenticatedUser();
    try {
      await _client.rpc<dynamic>(
        'build_city_building',
        params: {
          'p_type': type.databaseValue,
          'p_iso_x': tile.x,
          'p_iso_y': tile.y,
        },
      );
    } on PostgrestException catch (error) {
      throw CityRepositoryException(
        _messageForDatabaseError(
          error,
          fallback: 'Не удалось построить здание.',
        ),
        technicalMessage: error.message,
      );
    } on Exception catch (error) {
      throw CityRepositoryException(
        'Не удалось построить здание. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  Future<void> upgradeBuilding(String buildingId) async {
    _requireAuthenticatedUser();
    try {
      await _client.rpc<dynamic>(
        'upgrade_city_building',
        params: {'p_building_id': buildingId},
      );
    } on PostgrestException catch (error) {
      throw CityRepositoryException(
        _messageForDatabaseError(
          error,
          fallback: 'Не удалось улучшить здание.',
        ),
        technicalMessage: error.message,
      );
    } on Exception catch (error) {
      throw CityRepositoryException(
        'Не удалось улучшить здание. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  void _requireAuthenticatedUser() {
    if (_client.auth.currentUser == null) {
      throw const CityRepositoryException(
        'Для управления городом необходимо войти в аккаунт.',
      );
    }
  }

  String _messageForDatabaseError(
    PostgrestException error, {
    required String fallback,
  }) {
    final message = error.message;
    if (message.contains('INSUFFICIENT_GOLD')) {
      return 'Недостаточно золота.';
    }
    if (message.contains('TILE_OCCUPIED')) {
      return 'Эта клетка уже занята.';
    }
    if (message.contains('MAX_LEVEL_REACHED')) {
      return 'Здание уже достигло максимального уровня.';
    }
    if (message.contains('BUILDING_NOT_FOUND')) {
      return 'Здание не найдено.';
    }
    if (message.contains('INVALID_TILE')) {
      return 'Выбрана недопустимая клетка.';
    }
    if (message.contains('INVALID_BUILDING_TYPE')) {
      return 'Неизвестный тип здания.';
    }
    if (message.contains('UNAUTHORIZED')) {
      return 'Сессия истекла. Войдите в аккаунт снова.';
    }
    if (message.contains('PROFILE_NOT_FOUND')) {
      return 'Профиль игрока не найден.';
    }
    return fallback;
  }
}

final class CityRepositoryException implements Exception {
  const CityRepositoryException(this.message, {this.technicalMessage});

  final String message;
  final String? technicalMessage;

  @override
  String toString() => technicalMessage == null
      ? 'CityRepositoryException: $message'
      : 'CityRepositoryException: $message ($technicalMessage)';
}
