import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/moto_status.dart';

class ApiService {
  static final SupabaseClient client = Supabase.instance.client;

  static Future<MotoStatus?> fetchMotoStatus() async {
    final response = await client
        .from('moto_status')
        .select()
        .order('timestamp', ascending: false)
        .limit(1)
        .single();

    return MotoStatus.fromJson(response);
  }
}
