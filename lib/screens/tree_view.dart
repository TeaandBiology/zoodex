import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/species.dart';

/// A "tree of life" of the observed species. Two looks, switchable with the
/// toggle at the top:
///   • Tree — a radial deep-zoom cladogram (OneZoom-style). Branches radiate from
///     the centre; a clade you haven't zoomed into is a single labelled sector
///     (name + species count). Zoom into it and it "blooms" open into its
///     sub-clades, then species. Pinch to zoom, drag to pan.
///   • List — an indented, collapsible cladogram with connector lines.
///
/// Both use the species' taxonomic lineage (kingdom → … → species).
class TaxonomyTreeView extends StatefulWidget {
  final List<Species> species;
  final void Function(Species species) onOpenSpecies;

  const TaxonomyTreeView({
    super.key,
    required this.species,
    required this.onOpenSpecies,
  });

  @override
  State<TaxonomyTreeView> createState() => _TaxonomyTreeViewState();
}

enum _Mode { deep, bracket }

class _TaxonomyTreeViewState extends State<TaxonomyTreeView> {
  _Mode _mode = _Mode.deep;

  @override
  Widget build(BuildContext context) {
    if (widget.species.isEmpty) {
      return Center(
          child: Text(AppLocalizations.of(context).treeViewNoSightingsYet));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SegmentedButton<_Mode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: _Mode.deep,
                      icon: const Icon(Icons.hub_outlined),
                      label: Text(AppLocalizations.of(context).treeViewTree)),
                  ButtonSegment(
                      value: _Mode.bracket,
                      icon: const Icon(Icons.format_list_bulleted),
                      label: Text(AppLocalizations.of(context).treeViewList)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mode == _Mode.deep
              ? _DeepTree(
                  species: widget.species, onOpenSpecies: widget.onOpenSpecies)
              : _BracketTree(
                  species: widget.species, onOpenSpecies: widget.onOpenSpecies),
        ),
      ],
    );
  }
}

// --- Shared tree model -----------------------------------------------------

class _Node {
  final String label;
  final int depth; // 0 = root ("All life"); 1 = kingdom; … ; leaf = species
  final String group;
  final String key;
  final TaxonRank? rank;
  final Species? species;
  int leaves = 0;
  final Map<String, _Node> children = {};

  _Node(this.label, this.depth, this.group,
      {required this.key, this.rank, this.species});

  bool get isLeaf => species != null;
}

int _accumulate(_Node n) {
  if (n.children.isEmpty) return n.leaves;
  var total = 0;
  for (final c in n.children.values) {
    total += _accumulate(c);
  }
  n.leaves = total;
  return total;
}

_Node _buildTree(List<Species> list) {
  final root = _Node('All life', 0, '', key: 'root');
  for (final s in list) {
    var node = root;
    for (final step in s.taxonomy.lineage) {
      if (step.rank == TaxonRank.species) continue;
      node = node.children.putIfAbsent(
        step.value,
        () => _Node(step.value, node.depth + 1, s.majorGroup,
            key: '${node.key}/${step.value}', rank: step.rank),
      );
    }
    node.children.putIfAbsent(
      s.id,
      () => _Node(s.commonName, node.depth + 1, s.majorGroup,
          key: '${node.key}/sp:${s.id}', rank: TaxonRank.species, species: s),
    ).leaves = 1;
  }
  _accumulate(root);
  return root;
}

List<_Node> _sortedChildren(_Node n) => n.children.values.toList()
  ..sort((a, b) {
    if (a.isLeaf != b.isLeaf) return a.isLeaf ? 1 : -1;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });

const Map<String, Color> _groupColors = {
  'Mammals': Color(0xFF8D6E63),
  'Birds': Color(0xFF4F8FBA),
  'Reptiles': Color(0xFF66A05A),
  'Amphibians': Color(0xFF26A69A),
  'Fish': Color(0xFF2996C8),
  'Invertebrates': Color(0xFF9664AA),
};

Color _groupColor(String g) => _groupColors[g] ?? const Color(0xFF8A8A8A);

Color _shaded(_Node n) {
  final hsl = HSLColor.fromColor(_groupColor(n.group));
  final l = (hsl.lightness + (n.depth - 2) * 0.05).clamp(0.30, 0.82).toDouble();
  return hsl.withLightness(l).toColor();
}

// ===========================================================================
// Radial deep-zoom cladogram (OneZoom-style)
// ===========================================================================

class _Lay {
  final double angMin, angMax, angMid;
  _Lay(this.angMin, this.angMax, this.angMid);
}

