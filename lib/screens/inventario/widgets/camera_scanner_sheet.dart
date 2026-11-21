// lib/screens/inventario/widgets/camera_scanner_sheet.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerSheet extends StatefulWidget {
  final void Function(String barcode) onDetect;
  const CameraScannerSheet({super.key, required this.onDetect});

  @override
  State<CameraScannerSheet> createState() => _CameraScannerSheetState();
}

class _CameraScannerSheetState extends State<CameraScannerSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _ctrl;
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineAnim;
  bool _detected = false;

  static const _greenMid = Color(0xFF059669);
  static const _greenDim = Color(0xFF6EE7B7);

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() => _detected = true);
    _lineCtrl.stop();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDetect(raw);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            MobileScanner(controller: _ctrl, onDetect: _onDetect),
            // Overlay oscuro
            AnimatedOpacity(
              opacity: _detected ? 0.3 : 0.6,
              duration: const Duration(milliseconds: 300),
              child: const ColoredBox(
                  color: Colors.black, child: SizedBox.expand()),
            ),
            // Marco de escaneo
            Center(
              child: SizedBox(
                width: 240,
                height: 140,
                child: Stack(
                  children: [
                    Positioned(top: 0, left: 0,
                        child: _Corner(top: true, left: true)),
                    Positioned(top: 0, right: 0,
                        child: _Corner(top: true, left: false)),
                    Positioned(bottom: 0, left: 0,
                        child: _Corner(top: false, left: true)),
                    Positioned(bottom: 0, right: 0,
                        child: _Corner(top: false, left: false)),
                    if (!_detected)
                      AnimatedBuilder(
                        animation: _lineAnim,
                        builder: (ctx, snap) => Positioned(
                          top: 8 + _lineAnim.value * 116,
                          left: 8, right: 8,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Colors.transparent,
                                Color(0xFF10B981),
                                Colors.transparent,
                              ]),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withAlpha(120),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_detected)
                      Center(
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: _greenMid.withAlpha(220),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Topbar
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                color: Colors.black54,
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Escáner de inventario',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            // Hint
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Text(
                _detected
                    ? 'Producto encontrado'
                    : 'Apunta al código de barras del producto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _detected ? _greenDim : Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      _detected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool top, left;
  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22, height: 22,
      child: CustomPaint(
        painter: _CornerPainter(top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top, left;
  _CornerPainter({required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF6EE7B7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final x0 = left ? 0.0 : size.width;
    final y0 = top ? 0.0 : size.height;
    final x1 = left ? size.width : 0.0;
    final y1 = top ? size.height : 0.0;
    canvas.drawLine(Offset(x0, y0), Offset(x1, y0), p);
    canvas.drawLine(Offset(x0, y0), Offset(x0, y1), p);
  }

  @override
  bool shouldRepaint(_CornerPainter o) => false;
}
