// Age groups and the boards: who counts where, and whose reading ranks.
import 'package:battle_baseball/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Measurement _m(String player, String type, double value, String division, {String event = 'e1'}) =>
    Measurement(
      id: '$player-$type-$event',
      eventId: event,
      eventName: event,
      playerId: player,
      publicName: player,
      divisionName: division,
      type: type,
      value: value,
      published: true,
    );

void main() {
  test('ages fold into 10U, 12U and 14U', () {
    expect(ageGroupForAge(8), '10U');
    expect(ageGroupForAge(10), '10U');
    expect(ageGroupForAge(11), '12U');
    expect(ageGroupForAge(12), '12U');
    expect(ageGroupForAge(13), '14U');
    expect(ageGroupForAge(14), '14U');
    expect(ageGroupForAge(15), isNull);
  });

  test('a division counts toward the age group its number falls in', () {
    expect(ageGroupOf('10U'), '10U');
    expect(ageGroupOf('11U Gold'), '12U');
    expect(ageGroupOf('12u'), '12U');
    expect(ageGroupOf('13U'), '14U');
    expect(ageGroupOf('14U'), '14U');
    expect(ageGroupOf('Open'), isNull);
  });

  test('birth dates read both ways, and age turns on the birthday', () {
    final birth = parseBirthDate('04/01/2016')!;
    expect(birth, DateTime(2016, 4, 1));
    expect(parseBirthDate('2016-04-01'), birth);
    expect(parseBirthDate('April 1'), isNull);
    expect(ageOn(birth, DateTime(2026, 3, 31)), 9);
    expect(ageOn(birth, DateTime(2026, 4, 1)), 10);
  });

  test("a board keeps each player's best across showcases", () {
    final readings = [
      _m('bart', 'fastball', 52, '10U'),
      _m('bart', 'fastball', 55, '10U', event: 'e2'),
      _m('martin', 'fastball', 50, '10U'),
      _m('jimbo', 'fastball', 71, '14U'),
    ];
    final tenU = bestReadings(readings, 'fastball', ageGroup: '10U');
    expect(tenU.map((m) => m.playerId), ['bart', 'martin']);
    expect(tenU.first.value, 55);
    expect(tenU.first.eventId, 'e2');
    expect(bestReadings(readings, 'fastball').first.playerId, 'jimbo');
  });

  test('the 40 ranks the quickest time first', () {
    final readings = [
      _m('dolph', 'dash40', 5.41, '14U'),
      _m('dolph', 'dash40', 5.36, '14U', event: 'e2'),
      _m('sherri', 'dash40', 5.49, '14U'),
    ];
    final board = bestReadings(readings, 'dash40', ageGroup: '14U');
    expect(board.map((m) => m.value), [5.36, 5.49]);
  });

  test('home runs rank by the best single showcase and leave off zeros', () {
    StatLine line(String player, int hr, String event) => StatLine(
          id: '${event}_$player',
          eventId: event,
          playerId: player,
          publicName: player,
          divisionName: '12U',
          hr: hr,
          ab: 4,
        );
    final readings = [
      line('nelson', 2, 'e1').homeRuns,
      line('nelson', 1, 'e2').homeRuns,
      line('uter', 2, 'e2').homeRuns,
      line('rod', 0, 'e1').homeRuns,
    ];
    final board = bestReadings(readings, 'homeRuns', ageGroup: '12U');
    expect(board.map((m) => m.playerId), ['nelson', 'uter']);
    expect(board.first.value, 2);
  });

  test('the Leaders home run board adds up every showcase in the age group', () {
    StatLine line(String player, int hr, String event, String division) => StatLine(
          id: '${event}_$player',
          eventId: event,
          playerId: player,
          publicName: player,
          divisionName: division,
          hr: hr,
          ab: 4,
        );
    final readings = [
      line('jimbo', 2, 'e1', '14U').homeRuns,
      line('jimbo', 3, 'e2', '14U').homeRuns,
      line('kearney', 3, 'e1', '14U').homeRuns,
      line('kearney', 1, 'e2', '14U').homeRuns,
      line('dolph', 0, 'e1', '14U').homeRuns,
      line('nelson', 9, 'e1', '12U').homeRuns,
    ];
    final board = leaderRows(readings, 'homeRuns', ageGroup: '14U');
    expect(board.map((m) => m.playerId), ['jimbo', 'kearney']);
    expect(board.map((m) => m.value), [5, 4]);
    expect(board.first.eventName, '2 showcases');
    // Every other board still takes the best reading.
    expect(leaderRows([_m('bart', 'fastball', 52, '10U'), _m('bart', 'fastball', 55, '10U', event: 'e2')], 'fastball')
        .single
        .value, 55);
  });
}
