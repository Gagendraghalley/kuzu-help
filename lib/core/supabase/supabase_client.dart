import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single shared Supabase client. Repositories read it through this provider.
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
