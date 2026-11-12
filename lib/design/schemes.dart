// The color schemes an admin can switch the whole app to, from Staff tools >
// Color scheme. Every screen draws its colors from BB, and BB reads them from
// the scheme in use, so a scheme is the only place a color is set.
import 'package:material_ui/material_ui.dart';

class BBScheme {
  const BBScheme({
    required this.id,
    required this.name,
    required this.blurb,
    required this.field,
    required this.fieldDeep,
    required this.fieldRaised,
    required this.cream,
    required this.kraft,
    required this.ink,
    required this.ink2,
    required this.accent,
    required this.accentDeep,
    required this.seam,
    required this.honors,
    this.mint = const Color(0xFF58C173),
    this.softAlpha = 0xD1,
  });

  /// Saved in config/theme and accepted by ?scheme= on the web.
  final String id;
  final String name;
  final String blurb;

  /// The page behind everything, the darker bars, and raised fields.
  final Color field, fieldDeep, fieldRaised;

  /// Card stock, the darker paper, and the two inks.
  final Color cream, kraft, ink, ink2;

  /// The one accent: the card face, primary buttons, the selected tab.
  final Color accent, accentDeep;

  /// The stitches on the card's baseball.
  final Color seam;

  /// Award seals and first place.
  final Color honors;

  /// Spots open.
  final Color mint;

  /// How strongly secondary text on the field shows (out of 255). Light
  /// fields need it higher so the text stays readable.
  final int softAlpha;

  /// Colors for the web loading screen and the plain pages, which read them
  /// from localStorage before the app starts.
  Map<String, String> get css => {
        'field': _hex(field),
        'cream': _hex(cream),
        'kraft': _hex(kraft),
        'ink': _hex(ink),
        'ink2': _hex(ink2),
        'coral': _hex(accent),
      };

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

abstract final class BBSchemes {
  static const royal = BBScheme(
    id: 'royal',
    name: 'Royal Blue',
    blurb: 'Royal blue and gold',
    field: Color(0xFF1F4FC4),
    fieldDeep: Color(0xFF153A96),
    fieldRaised: Color(0xFF2F60D6),
    cream: Color(0xFFF5EFDF),
    kraft: Color(0xFFE4DBC3),
    ink: Color(0xFF0F1A3A),
    ink2: Color(0xFF4F5873),
    accent: Color(0xFFFFC627),
    accentDeep: Color(0xFFF0B30C),
    seam: Color(0xFFC0262F),
    honors: Color(0xFFF26A4B),
  );

  static const navy = BBScheme(
    id: 'navy',
    name: 'Ballpark Navy',
    blurb: 'Navy and scoreboard red',
    field: Color(0xFF1E2B47),
    fieldDeep: Color(0xFF131C30),
    fieldRaised: Color(0xFF2C3B5B),
    cream: Color(0xFFF4EAD0),
    kraft: Color(0xFFE3D6B3),
    ink: Color(0xFF14161C),
    ink2: Color(0xFF565A66),
    accent: Color(0xFFE5483F),
    accentDeep: Color(0xFFCC3A36),
    seam: Color(0xFFB3202B),
    honors: Color(0xFFF8D84A),
  );

  static const carolina = BBScheme(
    id: 'carolina',
    name: 'Carolina Blue',
    blurb: 'Light blue, white card, navy lines',
    field: Color(0xFF6FA8D8),
    fieldDeep: Color(0xFF4E87BA),
    fieldRaised: Color(0xFF86B8E2),
    cream: Color(0xFFFBF8F1),
    kraft: Color(0xFFE4E9EF),
    ink: Color(0xFF13294B),
    ink2: Color(0xFF4D5F7A),
    accent: Color(0xFFFFFFFF),
    accentDeep: Color(0xFFE3EEF8),
    seam: Color(0xFFC0262F),
    honors: Color(0xFFFFC72C),
    softAlpha: 0xF5,
  );

  static const spring = BBScheme(
    id: 'spring',
    name: 'Spring Training',
    blurb: 'Deep teal and tangerine',
    field: Color(0xFF15464B),
    fieldDeep: Color(0xFF0C2E32),
    fieldRaised: Color(0xFF1F575C),
    cream: Color(0xFFF5ECD6),
    kraft: Color(0xFFE6D8B6),
    ink: Color(0xFF141A1A),
    ink2: Color(0xFF51605E),
    accent: Color(0xFFF58A3A),
    accentDeep: Color(0xFFE2772B),
    seam: Color(0xFFC0262F),
    honors: Color(0xFFF8D84A),
    mint: Color(0xFF6CCB82),
  );

  static const clay = BBScheme(
    id: 'clay',
    name: 'Infield Clay',
    blurb: 'Brick brown and sky blue',
    field: Color(0xFF6A3422),
    fieldDeep: Color(0xFF4A2215),
    fieldRaised: Color(0xFF7C4430),
    cream: Color(0xFFF6EBD3),
    kraft: Color(0xFFE8D7B5),
    ink: Color(0xFF1C1410),
    ink2: Color(0xFF66503F),
    accent: Color(0xFF4D8BD1),
    accentDeep: Color(0xFF3D78BC),
    seam: Color(0xFFC0262F),
    honors: Color(0xFFF8D84A),
  );

  static const night = BBScheme(
    id: 'night',
    name: 'Night Game',
    blurb: 'Charcoal and volt',
    field: Color(0xFF17191E),
    fieldDeep: Color(0xFF0E0F12),
    fieldRaised: Color(0xFF25282F),
    cream: Color(0xFFF3F1EA),
    kraft: Color(0xFFDDD8CC),
    ink: Color(0xFF0B0C0E),
    ink2: Color(0xFF5A5D63),
    accent: Color(0xFFCFF04A),
    accentDeep: Color(0xFFB7DA32),
    seam: Color(0xFFD0312D),
    honors: Color(0xFFF5B83D),
  );

  static const christmas = BBScheme(
    id: 'christmas',
    name: 'Christmas',
    blurb: 'Evergreen, red, and gold',
    field: Color(0xFF173D2B),
    fieldDeep: Color(0xFF0E2A1D),
    fieldRaised: Color(0xFF245039),
    cream: Color(0xFFF6EEDB),
    kraft: Color(0xFFE9DCBC),
    ink: Color(0xFF121A15),
    ink2: Color(0xFF56604F),
    accent: Color(0xFFD6303A),
    accentDeep: Color(0xFFB8242E),
    seam: Color(0xFF8E1B22),
    honors: Color(0xFFF2C14E),
    mint: Color(0xFF6CCB82),
  );

  static const olive = BBScheme(
    id: 'olive',
    name: 'Olive',
    blurb: 'The original: olive and coral',
    field: Color(0xFF474C2B),
    fieldDeep: Color(0xFF2B2F18),
    fieldRaised: Color(0xFF575A3A),
    cream: Color(0xFFF4EAD0),
    kraft: Color(0xFFE3D6B3),
    ink: Color(0xFF1A1A18),
    ink2: Color(0xFF5A5546),
    accent: Color(0xFFF45B5B),
    accentDeep: Color(0xFFE4494D),
    seam: Color(0xFFC0262F),
    honors: Color(0xFFF8D84A),
  );

  /// The default, used until an admin picks another.
  static const fallback = royal;

  static const all = [royal, navy, carolina, spring, clay, night, christmas, olive];

  static BBScheme? byId(String? id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
