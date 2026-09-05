import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';

abstract interface class CityRepository {
  Future<CityStateData> fetchCity();

  Future<CityStateData> buildBuilding({
    required String code,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  });

  Future<CityStateData> moveBuilding({
    required String buildingId,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  });
}

final class SupabaseCityRepository implements CityRepository {
  const SupabaseCityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CityStateData> fetchCity() {
    return _stateRpc(
      functionName: 'get_city_state_v2',
      fallbackMessage: 'Не удалось загрузить город.',
    );
  }

  @override
  Future<CityStateData> buildBuilding({
    required String code,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) {
    return _stateRpc(
      functionName: 'build_city_building_v2',
      params: {
        'p_code': code,
        'p_position_x': position.x,
        'p_position_y': position.y,
        'p_rotation': rotation.degrees,
      },
      fallbackMessage: 'Не удалось построить здание.',
    );
  }

  @override
  Future<CityStateData> moveBuilding({
    required String buildingId,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) {
    return _stateRpc(
      functionName: 'move_city_building_v2',
      params: {
        'p_building_id': buildingId,
        'p_position_x': position.x,
        'p_position_y': position.y,
        'p_rotation': rotation.degrees,
      },
      fallbackMessage: 'Не удалось переместить здание.',
    );
  }

  Future<CityStateData> _stateRpc({
    required String functionName,
    required String fallbackMessage,
    Map<String, dynamic>? params,
  }) async {
    _requireAuthenticatedUser();

    try {
      final dynamic response = params == null
          ? await _client.rpc<dynamic>(functionName)
          : await _client.rpc<dynamic>(functionName, params: params);
      if (response is! Map) {
        throw const CityRepositoryException(
          'Сервер вернул некорректное состояние города.',
        );
      }
      return CityStateData.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (error) {
      throw CityRepositoryException(
        _messageForDatabaseError(error, fallback: fallbackMessage),
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
        '$fallbackMessage Проверьте подключение к сети.',
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
    if (message.contains('BUILDING_OVERLAP')) {
      return 'На этом участке уже есть постройка.';
    }
    if (message.contains('OUT_OF_BOUNDS')) {
      return 'Здание выходит за границы города.';
    }
    if (message.contains('BUILDING_LOCKED')) {
      return 'Это здание пока недоступно на вашем уровне.';
    }
    if (message.contains('BUILDING_NOT_FOUND')) {
      return 'Здание не найдено.';
    }
    if (message.contains('INVALID_BUILDING_CODE')) {
      return 'Неизвестный тип здания.';
    }
    if (message.contains('INVALID_POSITION')) {
      return 'Выбрана недопустимая позиция.';
    }
    if (message.contains('INVALID_ROTATION')) {
      return 'Выбран недопустимый поворот здания.';
    }
    if (message.contains('INVALID_BUILDING_ID')) {
      return 'Не удалось определить здание.';
    }
    if (message.contains('UNAUTHORIZED')) {
      return 'Сессия истекла. Войдите в аккаунт снова.';
    }
    if (message.contains('PROFILE_NOT_FOUND')) {
      return 'Профиль игрока не найден.';
    }
    if (message.contains('CITY_NOT_FOUND')) {
      return 'Город игрока не найден.';
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
