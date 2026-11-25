import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/constants/api_endpoints.dart';
import 'package:olimpus/core/constants/exercise_media.dart';

const _base =
    '${ApiEndpoints.supabaseUrl}/storage/v1/object/public/exercise-media/v1';
const _legacyRawGithub =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
const _legacyJsDelivr =
    'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/';

void main() {
  group('ExerciseMedia', () {
    test('usa a base pública do bucket por padrão', () {
      expect(ExerciseMedia.baseUrl, _base);
    });

    test('monta a URL de um quadro a partir do caminho relativo', () {
      expect(
        ExerciseMedia.frameUrl('Dumbbell_Flyes/0.jpg'),
        '$_base/Dumbbell_Flyes/0.jpg',
      );
    });

    test('monta miniatura e animação com o id codificado', () {
      expect(
        ExerciseMedia.thumbnailUrl('Kettlebell Halo'),
        '$_base/Kettlebell%20Halo/thumbnail.webp',
      );
      expect(
        ExerciseMedia.motionUrl('Kettlebell Halo'),
        '$_base/Kettlebell%20Halo/motion.webp',
      );
    });

    group('normalize', () {
      test('reescreve URLs antigas do GitHub para o bucket', () {
        expect(
          ExerciseMedia.normalize('${_legacyRawGithub}Dumbbell_Flyes/0.jpg'),
          '$_base/Dumbbell_Flyes/0.jpg',
        );
      });

      test('reescreve URLs antigas do jsDelivr para o bucket', () {
        expect(
          ExerciseMedia.normalize('${_legacyJsDelivr}Dumbbell_Flyes/1.jpg'),
          '$_base/Dumbbell_Flyes/1.jpg',
        );
      });

      test('mantém URLs http(s) de outros destinos', () {
        const url = 'https://example.com/imagem.jpg';
        expect(ExerciseMedia.normalize(url), url);
      });

      test('mantém caminhos locais de assets', () {
        const url = 'assets/images/exercise.png';
        expect(ExerciseMedia.normalize(url), url);
      });

      test('converte caminho relativo em URL do bucket', () {
        expect(
          ExerciseMedia.normalize('Dumbbell_Flyes/0.jpg'),
          '$_base/Dumbbell_Flyes/0.jpg',
        );
      });
    });

    group('isFrame', () {
      test('reconhece o quadro relativo, legado e já normalizado', () {
        expect(
          ExerciseMedia.isFrame('Dumbbell_Flyes/0.jpg', 'Dumbbell_Flyes', 0),
          isTrue,
        );
        expect(
          ExerciseMedia.isFrame(
            '${_legacyRawGithub}Dumbbell_Flyes/0.jpg',
            'Dumbbell_Flyes',
            0,
          ),
          isTrue,
        );
        expect(
          ExerciseMedia.isFrame(
            '$_base/Dumbbell_Flyes/0.jpg',
            'Dumbbell_Flyes',
            0,
          ),
          isTrue,
        );
      });

      test('rejeita outro quadro ou outra URL', () {
        expect(
          ExerciseMedia.isFrame('Dumbbell_Flyes/1.jpg', 'Dumbbell_Flyes', 0),
          isFalse,
        );
        expect(
          ExerciseMedia.isFrame(
            'https://example.com/Dumbbell_Flyes/0.jpg',
            'Dumbbell_Flyes',
            0,
          ),
          isFalse,
        );
      });
    });
  });
}
