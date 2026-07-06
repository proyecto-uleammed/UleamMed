import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

/// Version del documento legal aceptado. Cambiala si actualizas el contenido.
const String kLegalVersion = '1.0';

/// Terminos, privacidad y consentimiento informado (PB-055/014).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.settings, this.showAccept = true});

  final AppSettingsController? settings;
  final bool showAccept;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminos y privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Section(
            icon: Icons.description,
            title: 'Terminos de uso',
            body:
                'UleamMed es una herramienta de apoyo para el cuidado y no '
                'reemplaza la atencion medica profesional. Usa la aplicacion '
                'como complemento y ante cualquier emergencia contacta a los '
                'servicios de salud.',
          ),
          _Section(
            icon: Icons.lock,
            title: 'Privacidad de tus datos',
            body:
                'Tu informacion de salud se guarda de forma cifrada en tu '
                'dispositivo y solo se comparte con los cuidadores que tu '
                'autorices y con el servidor para sincronizar. No vendemos ni '
                'compartimos tus datos con terceros.',
          ),
          _Section(
            icon: Icons.verified_user,
            title: 'Consentimiento informado',
            body:
                'Al aceptar, autorizas el tratamiento de tus datos de salud '
                'con el unico fin de recordarte tus medicamentos, citas y '
                'facilitar tu cuidado. Puedes revocar los permisos de tus '
                'cuidadores en cualquier momento desde la seccion Cuidadores.',
          ),
        ],
      ),
      bottomNavigationBar: (showAccept && settings != null)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedBuilder(
                  animation: settings!,
                  builder: (context, _) {
                    final accepted =
                        settings!.value.termsAcceptedVersion == kLegalVersion;
                    return FilledButton.icon(
                      onPressed: accepted
                          ? null
                          : () async {
                              await settings!.acceptTerms(kLegalVersion);
                              if (context.mounted) {
                                showAppSnackBar(
                                  context,
                                  'Gracias, terminos aceptados',
                                );
                                Navigator.maybePop(context);
                              }
                            },
                      icon: Icon(accepted ? Icons.check : Icons.done_all),
                      label: Text(
                        accepted ? 'Ya aceptaste los terminos' : 'Aceptar',
                      ),
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
