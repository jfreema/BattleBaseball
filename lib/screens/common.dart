import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

String fmtDate(DateTime? d) => d == null ? 'Date coming soon' : DateFormat('EEE, MMM d').format(d);
String fmtDateTime(DateTime? d) =>
    d == null ? '' : DateFormat('EEE, MMM d · h:mm a').format(d);
String fmtTime(DateTime? d) => d == null ? '' : DateFormat('h:mm a').format(d);
String fmtPrice(num? p) => p == null
    ? 'Price coming soon'
    : NumberFormat.simpleCurrency(decimalDigits: p % 1 == 0 ? 0 : 2).format(p);
String fmtValue(double v, String type) =>
    type == 'fastball' ? v.toStringAsFixed(v % 1 == 0 ? 0 : 1) : v.toStringAsFixed(2);

/// The hold's end, said gently: "until 4:05 PM" today, or with the day.
String holdUntil(DateTime? end) {
  if (end == null) return '';
  final now = DateTime.now();
  final sameDay = end.year == now.year && end.month == now.month && end.day == now.day;
  return sameDay
      ? 'until ${fmtTime(end)}'
      : 'until ${DateFormat('EEE h:mm a').format(end)}';
}

Color statusColor(String status) => switch (status) {
      'open' => BB.mint,
      'live' => BB.coral,
      'final' => BB.blue,
      'closed' => BB.lemon,
      'rainedOut' => BB.grape,
      _ => BB.rim,
    };

String statusLabel(String status) => switch (status) {
      'open' => 'Registration open',
      'live' => 'Happening now',
      'final' => 'Final',
      'closed' => 'Registration closed',
      'rainedOut' => 'Rained out',
      'draft' => 'Draft',
      _ => status,
    };

(String, Color) registrationLabel(Registration r) {
  if (r.holdEnded) return ('Checking payment', BB.lemon);
  return switch (r.status) {
    'held' => ('Spot held', BB.lemon),
    'offered' => ('Spot offered', BB.lemon),
    'paid' => ('All set', BB.mint),
    'checkedIn' => ('Checked in', BB.mint),
    'waitlisted' => ('Waitlist', BB.grape),
    'released' => ('Spot released', BB.rim),
    'cancelled' => ('Cancelled', BB.rim),
    'refundDue' => ('Refund on the way', BB.blue),
    'refunded' => ('Refunded', BB.blue),
    'credited' => ('Credit saved', BB.blue),
    _ => (r.status, BB.rim),
  };
}

/// An event in a list: name, date, place, and status.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.edge, this.onTap});
  final BBEvent event;
  final Color? edge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GumCard(
        edge: edge ?? statusColor(e.status),
        onTap: onTap ?? () => context.go('/events/${e.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow([if (e.ageGroups.isNotEmpty) e.ageGroups, 'Player showcase'].join(' · ')),
            Text(e.name, style: BB.title(22)),
            const SizedBox(height: 6),
            Text('${fmtDate(e.start)} · ${e.venue.isNotEmpty ? '${e.venue}, ' : ''}${e.city}',
                style: const TextStyle(color: BB.cardMuted, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusChip(statusLabel(e.status), color: statusColor(e.status)),
                StatusChip(fmtPrice(e.price), color: BB.page, fg: BB.text),
                if (e.skillsContest) const StatusChip('Skills contest', color: BB.grape),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A big Lilita readout: "71 MPH".
class Readout extends StatelessWidget {
  const Readout({super.key, required this.value, required this.unit, this.color = BB.lemon, this.size = 44});
  final String value;
  final String unit;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: BB.title(size, color: color)),
          const SizedBox(width: 6),
          Text(unit, style: BB.labelStyle(size * 0.38, color: BB.cardMuted)),
        ],
      );
}

Color awardColor(String type) => switch (type) {
      'mvp' => BB.lemon,
      'topPitcher' => BB.blue,
      'topHitter' => BB.coral,
      'eliteDefender' => BB.mint,
      _ => BB.grape,
    };

class AwardBadge extends StatelessWidget {
  const AwardBadge(this.award, {super.key});
  final Award award;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: awardColor(award.type),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BB.ink, width: 2),
          boxShadow: const [BoxShadow(color: BB.ink, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 18, color: BB.ink),
            const SizedBox(width: 6),
            Text(award.label, style: BB.labelStyle(14, color: BB.ink)),
          ],
        ),
      );
}

/// A loading spinner or an error, for StreamBuilders.
Widget? streamState(AsyncSnapshot<Object?> s) {
  if (s.hasError) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text("Couldn't load this. ${s.error}", style: const TextStyle(color: BB.accent)),
    );
  }
  if (!s.hasData) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
  return null;
}
