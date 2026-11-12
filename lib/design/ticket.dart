// A showcase, printed as a ticket: a date stub torn along a dashed
// perforation, the name and place, and a lower stub with the price and the
// one action.
import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

class ShowcaseTicket extends StatelessWidget {
  const ShowcaseTicket({
    super.key,
    required this.event,
    this.spotsLeft,
    this.onTap,
    this.onReserve,
    this.large,
  });

  final BBEvent event;

  /// Open spots across the showcase's age groups. Shown as a mint pill
  /// while registration is open; left out when null.
  final int? spotsLeft;

  /// Tapping anywhere on the ticket (and "Results" on a finished one).
  final VoidCallback? onTap;

  /// Shows the small coral Reserve button while registration is open.
  final VoidCallback? onReserve;

  /// Desktop sizes. Follows the breakpoint when left out.
  final bool? large;

  static String _money(num p) =>
      NumberFormat.simpleCurrency(decimalDigits: p % 1 == 0 ? 0 : 2).format(p);

  @override
  Widget build(BuildContext context) {
    final big = large ?? BB.isWide(context);
    final e = event;
    final done = e.status == 'final';
    final open = e.isOpen;
    final spots = spotsLeft;

    final Widget? pill = switch (e.status) {
      'open' when spots != null && spots > 0 =>
        Pill(spots == 1 ? '1 spot left' : '$spots spots left', color: BB.mint),
      'open' when spots != null => const Pill('Waitlist'),
      'closed' => const Pill('Registration closed'),
      'live' => const Pill('Today'),
      'rainedOut' => const Pill('Rained out'),
      'final' => const Pill('Final'),
      'draft' => const Pill('Draft'),
      _ => null,
    };
    final Widget? action = open && onReserve != null
        ? BBButton.primary('Reserve', small: true, onPressed: onReserve)
        : done && onTap != null
            ? TextLink('Results', color: BB.ink, onTap: onTap)
            : null;

    final facts = [
      if (e.price != null && !done) Text(_money(e.price!), style: BB.lilita(big ? 22 : 19, height: 1)),
      if (e.ageGroups.isNotEmpty) Text(e.ageGroups, style: BB.labelStyle(14.5, color: BB.ink, height: 1)),
    ];
    final lower = Padding(
      padding: big ? const EdgeInsets.fromLTRB(20, 12, 16, 12) : const EdgeInsets.fromLTRB(14, 12, 12, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          // On a phone the pill has its own line and the action sits level
          // with it, so every ticket in a list is set the same way.
          crossAxisAlignment: big ? CrossAxisAlignment.center : CrossAxisAlignment.end,
          children: [
            Expanded(
              child: big
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [...facts, ?pill],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (facts.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: facts,
                          ),
                        if (pill != null)
                          Padding(
                            // Lifted to the middle of the button beside it.
                            padding: EdgeInsets.only(top: facts.isEmpty ? 0 : 9, bottom: action == null ? 2 : 9),
                            child: pill,
                          ),
                      ],
                    ),
            ),
            if (action != null) ...[const SizedBox(width: 10), action],
          ],
        ),
      ),
    );

    return LipBox(
      lip: 5,
      onTap: onTap,
      sink: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TicketTop(
            large: big,
            stubColor: done ? BB.kraft : BB.coral,
            stub: _DateStub(date: e.start, large: big),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BB.lilita(big ? 27 : 23),
                ),
                if (e.venue.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      e.venue,
                      style: BB.bodyStyle(big ? 15.5 : 14, color: BB.ink, weight: FontWeight.w800, height: 1.3),
                    ),
                  ),
                if (e.city.isNotEmpty)
                  Text(e.city, style: BB.bodyStyle(big ? 15.5 : 14, color: BB.ink2, height: 1.3)),
              ],
            ),
          ),
          const DashedRule(),
          lower,
        ],
      ),
    );
  }
}

/// The ticket before anything is printed on it: no dates announced.
class TbaTicket extends StatelessWidget {
  const TbaTicket({super.key, this.large});

  /// Desktop sizes. Follows the breakpoint when left out.
  final bool? large;

  @override
  Widget build(BuildContext context) {
    final big = large ?? BB.isWide(context);
    return LipBox(
      lip: 5,
      child: _TicketTop(
        large: big,
        stubColor: BB.kraft,
        stub: Text('TBA', textScaler: TextScaler.noScaling, style: BB.lilita(big ? 30 : 26, height: 1)),
        child: Text('No dates announced yet.', style: BB.lilita(big ? 25 : 21, height: 1.1)),
      ),
    );
  }
}

/// The part of a ticket above the lower stub: the colored stub at the left,
/// a dashed perforation, and the body.
class _TicketTop extends StatelessWidget {
  const _TicketTop({required this.large, required this.stubColor, required this.stub, required this.child});

  final bool large;
  final Color stubColor;
  final Widget stub;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = large ? 96.0 : 80.0;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: large ? 108 : 98),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: w,
            child: ColoredBox(
              color: stubColor,
              child: const Align(
                alignment: Alignment.centerRight,
                child: DashedRule(axis: Axis.vertical, thickness: 2.5),
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(width: w, child: Center(child: stub)),
              Expanded(
                child: Padding(
                  padding: large
                      ? const EdgeInsets.fromLTRB(20, 16, 20, 16)
                      : const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  child: child,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateStub extends StatelessWidget {
  const _DateStub({required this.date, required this.large});

  final DateTime? date;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final d = date;
    if (d == null) {
      return Text('TBA', textScaler: TextScaler.noScaling, style: BB.lilita(large ? 30 : 26, height: 1));
    }
    final caps = BB.caps(12, color: BB.ink, tracking: 0.14);
    return MediaQuery.withNoTextScaling(
      child: Semantics(
        label: DateFormat('EEEE, MMMM d').format(d),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('EEE').format(d).toUpperCase(), style: caps),
              const SizedBox(height: 3),
              Text('${d.day}', style: BB.lilita(large ? 50 : 42, height: 0.95)),
              const SizedBox(height: 3),
              Text(DateFormat('MMM').format(d).toUpperCase(), style: caps),
            ],
          ),
        ),
      ),
    );
  }
}
