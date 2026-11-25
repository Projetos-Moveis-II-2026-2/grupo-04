import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/generate_exercise_media.dart '
      '<pasta exercises do free-exercise-db> [id ...]',
    );
    exitCode = 64;
    return;
  }

  final source = args.first;
  final selectedIds = args.skip(1).toSet();
  final isSample = selectedIds.isNotEmpty;
  final output = p.join(
    'build',
    isSample ? 'exercise-media-sample' : 'exercise-media',
    'v1',
  );
  final catalog = jsonDecode(
    await File('assets/data/exercises.json').readAsString(),
  ) as List<dynamic>;
  final jobs = <({String id, List<String> frames})>[];
  final catalogIds = <String>{};
  final supportedId = RegExp(r'^[a-zA-Z0-9_-]+$');
  for (final exercise in catalog.cast<Map<String, dynamic>>()) {
    final id = exercise['id'] as String;
    catalogIds.add(id);
    if (isSample && !selectedIds.contains(id)) continue;
    final images = (exercise['images'] as List<dynamic>).cast<String>();
    if (images.isEmpty) continue;

    if (!supportedId.hasMatch(id) ||
        images.first != '$id/0.jpg' ||
        images.length > 2 ||
        (images.length == 2 && images.last != '$id/1.jpg')) {
      throw FormatException('Quadros inesperados no catálogo de $id.');
    }
    final frames = [
      for (final image in images) p.joinAll([source, ...image.split('/')]),
    ];
    for (final frame in frames) {
      if (!File(frame).existsSync()) {
        throw FileSystemException('Quadro indisponível', frame);
      }
    }
    jobs.add((id: id, frames: frames));
  }
  final unknownIds = selectedIds.difference(catalogIds);
  if (unknownIds.isNotEmpty) {
    throw ArgumentError('IDs fora do catálogo: ${unknownIds.join(', ')}');
  }

  final magick = Platform.environment['EXERCISE_MAGICK'] ?? 'magick';
  final queue = jobs.iterator;
  var thumbnails = 0;
  var details = 0;

  Future<void> generate() async {
    while (queue.moveNext()) {
      final job = queue.current;
      final directory = await Directory(p.join(output, job.id))
          .create(recursive: true);
      await _convert(magick, [
        job.frames.first,
        '-auto-orient',
        '-resize',
        '200x200>',
        '-strip',
        '-quality',
        '72',
        p.join(directory.path, 'thumbnail.webp'),
      ]);
      thumbnails++;

      if (job.frames.length == 2) {
        await _convert(magick, [
          ...job.frames,
          '-auto-orient',
          '-resize',
          '360x360>',
          '-alpha',
          'set',
          '-background',
          'none',
          '-gravity',
          'center',
          // Alinha quadros de tamanhos diferentes sem forçar um fundo quadrado.
          '-extent',
          '%[fx:max(u.w,v.w)]x%[fx:max(u.h,v.h)]',
          '+repage',
          '-strip',
          '-morph',
          '2',
          '(',
          '-clone',
          '2,1',
          ')',
          '-set',
          'delay',
          '%[fx:t==0 || t==3 ? 54 : 8]',
          // Evita que a codificação torne opacas as bordas transparentes.
          '-channel',
          'A',
          '-evaluate',
          'max',
          '0.4%',
          '+channel',
          '-loop',
          '0',
          '-quality',
          '72',
          p.join(directory.path, 'motion.webp'),
        ]);
        details++;
      }
    }
  }

  await Future.wait(List.generate(4, (_) => generate()));
  stdout.writeln(
    '$thumbnails miniaturas e $details imagens de detalhe em $output.',
  );
}

Future<void> _convert(String magick, List<String> arguments) async {
  final result = await Process.run(
    magick,
    arguments,
    environment: {'MAGICK_THREAD_LIMIT': '1'},
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      magick,
      arguments,
      result.stderr.toString(),
      result.exitCode,
    );
  }
}
