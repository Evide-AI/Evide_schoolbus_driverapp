import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

// All Supabase reads/writes for the driver app live here, so screens stay
// focused on UI. RLS on the backend guarantees a driver only ever sees/writes
// their own bus's data, regardless of what this client asks for.
class DriverService {
  final SupabaseClient _db = Supabase.instance.client;

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Loads the signed-in driver's own profile row (to find their assigned bus).
  /// Returns null if this auth user isn't linked to a drivers row.
  Future<DriverProfile?> loadProfile() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _db
        .from('drivers')
        .select('id, name, bus_id, school_id, role')
        .eq('auth_user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return DriverProfile.fromMap(row);
  }

  /// Loads students on the given bus, merged with today's attendance so
  /// toggles reflect what's already been marked. Also resolves a signed photo
  /// URL for any student that has a photo.
  Future<List<Student>> loadStudentsWithAttendance(String busId) async {
    final studentRows = await _db
        .from('students')
        .select('id, full_name, admission_number, photo_path')
        .eq('bus_id', busId)
        .order('full_name');

    final students = (studentRows as List)
        .map((m) => Student.fromMap(m as Map<String, dynamic>))
        .toList();

    // Pull today's attendance for this bus and merge the present flags in.
    final attendanceRows = await _db
        .from('attendance')
        .select('student_id, present')
        .eq('bus_id', busId)
        .eq('date', _todayStr);

    final presentById = <String, bool>{};
    for (final r in attendanceRows as List) {
      presentById[r['student_id'] as String] = r['present'] as bool;
    }
    for (final s in students) {
      s.present = presentById[s.id] ?? false;
    }

    // Resolve signed URLs for students that have a photo (private bucket).
    final withPhotos = students.where((s) => s.photoPath != null).toList();
    if (withPhotos.isNotEmpty) {
      try {
        final signed = await _db.storage
            .from('student-photos')
            .createSignedUrls(withPhotos.map((s) => s.photoPath!).toList(), 3600);
        for (var i = 0; i < withPhotos.length; i++) {
          withPhotos[i].photoUrl = signed[i].signedUrl;
        }
      } catch (_) {
        // If signing fails, students just show their initial fallback.
      }
    }

    return students;
  }

  /// Marks (or updates) a single student's attendance for today.
  /// Uses upsert on the (student_id, date) unique key so tapping twice just
  /// flips the stored value rather than erroring on a duplicate.
  Future<void> setAttendance({
    required String studentId,
    required String busId,
    required String driverId,
    required bool present,
  }) async {
    await _db.from('attendance').upsert(
      {
        'student_id': studentId,
        'bus_id': busId,
        'date': _todayStr,
        'present': present,
        'marked_by': driverId,
        'marked_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'student_id,date',
    );
  }

  /// Saves attendance for many students at once (the "Save" button).
  /// Builds one batch of rows and upserts them in a single request.
  Future<void> saveAttendanceBatch({
    required String busId,
    required String driverId,
    required List<Student> students,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = students
        .map((s) => {
              'student_id': s.id,
              'bus_id': busId,
              'date': _todayStr,
              'present': s.present,
              'marked_by': driverId,
              'marked_at': now,
            })
        .toList();
    if (rows.isEmpty) return;
    await _db.from('attendance').upsert(rows, onConflict: 'student_id,date');
  }

  /// Sends a message from the bus to parents and/or the school office.
  ///
  /// `audience` decides who receives it: parents of students on this bus, or
  /// the office only (which always sees every message in the dashboard).
  /// Row-level security limits a driver to their own bus, and the database
  /// trigger queues the push.
  Future<void> sendNotification({
    required String schoolId,
    required String busId,
    required String driverId,
    required String title,
    required String body,
    required bool toParents,
    required bool toManagement,
  }) async {
    await _db.from('notifications').insert({
      'school_id': schoolId,
      'bus_id': busId,
      'sender_type': 'driver',
      'sender_id': driverId,
      'title': title,
      'body': body,
      'category': 'MESSAGE',
      'audience': toParents ? 'parents' : 'management',
    });
  }

  /// Messages for this driver: what the office sent to staff, plus what they
  /// sent themselves. Row-level security does the filtering.
  Future<List<StaffMessage>> loadMessages() async {
    final rows = await _db
        .from('notifications')
        .select('id, title, body, category, audience, sender_type, sender_name, created_at')
        .neq('category', 'ATTENDANCE')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((m) => StaffMessage.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Saves this phone's push token against the driver, so staff messages can
  /// reach it. Parents use the same table with parent_user_id instead.
  Future<void> registerDeviceToken(String token, String platform, String driverId) async {
    try {
      await _db.from('device_tokens').upsert({
        'driver_id': driverId,
        'fcm_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
    } catch (_) {
      // Never block sign-in over a token write.
    }
  }

  Future<void> removeDeviceToken(String token) async {
    try {
      await _db.from('device_tokens').delete().eq('fcm_token', token);
    } catch (_) {}
  }

  Future<void> signOut() => _db.auth.signOut();
}
