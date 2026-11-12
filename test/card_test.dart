// The card front's data rules, and the ticket's states.
import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/sample.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/design/ticket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) => MaterialApp(
      theme: BB.theme(),
      home: Scaffold(body: SingleChildScrollView(child: Center(child: child))),
    );

Award _award(String type) => Award(id: type, eventId: 'e', playerId: 'p', type: type);

Finder _numeral(String text) =>
    find.byWidgetPredicate((w) => w is OutlinedText && w.text == text);

const _rookie = PublicProfile(id: 'r', name: 'Owen K.', gradYear: 2033, positions: ['1B'], state: 'TX');

void main() {
  testWidgets('a card with a fastball shows the reading, MPH and the patch', (t) async {
    await t.pumpWidget(_host(const PlayerCard(profile: Sample.profile, topFastball: 71)));
    expect(t.takeException(), isNull);
    expect(_numeral('71'), findsOneWidget);
    expect(find.text('MPH'), findsOneWidget);
    expect(find.text('TOP FASTBALL'), findsOneWidget);
    expect(find.text('12'), findsOneWidget, reason: 'the jersey patch');
    expect(find.text('RHP'), findsOneWidget, reason: 'a right-handed P prints as RHP');
  });

  testWidgets('a long name stays on one line and inside the card', (t) async {
    const profile = PublicProfile(id: 'p', name: 'Maximiliano Quintanilla-Reyes', gradYear: 2030);
    for (final width in [240.0, 320.0, 420.0]) {
      await t.pumpWidget(_host(PlayerCard(
        profile: profile,
        topFastball: 67.5,
        awards: [_award('mvp'), _award('topPitcher')],
        width: width,
      )));
      expect(t.takeException(), isNull, reason: 'nothing overflows at $width');
      final name = find.text(profile.name);
      expect(t.widget<Text>(name).maxLines, 1);
      final card = t.getRect(find.byType(PlayerCard));
      final box = t.getRect(find.ancestor(of: name, matching: find.byType(FittedBox)).first);
      expect(box.right, lessThan(card.right));
      expect(box.height, closeTo(2.35 * width / 20, 0.01), reason: 'one line tall');
    }
  });

  testWidgets('awards: none, one or two as seals, more as two seals and a count', (t) async {
    Future<void> show(List<String> types) => t.pumpWidget(_host(PlayerCard(
          profile: Sample.profile,
          topFastball: 71,
          awards: [for (final type in types) _award(type)],
        )));

    await show([]);
    expect(find.byType(AwardSeal), findsNothing);

    await show(['topHitter']);
    expect(find.byType(AwardSeal), findsOneWidget);

    await show(['topHitter', 'mvp']);
    expect(find.byType(AwardSeal), findsNWidgets(2));
    expect(find.textContaining('+'), findsNothing);

    await show(['topHitter', 'mvp', 'hustle']);
    expect(find.byType(AwardSeal), findsNWidgets(2));
    expect(find.text('+1'), findsOneWidget);

    await show(['topHitter', 'mvp', 'hustle', 'eliteDefender', 'topPitcher']);
    expect(find.byType(AwardSeal), findsNWidgets(2));
    expect(find.text('+3'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a rookie shows the jersey number, or initials, and no MPH', (t) async {
    const numbered = PublicProfile(id: 'n', name: 'Sawyer N.', jersey: 7);
    await t.pumpWidget(_host(const PlayerCard(profile: numbered)));
    expect(_numeral('7'), findsOneWidget);
    expect(find.text('ROOKIE CARD'), findsOneWidget);
    expect(find.text('TOP FASTBALL'), findsNothing);
    expect(find.text('MPH'), findsNothing);

    await t.pumpWidget(_host(const PlayerCard(profile: _rookie)));
    expect(_numeral('OK'), findsOneWidget);
    expect(find.text('ROOKIE CARD'), findsOneWidget);
    expect(find.text('MPH'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the patch is left out when there is no jersey number', (t) async {
    await t.pumpWidget(_host(const PlayerCard(profile: _rookie, topFastball: 61)));
    // The only numerals on the card are the reading and the class year.
    expect(_numeral('61'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    expect(find.text('7'), findsNothing);
  });

  testWidgets('heightFor matches the card as laid out', (t) async {
    for (final width in [240.0, 300.0, 320.0, 420.0]) {
      await t.pumpWidget(_host(PlayerCard(profile: Sample.profile, topFastball: 71, width: width)));
      expect(t.getSize(find.byType(PlayerCard)).height, closeTo(PlayerCard.heightFor(width), 0.5));
      expect(t.getSize(find.byType(PlayerCard)).width, width);
    }
  });

  test('the gain tag appears only when the latest reading beats the first', () {
    expect(VeloChart.gain([64, 67, 68, 71]), '+7 MPH');
    expect(VeloChart.gain([64, 65.5]), '+1.5 MPH');
    expect(VeloChart.gain([70, 70]), isNull);
    expect(VeloChart.gain([71, 64]), isNull);
    expect(VeloChart.gain([64]), isNull);
    expect(VeloChart.gain([]), isNull);
  });

  testWidgets('one reading prints the number alone; two or more draw the chart', (t) async {
    await t.pumpWidget(_host(const SizedBox(width: 330, child: VeloChart(values: [64], labels: ['FALL 11U']))));
    expect(find.text('64'), findsOneWidget);
    expect(find.text('FALL 11U'), findsOneWidget);

    await t.pumpWidget(_host(const SizedBox(width: 330, child: VeloChart(values: [64, 71]))));
    expect(find.text('64'), findsNothing, reason: 'the chart paints its own numbers');
    expect(t.takeException(), isNull);
  });

  test('seal marks: a star for MVP, initials otherwise', () {
    expect(sealMark('mvp'), starMark);
    expect(sealMark('topPitcher'), 'TP');
    expect(sealMark('eliteDefender'), 'ED');
  });

  testWidgets('ticket states', (t) async {
    BBEvent event(String status) => BBEvent(
          id: status,
          name: 'Spring Showcase',
          status: status,
          venue: 'BREC Central Sports Park',
          start: DateTime(2027, 3, 13, 9),
          ageGroups: '9U to 14U',
          price: 85,
        );
    Future<void> show(Widget ticket) =>
        t.pumpWidget(_host(SizedBox(width: 358, child: ticket)));

    await show(ShowcaseTicket(event: event('open'), spotsLeft: 11, onTap: () {}, onReserve: () {}));
    expect(find.text('SAT'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('MAR'), findsOneWidget);
    expect(find.text(r'$85'), findsOneWidget);
    expect(find.text('11 spots left'), findsOneWidget);
    expect(find.text('Reserve'), findsOneWidget);

    await show(ShowcaseTicket(event: event('open'), spotsLeft: 0, onReserve: () {}));
    expect(find.text('Waitlist'), findsOneWidget);

    await show(ShowcaseTicket(event: event('closed'), spotsLeft: 3, onTap: () {}));
    expect(find.text('Registration closed'), findsOneWidget);
    expect(find.text('Reserve'), findsNothing);

    await show(ShowcaseTicket(event: event('live')));
    expect(find.text('Today'), findsOneWidget);

    await show(ShowcaseTicket(event: event('rainedOut')));
    expect(find.text('Rained out'), findsOneWidget);

    await show(ShowcaseTicket(event: event('final'), onTap: () {}));
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text(r'$85'), findsNothing);

    await show(const TbaTicket());
    expect(find.text('TBA'), findsOneWidget);
    expect(find.text('No dates announced yet.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
