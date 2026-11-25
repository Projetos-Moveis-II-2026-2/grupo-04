import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';

import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

/// Página de Onboarding e Configuração Inicial do Perfil do Usuário.
///
/// Apresenta um fluxo guiado em 3 passos:
/// 1. Nome e Peso corporal
/// 2. Meta diária de água
/// 3. Nível de experiência na musculação
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _waterGoalController;
  ExperienceLevel _selectedExperience = ExperienceLevel.beginner;

  static const _waterPresets = [1500, 2000, 2500, 3000];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _weightController = TextEditingController();
    _waterGoalController = TextEditingController(text: '2000');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _waterGoalController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
    } else if (_currentStep == 1) {
      if (!_step2FormKey.currentState!.validate()) return;
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitOnboarding() async {
    FocusScope.of(context).unfocus();

    final weightNormalized = _weightController.text.replaceAll(',', '.');
    final weight = double.tryParse(weightNormalized) ?? 0.0;
    final waterGoal = int.tryParse(_waterGoalController.text) ?? 2000;

    final success = await ref
        .read(onboardingNotifierProvider.notifier)
        .completeOnboarding(
          displayName: _nameController.text.trim(),
          bodyWeightKg: weight,
          dailyWaterGoalMl: waterGoal,
          experienceLevel: _selectedExperience,
        );

    if (!mounted) return;

    if (!success) {
      final errorState = ref.read(onboardingNotifierProvider);
      final errorMessage = errorState.hasError
          ? errorState.error.toString()
          : 'Ocorreu um erro ao salvar o perfil. Tente novamente.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Tentar novamente',
            textColor: Theme.of(context).colorScheme.onError,
            onPressed: _submitOnboarding,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onboardingState = ref.watch(onboardingNotifierProvider);
    final isLoading = onboardingState.isLoading;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0 && !isLoading) {
          _goToPreviousStep();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuração Inicial'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair da conta',
              onPressed: isLoading
                  ? null
                  : () => ref.read(authNotifierProvider.notifier).signOut(),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Barra de progresso dos passos
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Passo ${_currentStep + 1} de 3',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getStepLabel(_currentStep),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 3,
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (step) {
                    setState(() => _currentStep = step);
                  },
                  children: [
                    _buildStep1NameAndWeight(theme, colorScheme),
                    _buildStep2WaterGoal(theme, colorScheme),
                    _buildStep3Experience(theme, colorScheme),
                  ],
                ),
              ),
              // Botões inferiores de navegação
              _buildBottomActions(theme, colorScheme, isLoading),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepLabel(int step) {
    switch (step) {
      case 0:
        return 'Dados Pessoais';
      case 1:
        return 'Hidratação';
      case 2:
        return 'Experiência';
      default:
        return '';
    }
  }

  Widget _buildStep1NameAndWeight(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Bem-vindo ao Olimpus! 💪',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vamos configurar seu perfil para personalizar seus treinos e metas.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome completo ou como prefere ser chamado *',
                hintText: 'Ex: Matheus',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe seu nome';
                }
                if (value.trim().length < 2) {
                  return 'O nome deve ter pelo menos 2 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Peso corporal (kg) *',
                hintText: 'Ex: 75.5',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe seu peso';
                }
                final normalized = value.replaceAll(',', '.');
                final weight = double.tryParse(normalized);
                if (weight == null || weight <= 0) {
                  return 'Informe um peso válido maior que 0 kg';
                }
                if (weight > 400) {
                  return 'Informe um peso realista (máx. 400 kg)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2WaterGoal(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.water_drop,
                  color: Color(0xFF0288D1),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hidratação Diária',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'A água é fundamental para o desempenho muscular e recuperação. Escolha uma meta sugerida ou digite um valor entre 500 e 5000 ml.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Metas sugeridas:',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _waterPresets.map((preset) {
                final isSelected =
                    _waterGoalController.text == preset.toString();
                return ChoiceChip(
                  label: Text('$preset ml'),
                  avatar: const Icon(Icons.water_drop_outlined, size: 16),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _waterGoalController.text = preset.toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _waterGoalController,
              decoration: const InputDecoration(
                labelText: 'Meta diária personalizada *',
                hintText: 'Ex: 2200',
                prefixIcon: Icon(Icons.flag_outlined),
                suffixText: 'ml',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a meta de água';
                }
                final amount = int.tryParse(value);
                if (amount == null || amount < 500 || amount > 5000) {
                  return 'A meta de água deve estar entre 500 e 5000 ml';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Experience(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Nível de Experiência 🏋️',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione sua vivência com treinamento de força para calibrarmos os treinos.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildExperienceOption(
            theme: theme,
            colorScheme: colorScheme,
            level: ExperienceLevel.beginner,
            title: 'Iniciante',
            subtitle: 'Novo na musculação ou treinando há menos de 6 meses.',
            icon: Icons.fitness_center_outlined,
          ),
          const SizedBox(height: 12),
          _buildExperienceOption(
            theme: theme,
            colorScheme: colorScheme,
            level: ExperienceLevel.intermediate,
            title: 'Intermediário',
            subtitle: 'Treina com consistência há pelo menos 6 meses e domina as técnicas básicas.',
            icon: Icons.sports_gymnastics_outlined,
          ),
          const SizedBox(height: 12),
          _buildExperienceOption(
            theme: theme,
            colorScheme: colorScheme,
            level: ExperienceLevel.advanced,
            title: 'Avançado',
            subtitle: 'Treina há mais de 2 anos com grande intensidade e técnica consolidada.',
            icon: Icons.military_tech_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceOption({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ExperienceLevel level,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedExperience == level;

    return InkWell(
      onTap: () {
        setState(() => _selectedExperience = level);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2.0 : 1.0,
          ),
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.25)
              : colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isLoading,
  ) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              onPressed: isLoading ? null : _goToPreviousStep,
              child: const Text('Voltar'),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: FilledButton(
              onPressed: isLoading
                  ? null
                  : () {
                      if (_currentStep == 2) {
                        _submitOnboarding();
                      } else {
                        _goToNextStep();
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_currentStep == 2 ? 'Concluir' : 'Continuar'),
            ),
          ),
        ],
      ),
    );
  }
}
