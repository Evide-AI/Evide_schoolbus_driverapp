import 'package:flutter/material.dart';
import '../services/driver_service.dart';
import '../theme.dart';

// Quick presets a driver can tap; each fills the title. They can also add
// custom text in the message field.
const _presets = [
  ('Running late', 'The bus is running late today. Thank you for your patience.'),
  ('Traffic delay', 'The bus is delayed due to traffic. We will arrive as soon as possible.'),
  ('Breakdown', 'The bus has a breakdown. We are arranging a replacement and will update you shortly.'),
  ('Reached stop', 'The bus has reached the stop.'),
  ('Starting now', 'The bus is starting the trip now.'),
];

class NotifyScreen extends StatefulWidget {
  final DriverService service;
  final String schoolId;
  final String busId;
  final String driverId;

  const NotifyScreen({
    super.key,
    required this.service,
    required this.schoolId,
    required this.busId,
    required this.driverId,
  });

  @override
  State<NotifyScreen> createState() => _NotifyScreenState();
}

class _NotifyScreenState extends State<NotifyScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  // Recipient choice: 0 = Parents, 1 = Management, 2 = Both
  int _recipient = 0;
  String? _activePreset;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String label, String body) {
    setState(() {
      _activePreset = label;
      _titleCtrl.text = label;
      if (_bodyCtrl.text.trim().isEmpty) _bodyCtrl.text = body;
    });
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a title, or pick a quick message above.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.sendNotification(
        schoolId: widget.schoolId,
        busId: widget.busId,
        driverId: widget.driverId,
        title: title,
        body: body.isEmpty ? title : body,
        toParents: _recipient == 0 || _recipient == 2,
        toManagement: _recipient == 1 || _recipient == 2,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent'), backgroundColor: AppColors.go),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Could not send. Check your connection and try again.';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send notification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Send to',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          _RecipientPicker(
            value: _recipient,
            onChanged: (v) => setState(() => _recipient = v),
          ),
          const SizedBox(height: 24),

          const Text('Quick messages',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final active = _activePreset == p.$1;
              return GestureDetector(
                onTap: () => _applyPreset(p.$1, p.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: active ? AppColors.accent : AppColors.line),
                  ),
                  child: Text(p.$1,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.inkSoft)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          const Text('Title',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Running 15 minutes late'),
          ),
          const SizedBox(height: 18),

          const Text('Message',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Add any details (optional)…'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.stopSoft, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.stop)),
            ),
          ],

          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send notification'),
          ),
        ],
      ),
    );
  }
}

class _RecipientPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _RecipientPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['Parents', 'Management', 'Both'];
    return Row(
      children: List.generate(labels.length, (i) {
        final active = value == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              margin: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.accentSoft : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? AppColors.accent : AppColors.line, width: active ? 1.5 : 1),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.accent : AppColors.inkSoft)),
            ),
          ),
        );
      }),
    );
  }
}
