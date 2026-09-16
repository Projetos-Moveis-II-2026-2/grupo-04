import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';

import '../providers/water_providers.dart';
import '../widgets/daily_water_total_card.dart';
import '../widgets/edit_water_goal_dialog.dart';
import '../widgets/today_water_entries_list.dart';
import '../widgets/weekly_water_chart.dart';

/// Página principal de visualização de consumo de água (histórico diário e semanal).
class WaterHistoryPage extends ConsumerWidget {
  const WaterHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    final totalAsync = ref.watch(todayWaterTotalProvider);
    final entriesAsync = ref.watch(todayWaterEntriesProvider);
    final weeklyAsync = ref.watch(weeklyWaterSummaryProvider);
    final goal = ref.watch(dailyWaterGoalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hidratação',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Alterar meta diária',
            onPressed: () => EditWaterGoalDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Adicionar registro',
            onPressed: () => _showAddWaterDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayWaterTotalProvider);
          ref.invalidate(todayWaterEntriesProvider);
          ref.invalidate(weeklyWaterSummaryProvider);
          ref.invalidate(dailyWaterGoalProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Card com o Total Diário
              totalAsync.when(
                data: (total) => DailyWaterTotalCard(
                  totalMl: total,
                  goalMl: goal,
                  onEditGoal: () => EditWaterGoalDialog.show(context),
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Erro ao carregar total: $err'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Atalhos rápidos de adição (+250ml, +500ml)
              _QuickAddButtonsRow(
                onAdd: (amount) async {
                  if (user == null) return;
                  await ref.read(waterRepositoryProvider).addWaterIntake(
                        userId: user.id,
                        amountMl: amount,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('+$amount ml adicionados! 💧'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                onCustom: () => _showAddWaterDialog(context, ref),
              ),
              const SizedBox(height: 20),

              // 2. Mini gráfico da semana
              weeklyAsync.when(
                data: (summaries) => WeeklyWaterChart(
                  summaries: summaries,
                  dailyGoalMl: goal,
                ),
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Erro ao carregar gráfico semanal: $err'),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Lista de registros de hoje
              entriesAsync.when(
                data: (entries) => TodayWaterEntriesList(
                  entries: entries,
                  onDelete: (id) async {
                    await ref.read(waterRepositoryProvider).deleteWaterIntake(id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registro removido'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Erro ao carregar registros: $err'),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar'),
        onPressed: () => _showAddWaterDialog(context, ref),
      ),
    );
  }

  void _showAddWaterDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: '250');
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.water_drop, color: Color(0xFF0288D1)),
              SizedBox(width: 8),
              Text('Registrar Água'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Digite a quantidade consumida (em ml):'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    suffixText: 'ml',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: 350',
                  ),
                  validator: (val) {
                    final amount = int.tryParse(val ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Informe um volume válido maior que zero';
                    }
                    if (amount > 5000) {
                      return 'Volume máximo por registro: 5000 ml';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final amount = int.parse(controller.text);
                  final user = ref.read(currentUserProvider);
                  if (user != null) {
                    await ref
                        .read(waterRepositoryProvider)
                        .addWaterIntake(userId: user.id, amountMl: amount);
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('+$amount ml adicionados! 💧'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAddButtonsRow extends StatelessWidget {
  const _QuickAddButtonsRow({
    required this.onAdd,
    required this.onCustom,
  });

  final void Function(int amount) onAdd;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+250 ml'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => onAdd(250),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+500 ml'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => onAdd(500),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Outro valor',
          icon: const Icon(Icons.edit_note_rounded),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onCustom,
        ),
      ],
    );
  }
}

