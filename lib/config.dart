// Supabase connection config.
//
// The anon key is safe to ship in a client app — it's the public key, gated by
// the Row-Level Security policies in your database. Never put the service_role
// key in a Flutter app.
class SupabaseConfig {
  static const String url = 'https://rujjbkvqsqzholravzsx.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ1ampia3Zxc3F6aG9scmF2enN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxODQwNDIsImV4cCI6MjEwNDc2MDA0Mn0.eWqDNABawNDqurD-1OWrygNNewub05PHYyCOohT53bs';
}
