import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');

    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('WARNING: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env');
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('SupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  static String? get currentUserId => client.auth.currentUser?.id;

  static bool get isLoggedIn => client.auth.currentUser != null;

  static Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUp(String email, String password, String name, String phone) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'phone': phone},
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<bool> isAdmin() async {
    final userId = currentUserId;
    if (userId == null) return false;

    final response = await client
        .from('profiles')
        .select('is_admin')
        .eq('id', userId)
        .maybeSingle();

    return response?['is_admin'] == true;
  }
}
