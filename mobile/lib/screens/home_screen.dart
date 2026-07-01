import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/action_card.dart';
import 'activities_screen.dart';
import 'appointments_screen.dart';
import 'emergency_screen.dart';
import 'medications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UleamMed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hola, Roberto 👋',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¿Cómo te sientes hoy?',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MoodSelector(),
                  const SizedBox(height: 24),
                  Text('Acciones rápidas', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  ActionCard(
                    icon: Icons.medication,
                    title: 'Medicamentos',
                    subtitle: '2 de 4 tomados hoy',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MedicationsScreen()),
                    ),
                  ),
                  ActionCard(
                    icon: Icons.calendar_month,
                    title: 'Citas médicas',
                    subtitle: 'Próxima: 28 Jun con Dra. González',
                    color: AppColors.primaryLight,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
                    ),
                  ),
                  ActionCard(
                    icon: Icons.fitness_center,
                    title: 'Actividades del día',
                    subtitle: 'Caminata, estiramientos y más',
                    color: AppColors.primaryDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
                    ),
                  ),
                  ActionCard(
                    icon: Icons.emergency,
                    title: 'Emergencias',
                    subtitle: 'Contactos y llamada al 911',
                    color: const Color(0xFFC62828),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Resumen de hoy', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  const _SummaryRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodSelector extends StatefulWidget {
  @override
  State<_MoodSelector> createState() => _MoodSelectorState();
}

class _MoodSelectorState extends State<_MoodSelector> {
  int? _selectedMood;

  static const _moods = [
    (Icons.sentiment_very_satisfied, 'Bien'),
    (Icons.sentiment_neutral, 'Regular'),
    (Icons.sentiment_dissatisfied, 'Mal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu estado de ánimo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_moods.length, (index) {
              final isSelected = _selectedMood == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < _moods.length - 1 ? 8 : 0),
                  child: InkWell(
                    onTap: () => setState(() => _selectedMood = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.accent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _moods[index].$1,
                            color: isSelected ? Colors.white : AppColors.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _moods[index].$2,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(icon: Icons.medication, label: 'Medicamentos', value: '50%')),
        const SizedBox(width: 12),
        Expanded(child: _SummaryCard(icon: Icons.directions_walk, label: 'Actividad', value: '25%')),
        const SizedBox(width: 12),
        Expanded(child: _SummaryCard(icon: Icons.water_drop, label: 'Agua', value: '4/8')),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
