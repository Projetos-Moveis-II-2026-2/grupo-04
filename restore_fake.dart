import 'dart:io';

void main() {
  final Map<String, List<Map<String, String>>> exercisesByMuscle = {
    'peito': [
      {'name': 'Supino Reto com Barra', 'folder': 'Barbell_Bench_Press'},
      {'name': 'Crucifixo Inclinado', 'folder': 'Incline_Dumbbell_Flye'},
      {'name': 'Supino com Halteres', 'folder': 'Dumbbell_Bench_Press'},
      {'name': 'Supino Declinado', 'folder': 'Decline_Barbell_Bench_Press'},
      {'name': 'Crossover no Cabo', 'folder': 'Cable_Crossover'},
    ],
    'costas': [
      {'name': 'Barra Fixa', 'folder': 'Pull-up'},
      {'name': 'Puxada Frontal', 'folder': 'Lat_Pulldown'},
      {'name': 'Remada Curvada com Barra', 'folder': 'Barbell_Row'},
      {'name': 'Remada Baixa', 'folder': 'Seated_Cable_Row'},
      {'name': 'Remada Unilateral', 'folder': 'Dumbbell_Row'},
    ],
    'ombros': [
      {'name': 'Desenvolvimento com Halteres', 'folder': 'Dumbbell_Shoulder_Press'},
      {'name': 'Elevação Lateral', 'folder': 'Lateral_Raise'},
      {'name': 'Elevação Frontal', 'folder': 'Front_Raise'},
      {'name': 'Remada Alta', 'folder': 'Upright_Row'},
      {'name': 'Crucifixo Inverso', 'folder': 'Reverse_Flye'},
    ],
    'bíceps': [
      {'name': 'Rosca Direta com Barra', 'folder': 'Barbell_Curl'},
      {'name': 'Rosca Alternada', 'folder': 'Dumbbell_Curl'},
      {'name': 'Rosca Martelo', 'folder': 'Hammer_Curl'},
      {'name': 'Rosca Scott', 'folder': 'Preacher_Curl'},
      {'name': 'Rosca Concentrada', 'folder': 'Concentration_Curl'},
    ],
    'tríceps': [
      {'name': 'Tríceps Pulley', 'folder': 'Triceps_Pushdown'},
      {'name': 'Tríceps Francês', 'folder': 'Overhead_Triceps_Extension'},
      {'name': 'Tríceps Testa', 'folder': 'Skull_Crusher'},
      {'name': 'Mergulho', 'folder': 'Triceps_Dip'},
      {'name': 'Supino Fechado', 'folder': 'Close_Grip_Bench_Press'},
    ],
    'pernas': [
      {'name': 'Agachamento Livre', 'folder': 'Barbell_Squat'},
      {'name': 'Leg Press 45', 'folder': 'Leg_Press'},
      {'name': 'Cadeira Extensora', 'folder': 'Leg_Extension'},
      {'name': 'Mesa Flexora', 'folder': 'Lying_Leg_Curl'},
      {'name': 'Stiff', 'folder': 'Romanian_Deadlift'},
    ],
    'panturrilhas': [
      {'name': 'Gêmeos em Pé', 'folder': 'Standing_Calf_Raise'},
      {'name': 'Gêmeos Sentado', 'folder': 'Seated_Calf_Raise'},
      {'name': 'Panturrilha no Leg Press', 'folder': 'Leg_Press_Calf_Raise'},
      {'name': 'Panturrilha Burrinho', 'folder': 'Donkey_Calf_Raise'},
      {'name': 'Panturrilha Unilateral', 'folder': 'Single_Leg_Calf_Raise'},
    ],
    'abdômen': [
      {'name': 'Abdominal Supra', 'folder': 'Crunch'},
      {'name': 'Prancha', 'folder': 'Plank'},
      {'name': 'Elevação de Pernas', 'folder': 'Leg_Raise'},
      {'name': 'Giro Russo', 'folder': 'Russian_Twist'},
      {'name': 'Abdominal no Cabo', 'folder': 'Cable_Crunch'},
    ],
  };

  final buffer = StringBuffer();
  buffer.writeln("import '../../domain/entities/exercise.dart';");
  buffer.writeln();
  buffer.writeln("class ExerciseRemoteDataSourceFake {");
  buffer.writeln("  Future<List<Exercise>> fetchExercises() async {");
  buffer.writeln("    await Future.delayed(const Duration(milliseconds: 500));");
  buffer.writeln("    final now = DateTime.now();");
  buffer.writeln("    return [");

  int idCounter = 1;
  for (var entry in exercisesByMuscle.entries) {
    final muscle = entry.key;
    buffer.writeln("      // \${muscle.toUpperCase()}");
    for (var ex in entry.value) {
      final name = ex['name']!;
      final folder = ex['folder']!;
      
      final url0 = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$folder/0.gif';
      final url1 = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$folder/1.gif';
      final urlStr = '$url0,$url1';
      
      buffer.writeln("      Exercise(");
      buffer.writeln("        id: '$idCounter',");
      buffer.writeln("        externalId: 'ext_$idCounter',");
      buffer.writeln("        name: '$name',");
      buffer.writeln("        primaryMuscles: '$muscle',");
      buffer.writeln("        imageUrls: '$urlStr',");
      buffer.writeln("        instructions: '1. Prepare-se para $name.\\n2. Execute o movimento com cuidado.',");
      buffer.writeln("        synced: true,");
      buffer.writeln("        updatedAt: now,");
      buffer.writeln("      ),");
      idCounter++;
    }
  }

  buffer.writeln("    ];");
  buffer.writeln("  }");
  buffer.writeln("}");

  final file = File('lib/features/exercise/data/datasources/exercise_remote_datasource_fake.dart');
  file.writeAsStringSync(buffer.toString());
  print('Restored exercise_remote_datasource_fake.dart');
}
