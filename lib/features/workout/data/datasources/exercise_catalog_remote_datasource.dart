import 'package:drift/drift.dart';
import 'package:olimpus/core/constants/exercise_media.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Porta remota para leitura do catálogo de exercícios (`exercise_library`)
/// e resolução de `external_id -> id (UUID)` no Supabase.
abstract interface class IExerciseCatalogRemoteDataSource {
  Future<List<ExerciseLibraryTableCompanion>> fetchCatalog();
  Future<String?> resolveExerciseUuid(String idOrExternalId);
}

class SupabaseExerciseCatalogRemoteDataSource
    implements IExerciseCatalogRemoteDataSource {
  SupabaseExerciseCatalogRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExerciseLibraryTableCompanion>> fetchCatalog() async {
    final rows = await _client
        .from('exercise_library')
        .select()
        .order('name')
        .limit(1000);

    // Antes da migração, gravar o catálogo remoto substituiria o pt-BR pelo
    // inglês e marcaria a revisão como aplicada. Tenta novamente na próxima abertura.
    if (rows.any((row) => row['name_en'] == null)) return const [];

    final now = DateTime.now().toUtc();
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          final id = row['id'] as String;
          final externalId = (row['external_id'] as String?) ?? id;
          final name = (row['name'] as String?) ?? externalId;
          final createdAtStr = row['created_at'] as String?;
          final updatedAt = createdAtStr != null
              ? (DateTime.tryParse(createdAtStr) ?? now)
              : now;

          return ExerciseLibraryTableCompanion.insert(
            id: id,
            remoteId: Value(id),
            externalId: externalId,
            name: name,
            force: Value(row['force'] as String?),
            level: Value(row['level'] as String?),
            mechanic: Value(row['mechanic'] as String?),
            equipment: Value(row['equipment'] as String?),
            primaryMuscles: Value(_joinArray(row['primary_muscles'])),
            secondaryMuscles: Value(_joinArray(row['secondary_muscles'])),
            instructions: Value(
              _joinArray(row['instructions'], separator: '\n'),
            ),
            category: Value(row['category'] as String?),
            imageUrls: Value(_normalizeImageUrls(row['image_urls'])),
            synced: const Value(true),
            updatedAt: updatedAt,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<String?> resolveExerciseUuid(String idOrExternalId) async {
    if (UuidV4.isValid(idOrExternalId)) return idOrExternalId;
    final row = await _client
        .from('exercise_library')
        .select('id')
        .eq('external_id', idOrExternalId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  static String? _joinArray(dynamic value, {String separator = ', '}) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      final items = value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return items.isEmpty ? null : items.join(separator);
    }
    return value.toString();
  }

  static String? _normalizeImageUrls(dynamic value) {
    if (value == null) return null;
    final List<String> rawList;
    if (value is List) {
      rawList = value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } else if (value is String && value.trim().isNotEmpty) {
      rawList = value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } else {
      return null;
    }

    if (rawList.isEmpty) return null;
    return rawList.map(ExerciseMedia.normalize).join(',');
  }
}
