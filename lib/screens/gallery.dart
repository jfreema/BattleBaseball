// Every shared component in its variants, on one page, for design review.
// Reached at /dev/gallery, and only when the app is opened with ?demo=1.
import 'package:battle_baseball/data/models.dart';
import 'package:battle_baseball/data/sample.dart';
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/design/card.dart';
import 'package:battle_baseball/design/ticket.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:material_ui/material_ui.dart';

const _long = PublicProfile(
  id: 'g-long',
  name: 'Maximiliano Q.',
  gradYear: 2030,
  positions: ['3B', 'P', 'C'],
  state: 'LA',
  jersey: 18,
);
const _rookieNumber = PublicProfile(
  id: 'g-rookie-7',
  name: 'Sawyer N.',
  gradYear: 2032,
  positions: ['UT'],
  state: 'LA',
  jersey: 7,
);
const _rookie = PublicProfile(
  id: 'g-rookie',
  name: 'Owen B.',
  gradYear: 2033,
  positions: ['1B', 'LF', 'RF', 'CF'],
  bats: 'L',
  throws: 'L',
  state: 'TX',
);
const _bare = PublicProfile(id: 'g-bare', name: 'Wm', positions: []);

Award _award(String type) => Award(id: 'g-$type', eventId: 'g', playerId: 'g', type: type);

BBEvent _event(String status, {DateTime? start, String name = 'Spring Showcase', num? price = 85}) => BBEvent(
      id: 'g-$status',
      name: name,
      status: status,
      venue: 'BREC Central Sports Park',
      city: 'Baton Rouge',
      start: start,
      ageGroups: '9U to 14U',
      price: price,
    );

