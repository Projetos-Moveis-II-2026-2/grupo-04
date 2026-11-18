import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:olimpus/core/utils/uuid_v4.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/workout/domain/entities/template_exercise_item.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';
import 'package:olimpus/features/workout/presentation/providers/workout_template_providers.dart';
import 'package:olimpus/features/workout/presentation/widgets/exercise_picker_sheet.dart';
import 'package:olimpus/features/workout/presentation/widgets/template_card.dart';

class TemplateFormPage extends ConsumerStatefulWidget {
  const TemplateFormPage({
    super.key,
    this.templateId,
    this.initialTemplate,
  });

  final String? templateId;
  final WorkoutTemplateEntity? initialTemplate;

  bool get isEditing => templateId != null || initialTemplate != null;

  @override
  ConsumerState<TemplateFormPage> createState() => _TemplateFormPageState();
}

class _TemplateFormPageState extends ConsumerState<TemplateFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String _resolvedTemplateId;
  List<TemplateExerciseItem> _exercises = <TemplateExerciseItem>[];
  bool _initializedFromRemote = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTemplate;
    _resolvedTemplateId =
        initial?.id ?? widget.templateId ?? UuidV4.generate();
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    if (initial != null) {
      _exercises = List<TemplateExerciseItem>.from(initial.exercises);
      _initializedFromRemote = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _applyLoadedTemplate(WorkoutTemplateEntity loaded) {
    if (_initializedFromRemote) return;
    _initializedFromRemote = true;
    _resolvedTemplateId = loaded.id;
    _nameController.text = loaded.name;
    _descriptionController.text = loaded.description ?? '';
    _exercises = List<TemplateExerciseItem>.from(loaded.exercises);
  }

  void _reindexExercises() {
    _exercises = [
      for (var i = 0; i < _exercises.length; i++)
        _exercises[i].copyWith(sortOrder: i),
    ];
  }

  Future<void> _onAddExercisesPressed() async {
    final picked = await showExercisePickerSheet(context);
    if (picked == null || picked.isEmpty) return;

    setState(() {
      for (final ex in picked) {
        _exercises.add(
          TemplateExerciseItem(
            id: UuidV4.generate(),
            templateId: _resolvedTemplateId,
            exerciseId: ex.id,
            exerciseName: ex.name,
            primaryMuscles: ex.primaryMuscles,
            equipment: ex.equipment,
            imageUrl: ex.firstImageUrl,
            sortOrder: _exercises.length,
            targetSets: 3,
            targetReps: 10,
          ),
        );
      }
      _reindexExercises();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final moved = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, moved);
      _reindexExercises();
    });
  }

  void _onRemoveExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _reindexExercises();
    });
  }

  void _onUpdateSets(int index, int delta) {
    final current = _exercises[index].targetSets;
    final next = (current + delta).clamp(1, 30);
    if (next == current) return;
    setState(() {
      _exercises[index] = _exercises[index].copyWith(targetSets: next);
    });
  }

  void _onUpdateReps(int index, int delta) {
    final current = _exercises[index].targetReps ?? 10;
    final next = (current + delta).clamp(1, 100);
    setState(() {
      _exercises[index] = _exercises[index].copyWith(targetReps: next);
    });
  }

  Future<void> _onSavePressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(currentUserProvider);
    final userId = widget.initialTemplate?.userId ?? user?.id ?? 'local-user';

    final entity = WorkoutTemplateEntity(
      id: _resolvedTemplateId,
      userId: userId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      exercises: [
        for (var i = 0; i < _exercises.length; i++)
          _exercises[i].copyWith(
            templateId: _resolvedTemplateId,
            sortOrder: i,
          ),
      ],
      synced: false,
      updatedAt: DateTime.now().toUtc(),
    );

    final ok = await ref
        .read(workoutTemplateActionNotifierProvider.notifier)
        .saveTemplate(entity);

    if (!mounted) return;
    if (ok) {
      if (widget.templateId != null) {
        ref.invalidate(workoutTemplateByIdProvider(widget.templateId!));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Ficha "${entity.name}" atualizada!'
                : 'Ficha "${entity.name}" criada!',
          ),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } else {
      final err = ref.read(workoutTemplateActionNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar ficha: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _onDeletePressed() async {
    final confirmed = await showDeleteTemplateConfirmationDialog(
      context,
      templateName: _nameController.text.trim().isEmpty
          ? 'esta ficha'
          : _nameController.text.trim(),
    );
    if (!confirmed || !mounted) return;

    final ok = await ref
        .read(workoutTemplateActionNotifierProvider.notifier)
        .deleteTemplate(_resolvedTemplateId);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ficha excluída.')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(workoutTemplateActionNotifierProvider);
    final isSaving = actionState.isLoading;

    if (widget.templateId != null && !_initializedFromRemote) {
      final asyncLoaded = ref.watch(
        workoutTemplateByIdProvider(widget.templateId!),
      );
      return asyncLoaded.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Editar Ficha')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          appBar: AppBar(title: const Text('Editar Ficha')),
          body: Center(child: Text('Erro ao carregar ficha: $err')),
        ),
        data: (loaded) {
          if (loaded == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Editar Ficha')),
              body: const Center(child: Text('Ficha não encontrada.')),
            );
          }
          _applyLoadedTemplate(loaded);
          return _buildFormScaffold(context, isSaving: isSaving);
        },
      );
    }

    return _buildFormScaffold(context, isSaving: isSaving);
  }

  Widget _buildFormScaffold(BuildContext context, {required bool isSaving}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Ficha' : 'Nova Ficha'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              tooltip: 'Excluir ficha',
              onPressed: isSaving ? null : _onDeletePressed,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome da ficha *',
                    hintText: 'Ex.: Treino A - Peito e Tríceps',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assignment_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da ficha';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Ex.: Foco em hipertrofia e progressão de carga',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Exercícios (${_exercises.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: isSaving ? null : _onAddExercisesPressed,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar exercícios'),
                    ),
                  ],
                ),
                if (_exercises.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.fitness_center_outlined,
                          size: 40,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum exercício adicionado à ficha.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toque em "Adicionar exercícios" para escolher na biblioteca.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Arraste pelo ícone lateral para reordenar os exercícios.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          itemCount: _exercises.length,
          onReorder: _onReorder,
          itemBuilder: (context, index) {
            final item = _exercises[index];
            return Card(
              key: ValueKey(item.id),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.exerciseName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.primaryMuscles != null &&
                                  item.primaryMuscles!.isNotEmpty)
                                Text(
                                  item.primaryMuscles!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: colorScheme.error,
                          ),
                          tooltip: 'Remover exercício',
                          onPressed: () => _onRemoveExercise(index),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.drag_handle,
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _CounterControl(
                            label: 'Séries alvo',
                            value: item.targetSets,
                            onDecrement: () => _onUpdateSets(index, -1),
                            onIncrement: () => _onUpdateSets(index, 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CounterControl(
                            label: 'Reps alvo',
                            value: item.targetReps ?? 10,
                            onDecrement: () => _onUpdateReps(index, -1),
                            onIncrement: () => _onUpdateReps(index, 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: isSaving ? null : _onSavePressed,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              widget.isEditing ? 'Salvar alterações' : 'Criar ficha',
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterControl extends StatelessWidget {
  const _CounterControl({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.remove),
                onPressed: onDecrement,
              ),
              Text(
                '$value',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.add),
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
