import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/driver_service.dart';
import '../theme.dart';
import 'messages_screen.dart';
import 'notify_screen.dart';
import '../services/push_service.dart';

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _service = DriverService();

  DriverProfile? _profile;
  List<Student> _students = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Tracks the last-saved present value per student, so we know what's dirty.
  final Map<String, bool> _savedState = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _service.loadProfile();
      if (profile == null) {
        setState(() {
          _error = 'This account is not set up as a driver. Contact your school office.';
          _loading = false;
        });
        return;
      }
      if (profile.busId == null) {
        setState(() {
          _profile = profile;
          _error = 'You are not assigned to a bus yet. Contact your school office.';
          _loading = false;
        });
        return;
      }
      final students = await _service.loadStudentsWithAttendance(profile.busId!);
      _savedState
        ..clear()
        ..addEntries(students.map((s) => MapEntry(s.id, s.present)));
      setState(() {
        _profile = profile;
        _students = students;
        _loading = false;
      });

      // Now that we know which driver this is, register the phone for the
      // school's staff messages.
      PushService.instance.attach(_service, profile.id);
    } catch (e) {
      setState(() {
        _error = 'Could not load your roster. Pull to retry.';
        _loading = false;
      });
    }
  }

  bool get _hasUnsavedChanges =>
      _students.any((s) => _savedState[s.id] != s.present);

  int get _dirtyCount =>
      _students.where((s) => _savedState[s.id] != s.present).length;

  int get _presentCount => _students.where((s) => s.present).length;

  void _toggle(Student student, bool value) {
    setState(() => student.present = value);
  }

  Future<void> _save() async {
    if (!_hasUnsavedChanges || _profile?.busId == null) return;
    setState(() => _saving = true);
    try {
      await _service.saveAttendanceBatch(
        busId: _profile!.busId!,
        driverId: _profile!.id,
        students: _students,
      );
      for (final s in _students) {
        _savedState[s.id] = s.present;
      }
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved'),
            backgroundColor: AppColors.go,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your connection and try again.')),
        );
      }
    }
  }

  Future<void> _openNotify() async {
    if (_profile == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotifyScreen(
          service: _service,
          schoolId: _profile!.schoolId,
          busId: _profile!.busId!,
          driverId: _profile!.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's roster"),
        actions: [
          if (!_loading && _error == null && _profile?.busId != null) ...[
            IconButton(
              icon: const Icon(Icons.mail_outline_rounded),
              tooltip: 'Messages',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MessagesScreen(service: _service),
              )),
            ),
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Send message',
              onPressed: _openNotify,
            ),
            _SaveButton(
              enabled: _hasUnsavedChanges && !_saving,
              saving: _saving,
              count: _dirtyCount,
              onPressed: _save,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await PushService.instance.detach(_service);
              await _service.signOut();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      _SummaryBar(
                        present: _presentCount,
                        total: _students.length,
                        driverName: _profile?.name ?? '',
                        unsaved: _dirtyCount,
                      ),
                      Expanded(
                        child: _students.isEmpty
                            ? const _EmptyView()
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                                itemCount: _students.length,
                                itemBuilder: (context, i) {
                                  final s = _students[i];
                                  return _StudentCard(
                                    student: s,
                                    dirty: _savedState[s.id] != s.present,
                                    onChanged: (v) => _toggle(s, v),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final int count;
  final VoidCallback onPressed;
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.accent,
          disabledBackgroundColor: Colors.white24,
          disabledForegroundColor: Colors.white54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: saving
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(saving ? 'Saving' : (count > 0 ? 'Save ($count)' : 'Save')),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int present;
  final int total;
  final String driverName;
  final int unsaved;
  const _SummaryBar({
    required this.present,
    required this.total,
    required this.driverName,
    required this.unsaved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$present / $total present',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('Marked by $driverName',
                    style: const TextStyle(fontSize: 13, color: AppColors.inkFaint)),
              ],
            ),
          ),
          if (unsaved > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$unsaved unsaved',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9A6B00))),
            ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final bool dirty;
  final ValueChanged<bool> onChanged;
  const _StudentCard({
    required this.student,
    required this.dirty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dirty ? AppColors.amber : AppColors.line,
          width: dirty ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14202B49),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Avatar(student: student),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(student.admissionNumber,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkFaint)),
                      const SizedBox(width: 8),
                      Text(
                        student.present ? 'Present' : 'Absent',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: student.present ? AppColors.go : AppColors.stop,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: student.present,
              activeColor: AppColors.go,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Student student;
  const _Avatar({required this.student});

  @override
  Widget build(BuildContext context) {
    final initial = student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?';
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentSoft,
        border: Border.all(
          color: student.present ? AppColors.go : AppColors.line,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: student.photoUrl != null
          ? Image.network(
              student.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialText(initial),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _initialText(initial),
            )
          : _initialText(initial),
    );
  }

  Widget _initialText(String initial) {
    return Center(
      child: Text(initial,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.accent)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.groups_outlined, size: 48, color: AppColors.inkFaint),
        SizedBox(height: 12),
        Center(
          child: Text('No students on your bus yet',
              style: TextStyle(color: AppColors.inkFaint)),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.inkFaint),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 15)),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
