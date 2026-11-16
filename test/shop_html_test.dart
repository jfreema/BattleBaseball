// Shopify product descriptions read into blocks: the coral tee's, and the other bits of HTML an editor writes.
import 'package:battle_baseball/data/shop_html.dart';
import 'package:flutter_test/flutter_test.dart';

/// The coral tee's description as Shopify stores it: the print shop writes
/// each bullet as its own list and adds a size chart.
const _coral = '''<p>Special Edition. The Battle Baseball tank logo on a coral A4 moisture-wicking performance tee, in adult sizes S-4XL. Light, breathable, and built for game days. Printed on demand and ships in 5-7 business days, with free shipping.</p>
<hr>
<p><strong>A4 N3142 Men's Short-Sleeve Cooling Performance Crew</strong></p>
<ul>
<li>4 oz, 100% polyester</li>
</ul>
<ul>
<li>Moisture wicking fabric great for sports and exercise</li>
</ul>
<ul>
<li>44+ UPF for UV sun protection</li>
</ul>
<ul>
<li>Reinforced shoulder seams</li>
</ul>
<ul>
<li>Tear-away label</li>
</ul>
<table id="sizechart">
<tbody>
<tr>
<th>Size</th>
<th>Body length (in)</th>
<th>Body width (in)</th>
<th>Sleeve length (in)</th>
</tr>
<tr>
<td>S</td>
<td>27.5</td>
<td>20.5</td>
<td>18.5</td>
</tr>
<tr>
<td>M</td>
<td>28.5</td>
<td>21.5</td>
<td>19.25</td>
</tr>
<tr>
<td>L</td>
<td>29.5</td>
<td>23.0</td>
<td>20</td>
</tr>
<tr>
<td>XL</td>
<td>30.5</td>
<td>24.5</td>
<td>20.75</td>
</tr>
<tr>
<td>2XL</td>
<td>31.5</td>
<td>26.0</td>
<td>21.5</td>
</tr>
<tr>
<td>3XL</td>
<td>32.5</td>
<td>27.5</td>
<td>22.25</td>
</tr>
<tr>
<td>4XL</td>
<td>33.5</td>
<td>29.0</td>
<td>23</td>
</tr>
</tbody>
</table>''';

String _text(List<DescRun> runs) => runs.map((r) => r.text).join();

