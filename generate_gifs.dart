import 'dart:io';
import 'dart:convert';

void main() {
  final dir = Directory('assets/gifs');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Transparent 1x1 GIF
  final String base64Gif = "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
  final List<int> bytes = base64Decode(base64Gif);

  final exercises = [
    // Peito
    'supino_inclinado_halteres', 'supino_reto_barra', 'crucifixo_reto', 'flexao_bracos', 'peck_deck',
    // Costas
    'puxada_frontal', 'remada_curvada', 'remada_baixa', 'barra_fixa', 'pulldown',
    // Ombros
    'desenvolvimento_halteres', 'elevacao_lateral', 'elevacao_frontal', 'crucifixo_inverso', 'encolhimento',
    // Bíceps
    'rosca_direta', 'rosca_alternada', 'rosca_scott', 'rosca_martelo', 'rosca_concentrada',
    // Tríceps
    'triceps_pulley', 'triceps_testa', 'triceps_coice', 'triceps_mergulho', 'triceps_frances',
    // Pernas
    'agachamento_livre', 'leg_press_45', 'cadeira_extensora', 'stiff', 'mesa_flexora',
    // Panturrilhas
    'gemeos_em_pe', 'gemeos_sentado', 'panturrilha_leg_press', 'panturrilha_unilateral', 'panturrilha_smith',
    // Abdômen
    'abdominal_supra', 'abdominal_infra', 'prancha_abdominal', 'abdominal_obliquo', 'abdominal_remador'
  ];

  for (var ex in exercises) {
    final file = File('assets/gifs/$ex.gif');
    if (!file.existsSync()) {
      file.writeAsBytesSync(bytes);
      print('Criado: assets/gifs/$ex.gif');
    }
  }
}
