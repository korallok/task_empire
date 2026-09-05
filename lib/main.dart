import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/app.dart';
import 'package:task_empire/core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final config = SupabaseConfig.fromEnvironment();
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
    );
    runApp(AuthenticatedAppBootstrap(supabase: Supabase.instance.client));
  } on Object catch (error) {
    runApp(BootstrapFailureApp(error: error));
  }
}

class AuthenticatedAppBootstrap extends StatefulWidget {
  const AuthenticatedAppBootstrap({required this.supabase, super.key});

  final SupabaseClient supabase;

  @override
  State<AuthenticatedAppBootstrap> createState() =>
      _AuthenticatedAppBootstrapState();
}

class _AuthenticatedAppBootstrapState extends State<AuthenticatedAppBootstrap> {
  late Future<void> _authentication;

  @override
  void initState() {
    super.initState();
    _authentication = _ensureAuthenticated();
  }

  Future<void> _ensureAuthenticated() async {
    if (widget.supabase.auth.currentSession != null) return;
    await widget.supabase.auth.signInAnonymously();
  }

  void _retry() {
    setState(() => _authentication = _ensureAuthenticated());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _authentication,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapMaterialApp(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _BootstrapMaterialApp(
            child: _BootstrapError(
              message:
                  'Не удалось войти в игровой профиль. '
                  'Проверьте подключение и настройку Anonymous Sign-Ins в Supabase.',
              onRetry: _retry,
            ),
          );
        }
        return TaskEmpireApp(supabase: widget.supabase);
      },
    );
  }
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return _BootstrapMaterialApp(
      child: _BootstrapError(
        message:
            'Приложение не настроено. Передайте SUPABASE_URL и '
            'SUPABASE_PUBLISHABLE_KEY через --dart-define.\n\n$error',
      ),
    );
  }
}

class _BootstrapMaterialApp extends StatelessWidget {
  const _BootstrapMaterialApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SafeArea(child: child)),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
