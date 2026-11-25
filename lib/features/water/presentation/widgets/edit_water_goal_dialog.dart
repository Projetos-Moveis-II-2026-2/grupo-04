import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/water_goal_calculator.dart';
import '../providers/water_providers.dart';

/// Modal para visualização e alteração da meta diária de consumo de água.
class EditWaterGoalDialog extends ConsumerStatefulWidget {
  const EditWaterGoalDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const EditWaterGoalDialog(),
    );
  }

  @override
  ConsumerState<EditWaterGoalDialog> createState() =>
      _EditWaterGoalDialogState();
}

class _EditWaterGoalDialogState extends ConsumerState<EditWaterGoalDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  static const _presets = AppConstants.waterGoalPresets;

  @override
  void initState() {
    super.initState();
    final currentGoal = ref.read(dailyWaterGoalProvider);
    _controller = TextEditingController(text: currentGoal.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatWeight(double weight) {
    if (weight % 1 == 0) {
      return weight.toInt().toString();
    }
    return weight.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider);
    final weightKg = profileAsync.value?.bodyWeightKg;
    final suggestion = WaterGoalCalculator.calculateSuggestion(weightKg);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.flag_rounded, color: Color(0xFF0288D1)),
          SizedBox(width: 10),
          Text('Meta Diária de Água'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escolha uma meta recomendada ou digite um valor personalizado:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                return ActionChip(
                  label: Text('$preset ml'),
                  avatar: const Icon(Icons.water_drop, size: 16),
                  onPressed: () {
                    setState(() {
                      _controller.text = preset.toString();
                    });
                  },
                );
              }).toList(),
            ),
            if (suggestion != null && weightKg != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sugestão para ${_formatWeight(weightKg)} kg: $suggestion ml',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _controller.text = suggestion.toString();
                        });
                      },
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Meta diária',
                suffixText: 'ml',
                border: OutlineInputBorder(),
                hintText: 'Ex: 2200',
              ),
              validator: (val) {
                final amount = int.tryParse(val ?? '');
                if (amount == null || amount < AppConstants.minWaterGoalMl) {
                  return 'A meta mínima recomendada é ${AppConstants.minWaterGoalMl} ml';
                }
                if (amount > AppConstants.maxWaterGoalMl) {
                  return 'A meta máxima permitida é ${AppConstants.maxWaterGoalMl} ml';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              final newGoal = int.parse(_controller.text);
              await ref.read(dailyWaterGoalProvider.notifier).setGoal(newGoal);
              ref.invalidate(userProfileProvider);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Meta diária alterada para $newGoal ml! 🎯'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
