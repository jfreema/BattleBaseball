// A Shopify product description is HTML written in the store's editor (and
// by the print shop, which adds fabric notes and a size chart). This reads
// the handful of things those descriptions use (paragraphs, bold and
// italic, lists, tables, rules) into blocks the product screen can draw in
// the app's own type.
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

sealed class DescBlock {
  const DescBlock();
}

/// A paragraph, or a heading.
class DescText extends DescBlock {
  const DescText(this.runs, {this.heading = false});
  final List<DescRun> runs;
  final bool heading;
  String get text => runs.map((r) => r.text).join();
}

class DescList extends DescBlock {
  const DescList(this.items, {this.numbered = false});
  final List<List<DescRun>> items;

  /// 1, 2, 3 rather than bullets.
  final bool numbered;
}

/// A table, the size chart most of the time.
class DescTable extends DescBlock {
  const DescTable(this.rows, {this.headed = false});
  final List<List<String>> rows;

  /// The first row is column headings.
  final bool headed;
}

class DescRule extends DescBlock {
  const DescRule();
}

class DescRun {
  const DescRun(this.text, {this.bold = false, this.italic = false});
  final String text;
  final bool bold;
  final bool italic;
}

const _blocks = {
  'p', 'div', 'ul', 'ol', 'table', 'hr', 'section', 'article', 'blockquote',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
};

/// Elements that start a new line when they turn up inside a line of text.
const _lineBreaks = {..._blocks, 'li', 'dt', 'dd', 'tr'};

/// Elements whose text is never meant to be read.
const _hidden = {'style', 'script', 'template', 'noscript', 'title', 'head'};

List<DescBlock> parseDescription(String source) {
  final out = <DescBlock>[];
  final loose = <DescRun>[];

  void flush() {
    final runs = _trim(loose);
    loose.clear();
    if (runs.isNotEmpty) out.add(DescText(runs));
  }

  void walk(Node parent) {
    for (final n in parent.nodes) {
      if (n is! Element || !_blocks.contains(n.localName)) {
        _inline(n, loose, bold: false, italic: false);
        continue;
      }
      flush();
      switch (n.localName) {
        case 'hr':
          out.add(const DescRule());
        case 'ul' || 'ol':
          final items = _items(n);
          if (items.isEmpty) break;
          final numbered = n.localName == 'ol';
          // The print shop writes each bullet as its own one-item list.
          if (out.lastOrNull case DescList last when last.numbered == numbered) {
            out.removeLast();
            out.add(DescList([...last.items, ...items], numbered: numbered));
          } else {
            out.add(DescList(items, numbered: numbered));
          }
        case 'table':
          final rows = [
            for (final tr in n.querySelectorAll('tr'))
              [for (final c in tr.children) _squash(c.text).trim()],
          ].where((r) => r.any((c) => c.isNotEmpty)).toList();
          if (rows.isNotEmpty) {
            out.add(DescTable(rows, headed: n.querySelector('tr')?.querySelector('th') != null));
          }
        case final name when name!.startsWith('h'):
          final runs = _trim(_runs(n));
          if (runs.isNotEmpty) out.add(DescText(runs, heading: true));
        default:
          // A paragraph, or a wrapper with blocks of its own inside.
          if (n.children.any((c) => _blocks.contains(c.localName))) {
            walk(n);
            flush();
          } else {
            final runs = _trim(_runs(n));
            if (runs.isNotEmpty) out.add(DescText(runs));
          }
      }
    }
  }

  walk(html.parseFragment(source));
  flush();
  return out;
}

/// A list's items. A list inside an item becomes items of its own, after it.
List<List<DescRun>> _items(Element list) {
  final items = <List<DescRun>>[];
  for (final li in list.children.where((c) => c.localName == 'li')) {
    final runs = <DescRun>[];
    final inside = <Element>[];
    for (final c in li.nodes) {
      if (c is Element && (c.localName == 'ul' || c.localName == 'ol')) {
        inside.add(c);
      } else {
        _inline(c, runs, bold: false, italic: false);
      }
    }
    final own = _trim(runs);
    if (own.isNotEmpty) items.add(own);
    for (final l in inside) {
      items.addAll(_items(l));
    }
  }
  return items;
}

List<DescRun> _runs(Node n) {
  final out = <DescRun>[];
  for (final c in n.nodes) {
    _inline(c, out, bold: false, italic: false);
  }
  return out;
}

void _inline(Node n, List<DescRun> out, {required bool bold, required bool italic}) {
  if (n is Text) {
    var t = _squash(n.text);
    // A new line doesn't start with a space.
    if (out.lastOrNull?.text == '\n') t = t.trimLeft();
    if (t.isNotEmpty) out.add(DescRun(t, bold: bold, italic: italic));
  } else if (n is Element) {
    if (_hidden.contains(n.localName)) return;
    if (n.localName == 'br') {
      out.add(const DescRun('\n'));
      return;
    }
    // A paragraph or a list item inside a line gets lines of its own, so
    // its words don't run into the ones beside it.
    final own = _lineBreaks.contains(n.localName);
    void lineBreak() {
      if (own && out.isNotEmpty && out.last.text != '\n') out.add(const DescRun('\n'));
    }

    lineBreak();
    final b = bold || n.localName == 'strong' || n.localName == 'b';
    final i = italic || n.localName == 'em' || n.localName == 'i';
    for (final c in n.nodes) {
      _inline(c, out, bold: b, italic: i);
    }
    lineBreak();
  }
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

/// Drops the blank space HTML leaves at either end of a block.
List<DescRun> _trim(List<DescRun> runs) {
  final list = [...runs];
  while (list.isNotEmpty && list.first.text.trim().isEmpty) {
    list.removeAt(0);
  }
  while (list.isNotEmpty && list.last.text.trim().isEmpty) {
    list.removeLast();
  }
  if (list.isEmpty) return list;
  final first = list.first, last = list.last;
  list[0] = DescRun(first.text.trimLeft(), bold: first.bold, italic: first.italic);
  final end = list.length - 1;
  list[end] = DescRun(
    (end == 0 ? list[0].text : last.text).trimRight(),
    bold: last.bold,
    italic: last.italic,
  );
  return list;
}
