// Plain data models mapping to Supabase rows.

class DriverProfile {
  final String id;
  final String name;
  final String? busId;
  final String schoolId;
  final String role;

  DriverProfile({
    required this.id,
    required this.name,
    required this.busId,
    required this.schoolId,
    required this.role,
  });

  factory DriverProfile.fromMap(Map<String, dynamic> m) {
    return DriverProfile(
      id: m['id'] as String,
      name: m['name'] as String,
      busId: m['bus_id'] as String?,
      schoolId: m['school_id'] as String,
      role: m['role'] as String,
    );
  }
}

class Student {
  final String id;
  final String fullName;
  final String admissionNumber;
  final String? photoPath;
  String? photoUrl; // signed URL, resolved after load
  bool present; // mutable — toggled in the UI, persisted to Supabase

  Student({
    required this.id,
    required this.fullName,
    required this.admissionNumber,
    required this.photoPath,
    required this.present,
    this.photoUrl,
  });

  factory Student.fromMap(Map<String, dynamic> m) {
    return Student(
      id: m['id'] as String,
      fullName: m['full_name'] as String,
      admissionNumber: m['admission_number'] as String,
      photoPath: m['photo_path'] as String?,
      present: false,
    );
  }
}

/// A message shown in the driver's inbox.
class StaffMessage {
  final String id;
  final String title;
  final String body;
  final String? audience;
  final String? senderType;
  final String? senderName;
  final DateTime createdAt;

  StaffMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.senderType,
    required this.senderName,
    required this.createdAt,
  });

  factory StaffMessage.fromMap(Map<String, dynamic> m) => StaffMessage(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        audience: m['audience'] as String?,
        senderType: m['sender_type'] as String?,
        senderName: m['sender_name'] as String?,
        createdAt:
            DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  bool get fromOffice => senderType != 'driver';

  String get fromLabel {
    if (senderName != null && senderName!.trim().isNotEmpty) return senderName!;
    return fromOffice ? 'School office' : 'You';
  }
}