void main() {
  test("the coral tee's description is a paragraph, a rule, a heading, one list and a size chart", () {
    final blocks = parseDescription(_coral);
    expect(blocks.map((b) => b.runtimeType), [DescText, DescRule, DescText, DescList, DescTable]);

    final intro = blocks[0] as DescText;
    expect(intro.heading, isFalse);
    expect(intro.text, startsWith('Special Edition. The Battle Baseball tank logo'));
    expect(intro.text, endsWith('with free shipping.'));
    expect(intro.runs.any((r) => r.bold), isFalse);

    final heading = blocks[2] as DescText;
    expect(heading.text, "A4 N3142 Men's Short-Sleeve Cooling Performance Crew");
    expect(heading.runs.every((r) => r.bold), isTrue, reason: 'the screen shows an all-bold line as a heading');

    final list = blocks[3] as DescList;
    expect(list.items.map(_text), [
      '4 oz, 100% polyester',
      'Moisture wicking fabric great for sports and exercise',
      '44+ UPF for UV sun protection',
      'Reinforced shoulder seams',
      'Tear-away label',
    ]);

    final chart = blocks[4] as DescTable;
    expect(chart.headed, isTrue);
    expect(chart.rows.first, ['Size', 'Body length (in)', 'Body width (in)', 'Sleeve length (in)']);
    expect(chart.rows, hasLength(8));
    expect(chart.rows.every((r) => r.length == 4), isTrue);
    expect(chart.rows.skip(1).map((r) => r.first), ['S', 'M', 'L', 'XL', '2XL', '3XL', '4XL']);
    expect(chart.rows[2], ['M', '28.5', '21.5', '19.25']);
  });

  test('the same description saved on one line reads the same', () {
    final blocks = parseDescription(_coral.replaceAll('\n', ''));
    expect(blocks.map((b) => b.runtimeType), [DescText, DescRule, DescText, DescList, DescTable]);
    expect((blocks[3] as DescList).items, hasLength(5));
    expect((blocks[4] as DescTable).rows, hasLength(8));
  });

  test('a line break stays inside its paragraph', () {
    final blocks = parseDescription('<p>Printed on demand.<br>Ships in 2-4 business days.</p>');
    expect((blocks.single as DescText).text, 'Printed on demand.\nShips in 2-4 business days.');
    expect((parseDescription('<p>Free shipping.<br></p>').single as DescText).text, 'Free shipping.');
  });

  test('italic and bold words keep their text and their style', () {
    final runs = (parseDescription('<p>Ships in <em>2-4</em> business days, <b>free</b>.</p>').single as DescText).runs;
    expect(_text(runs), 'Ships in 2-4 business days, free.');
    expect([for (final r in runs) if (r.italic) r.text], ['2-4']);
    expect([for (final r in runs) if (r.bold) r.text], ['free']);
    final nested = (parseDescription('<p><strong>Bold <i>and italic</i></strong></p>').single as DescText).runs;
    expect([for (final r in nested) (r.text, r.bold, r.italic)], [('Bold ', true, false), ('and italic', true, true)]);
  });

  test('paragraphs inside a div are read as paragraphs, with the loose text around them', () {
    final blocks = parseDescription('<div><p>One</p><p>Two</p></div><div>Before<p>Inside</p>After</div>');
    expect(blocks.every((b) => b is DescText), isTrue);
    expect([for (final b in blocks) (b as DescText).text], ['One', 'Two', 'Before', 'Inside', 'After']);
  });

  test('headings are marked as headings', () {
    final blocks = parseDescription('<h3>Care</h3><p>Machine wash cold, tumble dry low.</p>');
    expect([for (final b in blocks) ((b as DescText).text, b.heading)], [
      ('Care', true),
      ('Machine wash cold, tumble dry low.', false),
    ]);
  });

  test('empty paragraphs and non-breaking spaces leave nothing behind and drop no words', () {
    final blocks = parseDescription('<p></p><p>&nbsp;</p><p>4&nbsp;oz, 100%&nbsp;polyester</p><p> </p><p>&nbsp;<br></p>');
    expect(blocks, hasLength(1));
    expect((blocks.single as DescText).text.replaceAll(' ', ' '), '4 oz, 100% polyester');
  });

  test('bullet lists either side of an empty paragraph still read as one list', () {
    final blocks = parseDescription('<ul><li>4 oz</li></ul><p>&nbsp;</p><ul><li>UPF 44+</li></ul>');
    expect((blocks.single as DescList).items.map(_text), ['4 oz', 'UPF 44+']);
  });

  test('loose text and inline tags with no block around them are a paragraph', () {
    final blocks = parseDescription('Printed on demand by <a href="https://example.com">our print shop</a>.');
    expect((blocks.single as DescText).text, 'Printed on demand by our print shop.');
  });

  test('a numbered list is a list, and a table with no th row has no headings', () {
    final blocks = parseDescription('<ol><li>Wash cold</li><li>Hang dry</li></ol>'
        '<table><tr><td>Chest</td><td>20"</td></tr><tr><td>Length</td><td>28"</td></tr></table>');
    expect((blocks[0] as DescList).items.map(_text), ['Wash cold', 'Hang dry']);
    expect((blocks[1] as DescTable).headed, isFalse);
    expect((blocks[1] as DescTable).rows, [
      ['Chest', '20"'],
      ['Length', '28"'],
    ]);
  });

  test('a numbered list is numbered, and a bullet list next to it stays its own list', () {
    final blocks = parseDescription('<ol><li>Wash cold</li><li>Hang dry</li></ol><ul><li>4 oz</li></ul>');
    expect([for (final b in blocks) (b as DescList).numbered], [true, false]);
  });

  test("a style or script block's text never shows", () {
    final blocks = parseDescription('<style>#sizechart td { padding: 4px; }</style><script>track()</script>'
        '<p>Printed on demand.</p>');
    expect(blocks.map((b) => (b as DescText).text), ['Printed on demand.']);
  });

  test('a list inside a bullet becomes bullets of its own', () {
    final blocks = parseDescription('<ul><li>Fabric<ul><li>100% polyester</li><li>4 oz</li></ul></li><li>Fit</li></ul>');
    expect((blocks.single as DescList).items.map(_text), ['Fabric', '100% polyester', '4 oz', 'Fit']);
  });

  test("paragraphs inside a line of text don't run together", () {
    final blocks = parseDescription('<span><p>Para one</p>\n<p>Para two</p></span>');
    expect((blocks.single as DescText).text, 'Para one\nPara two');
  });

  test('an empty description has no blocks', () {
    expect(parseDescription(''), isEmpty);
    expect(parseDescription(' \n <p> </p> <ul></ul> <table></table>'), isEmpty);
  });
}
