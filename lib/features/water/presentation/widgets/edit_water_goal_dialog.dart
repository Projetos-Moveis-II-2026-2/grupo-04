import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ConsumerState<EditWaterGoalDialog> createState() => _EditWaterGoalDialogState();
}

class _EditWaterGoalDialogState extends ConsumerState<EditWaterGoalDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  static const _presets = [1500, 2000, 2500, 3000];

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                if (amount == null || amount < 500) {
                  return 'A meta mínima recomendada é 500 ml';
                }
                if (amount > 10000) {
                  return 'A meta máxima permitida é 10.000 ml';
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

