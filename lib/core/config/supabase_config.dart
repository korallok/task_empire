final class SupabaseConfig {
  const SupabaseConfig._({required this.url, required this.publishableKey});

  factory SupabaseConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final key = publishableKey.isNotEmpty ? publishableKey : legacyAnonKey;

    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be provided via '
        '--dart-define. SUPABASE_ANON_KEY is accepted for legacy projects.',
      );
    }

    final uri = Uri.tryParse(url);
    final isLoopback =
        uri?.host == 'localhost' ||
        uri?.host == '127.0.0.1' ||
        uri?.host == '::1';
    final hasAllowedScheme =
        uri?.scheme == 'https' || (uri?.scheme == 'http' && isLoopback);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        !hasAllowedScheme) {
      throw StateError(
        'SUPABASE_URL must use HTTPS. HTTP is allowed only for a local '
        'Supabase instance.',
      );
    }

    return SupabaseConfig._(url: url, publishableKey: key);
  }

  final String url;
  final String publishableKey;
}