const double _ringStep = 62; // radial distance per rank (scene px)
const double _rimPad = 48; // gap between deepest rank and the tip rim

class _DeepTree extends StatefulWidget {
  final List<Species> species;
  final void Function(Species species) onOpenSpecies;
  const _DeepTree({required this.species, required this.onOpenSpecies});

  @override
  State<_DeepTree> createState() => _DeepTreeState();
}

class _DeepTreeState extends State<_DeepTree> {
  final TransformationController _ctrl = TransformationController();
  late _Node _root;
  late Map<_Node, _Lay> _lay;
  late List<_Node> _leaves;
  late double _side, _rim, _slotAng;
  Offset get _center => Offset(_side / 2, _side / 2);
  bool _framed = false;

  double _rOf(_Node n) => n.isLeaf ? _rim : n.depth * _ringStep;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant _DeepTree old) {
    super.didUpdateWidget(old);
    _rebuild();
    _framed = false;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    _root = _buildTree(widget.species);
    _lay = {};
    _leaves = [];
    void collect(_Node n) {
      if (n.isLeaf) {
        _leaves.add(n);
        return;
      }
      for (final c in _sortedChildren(n)) {
        collect(c);
      }
    }

    collect(_root);
    final n = math.max(1, _leaves.length);
    const gap = 0.12;
    final span = 2 * math.pi - 2 * gap;
    final a0 = -math.pi / 2 + gap;
    _slotAng = span / n;
    var maxDepth = 1;
    final ang = <_Node, double>{};
    for (var i = 0; i < _leaves.length; i++) {
      ang[_leaves[i]] = a0 + span * (i + 0.5) / n;
      if (_leaves[i].depth > maxDepth) maxDepth = _leaves[i].depth;
    }
    _Lay comp(_Node node) {
      if (node.isLeaf) {
        final a = ang[node]!;
        return _lay[node] = _Lay(a, a, a);
      }
      var mn = double.infinity, mx = -double.infinity;
      for (final c in _sortedChildren(node)) {
        final cl = comp(c);
        mn = math.min(mn, cl.angMin);
        mx = math.max(mx, cl.angMax);
      }
      return _lay[node] = _Lay(mn, mx, (mn + mx) / 2);
    }

    comp(_root);
    _rim = maxDepth * _ringStep + _rimPad;
    _side = (_rim + 56) * 2;
  }

  void _onTap(Offset p, double scale) {
    if (_rim * _slotAng * scale < _DeepPainter._tipLabelPx) return;
    final rel = p - _center;
    if ((rel.distance - _rim).abs() > _ringStep) return;
    final a = math.atan2(rel.dy, rel.dx);
    _Node? best;
    var bd = _slotAng;
    for (final l in _leaves) {
      var d = (_lay[l]!.angMid - a) % (2 * math.pi);
      if (d > math.pi) d -= 2 * math.pi;
      if (d < -math.pi) d += 2 * math.pi;
      if (d.abs() < bd) {
        bd = d.abs();
        best = l;
      }
    }
    if (best != null) widget.onOpenSpecies(best.species!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, cons) {
        final vw = cons.maxWidth;
        final vh = cons.maxHeight.isFinite ? cons.maxHeight : vw;
        final fit = math.min(vw, vh) / _side;
        if (!_framed) {
          _framed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ctrl.value = Matrix4.identity()
              ..translate((vw - _side * fit) / 2, (vh - _side * fit) / 2)
              ..scale(fit);
          });
        }
        return InteractiveViewer(
          transformationController: _ctrl,
          constrained: false,
          minScale: fit * 0.6,
          maxScale: 24,
          boundaryMargin: EdgeInsets.symmetric(horizontal: vw, vertical: vh),
          child: SizedBox(
            width: _side,
            height: _side,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) =>
                  _onTap(d.localPosition, _ctrl.value.getMaxScaleOnAxis()),
              child: CustomPaint(
                size: Size(_side, _side),
                painter: _DeepPainter(
                  root: _root,
                  lay: _lay,
                  rOf: _rOf,
                  rim: _rim,
                  slotAng: _slotAng,
                  ctrl: _ctrl,
                  viewport: Size(vw, vh),
                  line: cs.outline,
                  text: cs.onSurface,
                  surface: cs.surface,
                  centreLabel: AppLocalizations.of(context).treeViewLife,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeepPainter extends CustomPainter {
  final _Node root;
  final Map<_Node, _Lay> lay;
  final double Function(_Node) rOf;
  final double rim, slotAng;
  final TransformationController ctrl;
  final Size viewport;
  final Color line, text, surface;
  final String centreLabel;

  _DeepPainter({
    required this.root,
    required this.lay,
    required this.rOf,
    required this.rim,
    required this.slotAng,
    required this.ctrl,
    required this.viewport,
    required this.line,
    required this.text,
    required this.surface,
    required this.centreLabel,
  }) : super(repaint: ctrl);

  static const double _expandPx = 70; // a clade opens when its arc exceeds this
  static const double _tipLabelPx = 11;

  late Offset _c;

  Offset _p(double r, double a) => _c + Offset(math.cos(a), math.sin(a)) * r;

  @override
  void paint(Canvas canvas, Size size) {
    _c = Offset(size.width / 2, size.height / 2);
    final scale = ctrl.value.getMaxScaleOnAxis();
    final view = Rect.fromPoints(
      ctrl.toScene(Offset.zero),
      ctrl.toScene(Offset(viewport.width, viewport.height)),
    ).inflate(_ringStep);

    void rotatedLabel(String s, double a, double r, double px,
        {bool bold = false}) {
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontSize: px,
                color: text,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 200);
      canvas.save();
      final at = _p(r, a);
      canvas.translate(at.dx, at.dy);
      if (math.cos(a) < 0) {
        canvas.rotate(a + math.pi);
        tp.paint(canvas, Offset(-tp.width, -tp.height / 2));
      } else {
        canvas.rotate(a);
        tp.paint(canvas, Offset(0, -tp.height / 2));
      }
      canvas.restore();
    }

    void draw(_Node n) {
      final l = lay[n]!;
      final box = _sectorBox(_c, rOf(n), rim + 30,
          l.angMin - slotAng, l.angMax + slotAng);
      if (!box.overlaps(view)) return;

      if (n.isLeaf) {
        canvas.drawCircle(
            _p(rim, l.angMid), 3.2, Paint()..color = _groupColor(n.group));
        if (rim * slotAng * scale >= _tipLabelPx) {
          rotatedLabel(n.label, l.angMid, rim + 8, 12);
        }
        return;
      }

      final arcOnScreen = (l.angMax - l.angMin) * rim * scale;
      if (arcOnScreen < _expandPx) {
        final col = n.depth <= 2 ? const Color(0xFFB0AEA6) : _groupColor(n.group);
        final wedge = _sectorPath(_c, rOf(n), rim, l.angMin, l.angMax);
        canvas.drawPath(wedge, Paint()..color = col.withValues(alpha: 0.85));
        canvas.drawPath(
            wedge,
            Paint()
              ..color = surface
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        if ((l.angMax - l.angMin) * rim * scale >= 16) {
          rotatedLabel('${n.label}  ·  ${n.leaves}', l.angMid, rim + 8, 12.5,
              bold: true);
        }
        return;
      }

      // Expanded: an arc at this node's radius across its children, then a radial
      // spoke out to each child.
      final kids = _sortedChildren(n);
      final mids = [for (final c in kids) lay[c]!.angMid];
      final rNode = rOf(n);
      if (rNode > 2) {
        canvas.drawArc(
            Rect.fromCircle(center: _c, radius: rNode),
            mids.reduce(math.min),
            mids.reduce(math.max) - mids.reduce(math.min),
            false,
            Paint()
              ..color = line.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4);
      }
      for (final c in kids) {
        final a = lay[c]!.angMid;
        canvas.drawLine(
            _p(rNode, a),
            _p(rOf(c), a),
            Paint()
              ..color = (c.depth <= 2 ? line : _groupColor(c.group))
                  .withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, 2.6 - c.depth * 0.25)
              ..strokeCap = StrokeCap.round);
        draw(c);
      }
    }

    draw(root);

    // Centre badge.
    canvas.drawCircle(_c, 22,
        Paint()..color = surface);
    canvas.drawCircle(
        _c,
        22,
        Paint()
          ..color = line.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    final tp = TextPainter(
      text: TextSpan(
          text: centreLabel,
          style: TextStyle(
              fontSize: 12, color: text, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, _c - Offset(tp.width / 2, tp.height / 2));
  }

  Path _sectorPath(Offset c, double r0, double r1, double a0, double a1) {
    return Path()
      ..moveTo(c.dx + math.cos(a0) * r0, c.dy + math.sin(a0) * r0)
      ..lineTo(c.dx + math.cos(a0) * r1, c.dy + math.sin(a0) * r1)
      ..arcTo(Rect.fromCircle(center: c, radius: r1), a0, a1 - a0, false)
      ..lineTo(c.dx + math.cos(a1) * r0, c.dy + math.sin(a1) * r0)
      ..arcTo(Rect.fromCircle(center: c, radius: r0), a1, -(a1 - a0), false)
      ..close();
  }

  Rect _sectorBox(Offset c, double r0, double r1, double a0, double a1) {
    var minx = double.infinity, miny = double.infinity;
    var maxx = -double.infinity, maxy = -double.infinity;
    void add(double r, double a) {
      final x = c.dx + math.cos(a) * r, y = c.dy + math.sin(a) * r;
      minx = math.min(minx, x);
      miny = math.min(miny, y);
      maxx = math.max(maxx, x);
      maxy = math.max(maxy, y);
    }

    add(r0, a0);
    add(r0, a1);
    add(r1, a0);
    add(r1, a1);
    for (var k = -2; k <= 4; k++) {
      final ax = k * math.pi / 2;
      if (ax >= a0 && ax <= a1) add(r1, ax);
    }
    return Rect.fromLTRB(minx, miny, maxx, maxy);
  }

  @override
  bool shouldRepaint(covariant _DeepPainter old) =>
      old.root != root || old.viewport != viewport;
}

// ===========================================================================
// Bracket (indented) tree
// ===========================================================================

const double _indent = 18;
const double _rowH = 44;

class _Row {
  final _Node node;
  final List<bool> hasNext;
  _Row(this.node, this.hasNext);
}

class _BracketTree extends StatefulWidget {
  final List<Species> species;
  final void Function(Species species) onOpenSpecies;
  const _BracketTree({required this.species, required this.onOpenSpecies});

  @override
  State<_BracketTree> createState() => _BracketTreeState();
}

class _BracketTreeState extends State<_BracketTree> {
  late _Node _root;
  final Map<String, bool> _userExpanded = {};

  @override
  void initState() {
    super.initState();
    _root = _buildTree(widget.species);
  }

  @override
  void didUpdateWidget(covariant _BracketTree old) {
    super.didUpdateWidget(old);
    _root = _buildTree(widget.species);
  }

  bool _isExpanded(_Node n) =>
      _userExpanded[n.key] ?? (n.depth < 3 || n.children.length <= 1);

  void _toggle(_Node n) =>
      setState(() => _userExpanded[n.key] = !_isExpanded(n));

  void _flatten(_Node node, List<bool> hasNext, List<_Row> out) {
    out.add(_Row(node, hasNext));
    if (node.isLeaf || !_isExpanded(node)) return;
    final kids = _sortedChildren(node);
    for (var i = 0; i < kids.length; i++) {
      final last = i == kids.length - 1;
      _flatten(kids[i], [...hasNext, !last], out);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[];
    _flatten(_root, const [], rows);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, i) => _buildRow(rows[i]),
    );
  }

  Widget _buildRow(_Row row) {
    final n = row.node;
    final depth = row.hasNext.length;
    final expandable = !n.isLeaf && n.children.isNotEmpty;
    final expanded = _isExpanded(n);
    final muted = Theme.of(context).colorScheme.outline;
    final lineColor = Theme.of(context).colorScheme.outlineVariant;

    return InkWell(
      onTap: () {
        if (n.isLeaf) {
          widget.onOpenSpecies(n.species!);
        } else if (expandable) {
          _toggle(n);
        }
      },
      child: SizedBox(
        height: _rowH,
        child: Row(
          children: [
            CustomPaint(
              size: Size(depth * _indent, _rowH),
              painter: _ConnectorPainter(row.hasNext, _indent, lineColor),
            ),
            SizedBox(
              width: 22,
              child: expandable
                  ? Icon(expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20, color: muted)
                  : null,
            ),
            Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: _shaded(n), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                n.depth == 0
                    ? AppLocalizations.of(context).treeViewAllLife
                    : n.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: n.isLeaf
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (!n.isLeaf && n.rank != null) ...[
              const SizedBox(width: 8),
              Text(n.rank!.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: muted)),
            ],
            const SizedBox(width: 10),
            if (n.isLeaf)
              Icon(Icons.chevron_right, size: 18, color: muted)
            else
              Text('${n.leaves}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: muted)),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final List<bool> hasNext;
  final double indent;
  final Color color;
  _ConnectorPainter(this.hasNext, this.indent, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final h = size.height;
    final mid = h / 2;
    for (var i = 0; i < hasNext.length; i++) {
      final x = i * indent + indent / 2;
      final isSelf = i == hasNext.length - 1;
      if (!isSelf) {
        if (hasNext[i]) canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, mid), paint);
        canvas.drawLine(Offset(x, mid), Offset(x + indent / 2, mid), paint);
        if (hasNext[i]) canvas.drawLine(Offset(x, mid), Offset(x, h), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.hasNext.length != hasNext.length || old.color != color;
}
