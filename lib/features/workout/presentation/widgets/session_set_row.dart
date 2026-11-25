import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';

/// Formata carga sem casas decimais desnecessárias (60 → "60", 62.5 → "62.5").
String formatKg(double? kg) {
  if (kg == null) return '-';
  return kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : '$kg';
}

/// Cabeçalho das colunas de séries.
class SessionSetHeader extends StatelessWidget {
  const SessionSetHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('Série', style: style)),
          SizedBox(
            width: 64,
            child: Text('Anterior', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('Peso (kg)', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('Reps', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Linha de uma série: carga anterior lado a lado, ajuste rápido (+/-) de
/// peso e repetições e checkbox de conclusão (com HapticFeedback).
class SessionSetRow extends StatelessWidget {
  const SessionSetRow({
    super.key,
    required this.set,
    required this.previous,
    required this.onChanged,
    this.weightStep = 2.5,
  });

  final SessionSet set;
  final SessionSet? previous;
  final ValueChanged<SessionSet> onChanged;
  final double weightStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weight = set.weightKg ?? 0;
    final reps = set.reps ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: set.completed
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${set.setNumber}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              previous == null
                  ? '—'
                  : '${formatKg(previous!.weightKg)}×${previous!.reps ?? '-'}',
              key: ValueKey('previous-${set.id}'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _Stepper(
              key: ValueKey('weight-${set.id}'),
              label: 'Peso (kg)',
              display: formatKg(set.weightKg),
              onMinus: weight <= 0
                  ? null
                  : () => onChanged(
                      set.copyWith(
                        weightKg: (weight - weightStep).clamp(0, 9999),
                      ),
                    ),
              onPlus: () =>
                  onChanged(set.copyWith(weightKg: weight + weightStep)),
              onEdited: (v) {
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed != null && parsed >= 0) {
                  onChanged(set.copyWith(weightKg: parsed));
                }
              },
              decimal: true,
            ),
          ),
          Expanded(
            child: _Stepper(
              key: ValueKey('reps-${set.id}'),
              label: 'Repetições',
              display: set.reps?.toString() ?? '-',
              onMinus: reps <= 0
                  ? null
                  : () => onChanged(set.copyWith(reps: reps - 1)),
              onPlus: () => onChanged(set.copyWith(reps: reps + 1)),
              onEdited: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed >= 0) {
                  onChanged(set.copyWith(reps: parsed));
                }
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: Checkbox(
              key: ValueKey('done-${set.id}'),
              value: set.completed,
              onChanged: (value) {
                final done = value ?? false;
                if (done) HapticFeedback.mediumImpact();
                onChanged(set.copyWith(completed: done));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    super.key,
    required this.label,
    required this.display,
    required this.onMinus,
    required this.onPlus,
    required this.onEdited,
    this.decimal = false,
  });

  final String label;
  final String display;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onEdited;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Diminuir',
            visualDensity: VisualDensity.compact,
            onPressed: onMinus,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () async {
              final value = await _showEditDialog(context);
              if (value != null) onEdited(value);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  display,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Aumentar',
            visualDensity: VisualDensity.compact,
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }

  Future<String?> _showEditDialog(BuildContext context) {
    final controller = TextEditingController(
      text: display == '-' ? '' : display,
    );
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
            ),
          ],
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
