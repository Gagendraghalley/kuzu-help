import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

/// The only place in this feature that talks to Supabase about customers
/// getting in touch with workers (supabase/updates.sql, sections 5g and 7).
class ContactRepository {
  final SupabaseClient _db;
  ContactRepository(this._db);

  /// C3: the customer tapped Call or WhatsApp (a ContactMethod value). The
  /// worker is told someone is getting in touch, at most once a day.
  Future<void> recordContact(String workerId, String method) async {
    await _db.rpc('record_contact', params: {'worker_id': workerId, 'method': method});
  }

  /// C4: customers can only review workers they have called, messaged or
  /// sent a job request.
  Future<bool> hasContacted(String workerId) async {
    final row = await _db
        .from('worker_contacts')
        .select('worker_id')
        .eq('worker_id', workerId)
        .eq('customer_id', _db.auth.currentUser!.id)
        .maybeSingle();
    return row != null;
  }
}

final contactRepositoryProvider = Provider<ContactRepository>((ref) => ContactRepository(ref.watch(supabaseProvider)));
