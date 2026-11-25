/// Rótulos em português para exibição dos campos categóricos do catálogo de exercícios.
///
/// Os dados armazenados no banco continuam com as chaves originais em inglês
/// para preservar filtros e consultas; apenas a camada de apresentação traduz
/// esses valores.
library;

/// Rótulos para os 17 grupos musculares do catálogo.
const Map<String, String> muscleLabels = {
  'abdominals': 'Abdômen',
  'abductors': 'Abdutores',
  'adductors': 'Adutores',
  'biceps': 'Bíceps',
  'calves': 'Panturrilhas',
  'chest': 'Peito',
  'forearms': 'Antebraços',
  'glutes': 'Glúteos',
  'hamstrings': 'Posteriores de coxa',
  'lats': 'Dorsais',
  'lower back': 'Lombar',
  'middle back': 'Costas (meio)',
  'neck': 'Pescoço',
  'quadriceps': 'Quadríceps',
  'shoulders': 'Ombros',
  'traps': 'Trapézio',
  'triceps': 'Tríceps',
};

/// Agrupamento de chaves musculares em inglês usado pelos chips de filtro.
///
/// Mantém as chaves em inglês nos valores para casar com `primaryMuscles` e
/// `secondaryMuscles` armazenados no banco local.
const Map<String, List<String>> muscleGroupTranslation = {
  'Peito': ['chest'],
  'Costas': ['lats', 'middle back', 'lower back'],
  'Ombros': ['shoulders', 'traps'],
  'Pernas': ['quadriceps', 'hamstrings', 'glutes', 'adductors', 'abductors'],
  'Panturrilhas': ['calves'],
  'Bíceps': ['biceps'],
  'Tríceps': ['triceps'],
  'Abdômen': ['abdominals'],
  'Antebraços': ['forearms'],
  'Pescoço': ['neck'],
};

/// Rótulos para nível de dificuldade.
const Map<String, String> levelLabels = {
  'beginner': 'Iniciante',
  'intermediate': 'Intermediário',
  'expert': 'Avançado',
};

/// Rótulos para equipamento.
const Map<String, String> equipmentLabels = {
  'barbell': 'Barra',
  'dumbbell': 'Halter',
  'cable': 'Cabo',
  'machine': 'Máquina',
  'kettlebells': 'Kettlebell',
  'bands': 'Elástico',
  'e-z curl bar': 'Barra W',
  'medicine ball': 'Medicine ball',
  'exercise ball': 'Bola suíça',
  'foam roll': 'Rolo de espuma',
  'body only': 'Peso corporal',
  'other': 'Outro',
};

/// Rótulos para mecânica do movimento.
const Map<String, String> mechanicLabels = {
  'compound': 'Composto',
  'isolation': 'Isolado',
};

/// Rótulos para tipo de força.
const Map<String, String> forceLabels = {
  'pull': 'Puxar',
  'push': 'Empurrar',
  'static': 'Estático',
};

/// Rótulos para categoria do exercício.
const Map<String, String> categoryLabels = {
  'strength': 'Força',
  'stretching': 'Alongamento',
  'plyometrics': 'Pliométrico',
  'powerlifting': 'Powerlifting',
  'olympic weightlifting': 'Levantamento olímpico',
  'strongman': 'Strongman',
  'cardio': 'Cardio',
};

String _lookupLabel(
  String? raw,
  Map<String, String> labels, {
  String emptyFallback = '—',
}) {
  if (raw == null) return emptyFallback;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return emptyFallback;

  final normalized = trimmed.toLowerCase();
  final match = labels[normalized];
  if (match != null) return match;

  return _capitalize(trimmed);
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

/// Traduz um único grupo muscular para português.
String muscleLabel(String? raw, {String emptyFallback = '—'}) =>
    _lookupLabel(raw, muscleLabels, emptyFallback: emptyFallback);

/// Traduz uma lista de músculos separada por vírgula (ex.: `"chest, triceps"`).
String muscleListLabel(String? raw, {String emptyFallback = '—'}) {
  if (raw == null || raw.trim().isEmpty) return emptyFallback;

  final items = raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .map((item) => muscleLabel(item, emptyFallback: emptyFallback))
      .toList(growable: false);

  if (items.isEmpty) return emptyFallback;
  return items.join(', ');
}

/// Traduz o nível de dificuldade para português.
String levelLabel(String? raw, {String emptyFallback = '—'}) =>
    _lookupLabel(raw, levelLabels, emptyFallback: emptyFallback);

/// Traduz o equipamento para português.
String equipmentLabel(String? raw, {String emptyFallback = '—'}) =>
    _lookupLabel(raw, equipmentLabels, emptyFallback: emptyFallback);

/// Traduz a mecânica do exercício para português.
String mechanicLabel(String? raw, {String emptyFallback = '—'}) =>
    _lookupLabel(raw, mechanicLabels, emptyFallback: emptyFallback);

/// Traduz o tipo de força para português.
String forceLabel(String? raw, {String emptyFallback = '—'}) =>
    _lookupLabel(raw, forceLabels, emptyFallback: emptyFallback);

/// Traduz a categoria do exercício para português.
String categoryLabel(String? raw, {String emptyFallback = '—'}) =>
    _lookupLabel(raw, categoryLabels, emptyFallback: emptyFallback);