Registration _reg(String status, {DateTime? hold, bool alreadyPaid = false}) => Registration(
      id: 'g-$status',
      eventId: 'g-open',
      eventName: 'Spring Showcase',
      divisionId: 'g-12u',
      divisionName: '12U',
      playerId: 'g',
      playerName: 'Mason Reed',
      guardianUid: 'g',
      guardianName: 'Jamie Reed',
      status: status,
      paymentCode: 'BB-7K2M',
      holdEndsAt: hold,
      alreadyPaid: alreadyPaid,
    );

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _chip = 'All';
  String _choice = 'Travel';
  bool _switch = true;
  bool _check = false;

  @override
  Widget build(BuildContext context) {
    final wide = BB.isWide(context);
    final awards = Sample.awards();
    final three = [_award('topHitter'), _award('mvp'), _award('eliteDefender'), _award('hustle')];
    final saturday = DateTime(2027, 3, 13, 9);
    void nothing() {}

    return PageFrame(
      children: [
        const BackHeader('Home'),
        const PageTitle('Gallery'),

        const SectionTitle('Player card'),
        _Flow([
          _Item('240', PlayerCard(profile: Sample.profile, topFastball: 71, awards: awards, width: 240)),
          _Item('320', PlayerCard(profile: Sample.profile, topFastball: 71, awards: awards)),
          _Item(
            '420',
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: PlayerCard(profile: Sample.profile, topFastball: 71, awards: awards, width: 420),
            ),
          ),
        ]),
        _Flow([
          _Item('Long name', PlayerCard(profile: _long, topFastball: 67, awards: awards)),
          _Item('Three awards and more', PlayerCard(profile: Sample.profile, topFastball: 71, awards: three)),
          _Item('One award', PlayerCard(profile: _long, topFastball: 67.5, awards: [_award('topHitter')])),
          _Item('No awards', PlayerCard(profile: Sample.profile, topFastball: 71, width: 300)),
          _Item('Rookie with a number', PlayerCard(profile: _rookieNumber, width: 280)),
          _Item('Rookie without', PlayerCard(profile: _rookie, width: 280)),
          _Item('Almost nothing known', PlayerCard(profile: _bare, width: 240)),
          _Item(
            'Tilted, tappable',
            Padding(
              padding: const EdgeInsets.all(12),
              child: PlayerCard(
                profile: Sample.profile,
                topFastball: 71,
                awards: awards,
                rotation: -3.5,
                sample: true,
                onTap: nothing,
              ),
            ),
          ),
        ]),

        const SectionTitle('Award seals'),
        const _Flow([
          _Item('Label', AwardSeal(label: 'MVP', mark: '*')),
          _Item('Two lines', AwardSeal(label: 'Top Pitcher', mark: 'TP')),
          _Item('Too long at 74', AwardSeal(label: 'Elite Defender', mark: 'ED')),
          _Item('At 96', AwardSeal(label: 'Elite Defender', mark: 'ED', size: 96)),
          _Item('Mark', AwardSeal(mark: '*', size: 37, drop: 0.05)),
          _Item('Initials', AwardSeal(mark: 'TP', size: 37, drop: 0.05)),
          _Item('Blank', AwardSeal(size: 44, drop: 0)),
        ]),

        const SectionTitle('Tickets'),
        _Grid(wide: wide, children: [
          _Item('Open', ShowcaseTicket(event: _event('open', start: saturday), spotsLeft: 11, onTap: nothing, onReserve: nothing)),
          _Item(
            'Open, one spot',
            ShowcaseTicket(
              event: _event('open', start: DateTime(2027, 6, 5, 9), name: 'Summer Showcase'),
              spotsLeft: 1,
              onTap: nothing,
              onReserve: nothing,
            ),
          ),
          _Item('Open, full', ShowcaseTicket(event: _event('open', start: saturday), spotsLeft: 0, onTap: nothing, onReserve: nothing)),
          _Item('Closed', ShowcaseTicket(event: _event('closed', start: saturday), onTap: nothing)),
          _Item('Live', ShowcaseTicket(event: _event('live', start: saturday), onTap: nothing)),
          _Item('Rained out', ShowcaseTicket(event: _event('rainedOut', start: saturday), onTap: nothing)),
          _Item(
            'Final',
            ShowcaseTicket(
              event: _event('final', start: DateTime(2026, 10, 17, 9), name: 'Fall Showcase'),
              onTap: nothing,
            ),
          ),
          _Item(
            'No date or price, long name',
            ShowcaseTicket(
              event: _event('open', name: 'Red Stick Renegades Winter Showcase', price: null),
              spotsLeft: 24,
              onReserve: nothing,
            ),
          ),
          const _Item('Nothing announced', TbaTicket()),
          _Item('Large', ShowcaseTicket(event: _event('open', start: saturday), spotsLeft: 11, onReserve: nothing, large: true)),
        ]),

        const SectionTitle('Mini cards'),
        _Grid(wide: wide, children: [
          MiniCard(rank: 1, name: 'Tyler B.', sub: 'Class of 2029', value: '78', unit: 'MPH', first: true, onTap: nothing),
          MiniCard(rank: 2, name: 'Jace M.', sub: 'Class of 2029', value: '76', unit: 'MPH', onTap: nothing),
          MiniCard(rank: 3, name: 'Cooper L.', sub: 'Class of 2030', value: '75', unit: 'MPH', dot: true, onTap: nothing),
          MiniCard(rank: 12, name: 'Maximiliano Quintanilla-Reyes', sub: 'Class of 2030', value: '67.5', unit: 'MPH', onTap: nothing),
          MiniCard(rank: 1, name: 'Cooper L.', sub: 'Class of 2030', value: '2.04', unit: 'SEC', first: true, onTap: nothing),
          MiniCard(name: 'Mason R.', sub: 'Class of 2031 · RHP', value: '71', unit: 'MPH', onTap: nothing),
          MiniCard(name: 'Sawyer N.', sub: 'Class of 2032 · UT', value: '7', onTap: nothing),
          MiniCard(name: 'Owen B.', sub: 'Class of 2033 · 1B', value: 'OB', onTap: nothing),
        ]),

        const SectionTitle('Ruled panel'),
        _Grid(wide: wide, children: [
          RuledPanel(children: [
            RuledRow(rank: 4, name: 'Wyatt S.', sub: '2029', value: '74', onTap: nothing),
            RuledRow(rank: 5, name: 'Beau D.', sub: '2030', value: '73', onTap: nothing),
            RuledRow(rank: 6, name: 'Mason R.', sub: '2031', value: '71', dot: true, onTap: nothing),
            const RuledRow(rank: 7, name: 'Private player', sub: '2030', value: '70'),
            RuledRow(rank: 18, name: 'Maximiliano Quintanilla-Reyes', sub: '2030', value: '67.5', onTap: nothing),
          ]),
          RuledPanel(
            columns: const ['AB', 'H', 'HR', 'RBI', 'AVG'],
            children: [
              RuledRow(name: 'Tyler B.', cells: const ['4', '3', '1', '4', '.750'], onTap: nothing),
              RuledRow(name: 'Cooper L.', cells: const ['4', '3', '0', '2', '.750'], onTap: nothing),
              const RuledRow(name: 'Private player', cells: ['3', '1', '0', '0', '.333']),
            ],
          ),
          const RuledPanel(children: [
            RuledRow(rank: 4, name: 'Hayes W.', sub: '2030', value: '2.11', unit: 'sec'),
            RuledRow(rank: 5, name: 'Mason R.', sub: '2031', value: '2.18', unit: 'sec'),
          ]),
        ]),

        const SectionTitle('Card back'),
        _Grid(wide: wide, children: [
          _Item('Everything', _fullBack()),
          _Item(
            'One reading',
            CardBack(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BackCaption('Fastball'),
                  VeloChart(values: const [64], labels: [tickLabel('Fall Showcase', '11U')]),
                ],
              ),
              const BackFoot(note: '1 showcase'),
            ]),
          ),
          _Item(
            'Six readings, no gain',
            CardBack(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BackCaption('Fastball', tag: VeloChart.gain(const [70, 69, 72, 71.5, 73, 70])),
                  const VeloChart(
                    values: [70, 69, 72, 71.5, 73, 70],
                    labels: ['FALL 10U', 'SPR 11U', 'SUM 11U', 'FALL 11U', 'SPR 12U', 'SUM 12U'],
                  ),
                ],
              ),
              const BackFoot(),
            ]),
          ),
        ]),

        const SectionTitle('Buttons'),
        _Flow([
          _Item('Primary', BBButton.primary('Reserve a spot', onPressed: nothing)),
          _Item('Paper', BBButton.paper('Add player', onPressed: nothing)),
          _Item('Quiet', BBButton.quiet('Edit', onPressed: nothing)),
          _Item('Small', BBButton.primary('Reserve', small: true, onPressed: nothing)),
          _Item('Small paper', BBButton.paper('I already paid', small: true, onPressed: nothing)),
          _Item('Small quiet', BBButton.quiet('Sign in', small: true, onPressed: nothing)),
          _Item('Large', BBButton.primary('Create an account', large: true, onPressed: nothing)),
          _Item('With icon', BBButton.paper('Share card', icon: const BBIcon(BBGlyph.share), onPressed: nothing)),
          _Item('Busy', BBButton.primary('Save', busy: true, onPressed: nothing)),
          const _Item('Off', BBButton.primary('Save', onPressed: null)),
        ]),
        _Item('Expanded', BBButton.primary('Save', expand: true, onPressed: nothing)),
        const SizedBox(height: 20),

        const SectionTitle('Chips, pills, stamps, links'),
        _Item(
          'Chips',
          ChipRow(children: [
            for (final c in const ['All', '2029', '2030', '2031', '2032', '2033'])
              BBChip(c, selected: _chip == c, onTap: () => setState(() => _chip = c)),
            const BBChip('Class of 2031', small: true),
          ]),
        ),
        _Item(
          'Material chips, themed',
          Wrap(spacing: 8, runSpacing: 10, children: [
            for (final c in playingLevels)
              ChoiceChip(
                label: Text(c),
                selected: _choice == c,
                onSelected: (_) => setState(() => _choice = c),
              ),
          ]),
        ),
        _Flow([
          _Item('Spots open', Pill('11 spots left', color: BB.mint)),
          _Item('Honor', Pill('Owner', color: BB.lemon)),
          _Item('Everything else', Pill('Confirming payment')),
          _Item('Stamp', Padding(padding: EdgeInsets.all(4), child: Stamp('Sample'))),
          _Item('Stamp', Padding(padding: EdgeInsets.all(4), child: Stamp('Sample data'))),
        ]),
        _Flow([
          _Item('Text link', TextLink('All leaders', onTap: nothing)),
          _Item('Opens the sheet', TextLink('The fine print', onTap: () => showFinePrint(context))),
          _Item('Toast', TextLink('Link copied', onTap: () => toast(context, 'Link copied'))),
          _Item(
            'On paper',
            Paper(child: TextLink('Results', color: BB.ink, onTap: nothing)),
          ),
        ]),

        const SectionTitle('Type and marks'),
        const _Flow([
          _Item('Wordmark', Wordmark()),
          _Item('Wordmark, desktop', Wordmark(height: 46.4)),
          _Item('Outlined numeral', OutlinedText('71', size: 48, stroke: 5, drop: 3)),
        ]),
        const PageTitle('Fastball leaders'),
        const SectionTitle('Next Showcase', trailing: BBChip('Class of 2031', small: true)),
        const Quiet('No readings yet.'),
        const SizedBox(height: 20),
        _Item(
          'Icons',
          Wrap(spacing: 18, runSpacing: 12, children: [
            for (final g in BBGlyph.values) BBIcon(g, size: 24),
          ]),
        ),

        const SectionTitle('Rows and panels'),
        _Grid(wide: wide, children: [
          RegistrationRow(_reg('paid')),
          RegistrationRow(_reg('held', hold: DateTime.now().add(const Duration(hours: 20)))),
          RegistrationRow(_reg('held', hold: DateTime.now().subtract(const Duration(hours: 2)))),
          RegistrationRow(_reg('waitlisted'), showEvent: false),
          Paper(
            onTap: nothing,
            child: Row(children: [
              Expanded(child: Text('Your players')),
              BBIcon(BBGlyph.forward, color: BB.ink),
            ]),
          ),
          Paper(
            color: BB.kraft,
            child: Row(children: [
              Expanded(child: Text('Battle Paddle')),
              Pill('Coming soon'),
            ]),
          ),
        ]),

        const SectionTitle('Fields'),
        _Grid(wide: wide, children: [
          const TextField(decoration: InputDecoration(labelText: 'First name')),
          TextField(
            controller: TextEditingController(text: 'Mason'),
            decoration: const InputDecoration(labelText: 'First name'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Public card'),
            value: _switch,
            onChanged: (v) => setState(() => _switch = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("I'm the parent or guardian and I agree to the waiver."),
            value: _check,
            onChanged: (v) => setState(() => _check = v ?? false),
          ),
        ]),
        const LoadingField(),
      ],
    );
  }

  Widget _fullBack() {
    final readings = Sample.fastballs;
    final values = [for (final m in readings) m.value];
    final total = StatLine.total(Sample.statLines());
    final awards = Sample.awards();
    return CardBack(children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BackCaption('Fastball', tag: VeloChart.gain(values)),
          VeloChart(
            values: values,
            labels: [for (final m in readings) tickLabel(m.eventName, m.divisionName)],
          ),
        ],
      ),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BackCaption('Skills'),
          RuledTable(headers: ['Pop time', '40 yard'], values: ['2.18', '5.62'], units: ['sec', 'sec']),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackCaption('Batting'),
          RuledTable(
            headers: const ['AB', 'H', 'HR', 'RBI', 'R', 'BB', 'AVG'],
            values: ['${total.ab}', '${total.h}', '${total.hr}', '${total.rbi}', '${total.r}', '${total.bb}', total.avg],
            highlightLast: true,
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackCaption('Pitching'),
          RuledTable(headers: const ['IP', 'K', 'BB'], values: [total.ip, '${total.k}', '${total.pbb}']),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackCaption('Awards'),
          for (final (i, a) in awards.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: AwardLine(
                title: a.label,
                sub: '${a.eventName} ${a.divisionName}',
                mark: awardMark(a.type),
                tilt: i.isEven ? -8 : 7,
              ),
            ),
        ],
      ),
      BackFoot(note: '${Sample.showcases} showcases'),
    ]);
  }
}

/// A variant with a small caps note over it.
class _Item extends StatelessWidget {
  const _Item(this.note, this.child);
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(note.toUpperCase(), style: BB.caps(11, color: BB.dashed)),
          ),
          child,
        ],
      );
}

/// Variants side by side, wrapping.
class _Flow extends StatelessWidget {
  const _Flow(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Wrap(spacing: 32, runSpacing: 30, crossAxisAlignment: WrapCrossAlignment.end, children: children),
      );
}

/// Full-width variants: one column on phones, two on desktop.
class _Grid extends StatelessWidget {
  const _Grid({required this.wide, required this.children});
  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: LayoutBuilder(
          builder: (context, box) {
            const gap = 28.0;
            final w = wide ? (box.maxWidth - gap) / 2 : box.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: 16,
              children: [for (final c in children) SizedBox(width: w, child: c)],
            );
          },
        ),
      );
}
