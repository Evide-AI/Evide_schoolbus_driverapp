import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/driver_service.dart';
import '../theme.dart';

/// Messages the school office sent to bus staff, plus what this bus sent out.
class MessagesScreen extends StatefulWidget {
  final DriverService service;
  const MessagesScreen({super.key, required this.service});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<StaffMessage> _items = [];
  bool _loading = true;
  String? _error;

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
      final items = await widget.service.loadMessages();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load messages. Pull down to try again.';
        _loading = false;
      });
    }
  }

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMMM').format(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.inkSoft)),
                        const SizedBox(height: 14),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          _EmptyMessages(),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final m = _items[i];
                            final showDay = i == 0 ||
                                _dayLabel(_items[i - 1].createdAt) != _dayLabel(m.createdAt);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDay)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                                    child: Text(
                                      _dayLabel(m.createdAt),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.inkFaint,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MessageCard(message: m),
                                ),
                              ],
                            );
                          },
                        ),
                ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final StaffMessage message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromOffice = message.fromOffice;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fromOffice ? AppColors.accentSoft : AppColors.paper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              fromOffice ? Icons.campaign_rounded : Icons.send_rounded,
              size: 20,
              color: fromOffice ? AppColors.accent : AppColors.inkFaint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
                if (message.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.body,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.inkSoft, height: 1.45),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${message.fromLabel}  ·  ${DateFormat('h:mm a').format(message.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 44, color: AppColors.inkFaint),
            SizedBox(height: 14),
            Text('No messages yet',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
            SizedBox(height: 6),
            Text(
              'Notices from the school office will appear here, along with the '
              'messages you send from this bus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
