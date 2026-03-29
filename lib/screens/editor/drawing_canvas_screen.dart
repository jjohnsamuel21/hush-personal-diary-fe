import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// A single stroke = a list of points drawn in one continuous finger drag
class _Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const _Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

// Full-screen free drawing canvas using finger/touch.
// Returns the saved image file path via Navigator.pop(filePath).
// The note editor receives this path and embeds the image.
class DrawingCanvasScreen extends StatefulWidget {
  const DrawingCanvasScreen({super.key});

  @override
  State<DrawingCanvasScreen> createState() => _DrawingCanvasScreenState();
}

class _DrawingCanvasScreenState extends State<DrawingCanvasScreen> {
  final List<_Stroke> _strokes = [];         // All completed strokes
  List<Offset> _currentPoints = [];          // Points in the current finger drag
  final _repaintKey = GlobalKey();           // Used to capture canvas as image

  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isEraser = false;
  bool _isSaving = false;

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentPoints = [d.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _currentPoints = [..._currentPoints, d.localPosition];
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_currentPoints.isEmpty) return;
    setState(() {
      _strokes.add(_Stroke(
        points: List.from(_currentPoints),
        color: _isEraser ? Colors.white : _selectedColor,
        strokeWidth: _isEraser ? 24.0 : _strokeWidth,
      ));
      _currentPoints = [];
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentPoints = [];
    });
  }

  // Captures the canvas widget as a PNG image and saves it to local storage.
  // Returns the file path so the note editor can embed it.
  Future<void> _saveAndReturn() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Find the RenderRepaintBoundary wrapping the canvas
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      // Render at 2x pixel ratio for crisp images on high-DPI screens
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Save to app's documents directory — persists until the user deletes the note
      final dir = await getApplicationDocumentsDirectory();
      final drawingsDir = Directory('${dir.path}/drawings');
      if (!drawingsDir.existsSync()) drawingsDir.createSync(recursive: true);

      final fileName = '${const Uuid().v4()}.png';
      final file = File('${drawingsDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      if (mounted) Navigator.of(context).pop(file.path);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save drawing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const canvasColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Draw'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last stroke',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear canvas',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveAndReturn,
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Insert'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Drawing canvas ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: canvasColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _CanvasPainter(
                          strokes: _strokes,
                          currentPoints: _currentPoints,
                          currentColor: _isEraser ? Colors.white : _selectedColor,
                          currentWidth: _isEraser ? 24.0 : _strokeWidth,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Toolbar ──
          _DrawingToolbar(
            selectedColor: _selectedColor,
            strokeWidth: _strokeWidth,
            isEraser: _isEraser,
            onColorSelected: (c) => setState(() {
              _selectedColor = c;
              _isEraser = false;
            }),
            onWidthChanged: (w) => setState(() => _strokeWidth = w),
            onEraserToggled: () => setState(() => _isEraser = !_isEraser),
          ),
        ],
      ),
    );
  }
}

// CustomPainter draws all completed strokes + the in-progress stroke.
class _CanvasPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;

  const _CanvasPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all saved strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth);
    }
    // Draw the current in-progress stroke
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentWidth);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Color color, double width) {
    if (points.length < 2) {
      // Single tap — draw a dot
      canvas.drawCircle(
        points.first,
        width / 2,
        Paint()..color = color,
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round   // rounded ends feel natural with fingers
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw smooth connected line through all points
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  // Repaint whenever any input changes
  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.strokes != strokes ||
      old.currentPoints != currentPoints ||
      old.currentColor != currentColor ||
      old.currentWidth != currentWidth;
}

// Toolbar at the bottom: color picker, stroke width slider, eraser
class _DrawingToolbar extends StatelessWidget {
  final Color selectedColor;
  final double strokeWidth;
  final bool isEraser;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onEraserToggled;

  static const _colors = [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Color(0xFF9C27B0),
    Colors.orange,
    Colors.teal,
  ];

  const _DrawingToolbar({
    required this.selectedColor,
    required this.strokeWidth,
    required this.isEraser,
    required this.onColorSelected,
    required this.onWidthChanged,
    required this.onEraserToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color row + eraser
            Row(
              children: [
                // Color chips
                ..._colors.map((c) => GestureDetector(
                      onTap: () => onColorSelected(c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (!isEraser && selectedColor == c)
                                ? colors.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                        ),
                      ),
                    )),
                const Spacer(),
                // Eraser button
                IconButton(
                  icon: Icon(
                    Icons.cleaning_services_rounded,
                    color: isEraser ? colors.primary : colors.outline,
                  ),
                  tooltip: 'Eraser',
                  onPressed: onEraserToggled,
                ),
              ],
            ),
            // Stroke width slider
            Row(
              children: [
                Icon(Icons.edit, size: 14, color: colors.outline),
                Expanded(
                  child: Slider(
                    value: strokeWidth,
                    min: 1.0,
                    max: 16.0,
                    divisions: 15,
                    onChanged: onWidthChanged,
                  ),
                ),
                Icon(Icons.edit, size: 22, color: colors.outline),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
