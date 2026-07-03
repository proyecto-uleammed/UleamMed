import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  static const _activities = [
  _Activity(
    title: 'Caminata ligera',
    duration: '20 min',
    time: '09:00',
    completed: true,
    icon: Icons.directions_walk,
  ),
  _Activity(
    title: 'Ejercicios de estiramiento',
    duration: '15 min',
    time: '11:00',
    completed: false,
    icon: Icons.self_improvement,
  ),
  _Activity(
    title: 'Lectura / pasatiempo',
    duration: '30 min',
    time: '15:00',
    completed: false,
    icon: Icons.menu_book,
  ),
  _Activity(
    title: 'Hidratación',
    duration: '8 vasos de agua',
    time: 'Todo el día',
    completed: false,
    icon: Icons.water_drop,
  ),
];

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Actividades del Día')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryLight,
                AppColors.primary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Buen día, Roberto!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 de 4 actividades completadas',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._activities.map((activity) => _ActivityCard(activity: activity)),
      ],
    ),
  );
  }
}

class _Activity {
  const _Activity({
    required this.title,
    required this.duration,
    required this.time,
    required this.completed,
    required this.icon,
  });

  final String title;
  final String duration;
  final String time;
  final bool completed;
  final IconData icon;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: activity.completed
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                activity.icon,
                color: activity.completed ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${activity.duration} · ${activity.time}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              activity.completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: activity.completed ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
