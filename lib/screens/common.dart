// Formatters, wording and the few widgets more than one screen needs.
import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/repo.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
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
String fmtValue(double v, String type) => switch (type) {
      'homeRuns' => v.toStringAsFixed(0),
      'fastball' => v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
      _ => v.toStringAsFixed(2),
    };

/// The hold's end, said gently: "until 4:05 PM" today, or with the day.
String holdUntil(DateTime? end) {
  if (end == null) return '';
  final now = DateTime.now();
  final sameDay = end.year == now.year && end.month == now.month && end.day == now.day;
  return sameDay
      ? 'until ${fmtTime(end)}'
      : 'until ${DateFormat('EEE h:mm a').format(end)}';
}

String statusLabel(String status) => switch (status) {
      'open' => 'Registration open',
      'live' => 'Happening now',
      'final' => 'Final',
      'closed' => 'Registration closed',
      'rainedOut' => 'Rained out',
      'draft' => 'Draft',
      _ => status,
    };

/// What a family sees for a registration, and the pill color to show it on.
(String, Color) registrationLabel(Registration r) {
  if (r.holdEnded) return ('Still matching', BB.cream);
  final label = switch (r.status) {
    'held' || 'offered' => 'Confirming payment',
    'paid' => 'All set',
    'checkedIn' => 'Checked in',
    'waitlisted' => 'Waitlist',
    'released' => 'Released',
    'cancelled' => 'Cancelled',
    'refundDue' => 'Refund on the way',
    'refunded' => 'Refunded',
    'credited' => 'Credit saved',
    _ => r.status,
  };
  return (label, BB.cream);
}

/// What a small award seal carries: a star for MVP (drawn by AwardSeal),
/// the award's initials otherwise.
String awardMark(String type) => sealMark(type);

/// The small caps line under a player's name: "CLASS OF 2031 · RHP".
String playerLine(PublicProfile p) => [
      if (p.gradYear != null) 'CLASS OF ${p.gradYear}',
      if (p.positionCodes.isNotEmpty) p.positionCodes.first,
    ].join(' · ');

/// A tick label for the fastball chart: "SPR 11U" from "Spring Showcase"
/// and "11U".
String tickLabel(String eventName, [String divisionName = '']) {
  String firstWord(String s) => s.trim().split(RegExp(r'\s+')).first.toUpperCase();
  final word = firstWord(eventName);
  final season = switch (word) {
    'SPRING' => 'SPR',
    'SUMMER' => 'SUM',
    'WINTER' => 'WIN',
    'AUTUMN' => 'FALL',
    _ => word.length > 5 ? word.substring(0, 5) : word,
  };
  return [season, firstWord(divisionName)].where((s) => s.isNotEmpty).join(' ');
}

/// A family's registration as a paper row: the player, the showcase and age
/// group, and a status pill. When a hold has ended it offers "I already
/// paid". Tapping the row opens the showcase.
class RegistrationRow extends StatelessWidget {
  const RegistrationRow(this.r, {super.key, this.showEvent = true});

  final Registration r;

  /// Off on the showcase's own screen, where its name would only repeat.
  final bool showEvent;

  Future<void> _alreadyPaid(BuildContext context) async {
    try {
      await Repo.instance.flagAlreadyPaid(r);
    } catch (_) {
      // Sample data, or offline: the thanks still stands and staff still check.
    }
    if (context.mounted) toast(context, "Thanks. We'll look for it.");
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = registrationLabel(r);
    final sub = [if (showEvent && r.eventName.isNotEmpty) r.eventName, r.divisionName]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final askPaid = r.holdEnded && !r.alreadyPaid;
    return Paper(
      onTap: () => context.go('/events/${r.eventId}'),
      sink: !askPaid,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BB.labelStyle(19, color: BB.ink, height: 1.1),
                    ),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(sub, style: BB.bodyStyle(14, color: BB.ink2, height: 1.25)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Pill(label, color: color),
            ],
          ),
          if (askPaid)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: BBButton.paper('I already paid', small: true, onPressed: () => _alreadyPaid(context)),
            ),
        ],
      ),
    );
  }
}

/// How a tab's first screen starts on phones: the wordmark, 62 tall, with
/// room for one thing at the right. On desktop the top bar carries the
/// wordmark, so this is only a little air.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (BB.isWide(context)) return const SizedBox(height: 12);
    // Sample data says so in place of whatever else would sit here.
    final right = Repo.stampDemo ? const Stamp('SAMPLE DATA') : trailing;
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          const Wordmark(),
          const SizedBox(width: 12),
          Expanded(child: Align(alignment: Alignment.centerRight, child: right)),
        ],
      ),
    );
  }
}

/// The top of a pushed screen: a back chevron with the parent's name, and
/// room for one thing beside it and one at the right. Going back defaults to
/// the path one level up ("/players/abc" to "/players").
class BackHeader extends StatelessWidget {
  const BackHeader(this.label, {super.key, this.onBack, this.beside, this.trailing});

  final String label;
  final VoidCallback? onBack;

  /// Sits right after the label (the SAMPLE stamp).
  final Widget? beside;
  final Widget? trailing;

  void _up(BuildContext context) {
    final segments = GoRouterState.of(context).uri.pathSegments;
    context.go(segments.length <= 1 ? '/' : '/${segments.take(segments.length - 1).join('/')}');
  }

  @override
  Widget build(BuildContext context) {
    final back = Transform.translate(
      offset: const Offset(-6, 0),
      child: Pressable(
        onTap: onBack ?? () => _up(context),
        label: 'Back to $label',
        builder: (context, down, focused) => Opacity(
          opacity: down ? 0.7 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BBIcon(BBGlyph.back, size: 24, color: BB.cream),
                const SizedBox(width: 4),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BB.labelStyle(17, height: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Sample data says so at the right, as the tab screens do.
    final right = trailing ?? (Repo.stampDemo && !BB.isWide(context) ? const Stamp('SAMPLE DATA') : null);
    return SizedBox(
      height: BB.isWide(context) ? 48 : 62,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(child: back),
                if (beside != null) ...[const SizedBox(width: 6), beside!],
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: 12), right],
        ],
      ),
    );
  }
}
/// What an address that leads nowhere shows, and what a screen shows for a
/// player or showcase that isn't there.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
        children: [
          const SizedBox(height: 56),
          Text('Nothing here.', style: BB.title(BB.isWide(context) ? 44 : 34, drop: 4)),
          const SizedBox(height: 6),
          TextLink('Home', onTap: () => context.go('/')),
        ],
      );
}
