// widgets/alertas_badge.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/alerta_separado.dart';

const _colorError   = Color(0xFFA12C7B);
const _colorWarning = Color(0xFFDA7101);
const _teal         = Color(0xFF01696F);

class AlertasBadge extends StatelessWidget {
  final int                  total;
  final VoidCallback?        onTap;
  final bool                 compacto;
  final List<AlertaSeparado> vencidos;
  final List<AlertaSeparado> porVencer;

  const AlertasBadge({
    super.key,
    required this.total,
    this.onTap,
    this.compacto = false,
    this.vencidos  = const [],
    this.porVencer = const [],
  });

  Color get _color => total > 0
      ? _colorError
      : const Color(0xFF7A7974);

  Color get _bg => total > 0
      ? const Color(0xFFE0CED7)
      : const Color(0xFFF3F0EC);

  String get _label {
    if (total == 0) return 'Sin alertas';
    if (total == 1) return '1 alerta';
    return '$total alertas';
  }

  void _mostrarPanel(BuildContext context, RenderBox box) {
    final offset = box.localToGlobal(Offset.zero);
    final size   = box.size;

    showDialog(
      context:           context,
      barrierColor:      Colors.transparent,
      barrierDismissible: true,
      builder: (_) => _AlertasPanel(
        vencidos:   vencidos,
        porVencer:  porVencer,
        anchorOffset: offset,
        anchorSize:   size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 10 : 12,
        vertical:   compacto ? 6  : 8,
      ),
      decoration: BoxDecoration(
        color:        _bg,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                total > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size:  compacto ? 15 : 16,
                color: _color,
              ),
              if (total > 0)
                Positioned(
                  right: -1,
                  top:   -1,
                  child: Container(
                    width:  8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _colorError,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 7),
          Text(
            _label,
            style: GoogleFonts.poppins(
              fontSize:   compacto ? 11 : 12,
              fontWeight: FontWeight.w600,
              color:      _color,
            ),
          ),
        ],
      ),
    );

    // Si no hay alertas, no hay panel
    if (total == 0) return child;

    return InkWell(
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) _mostrarPanel(context, box);
        onTap?.call();
      },
      borderRadius: BorderRadius.circular(20),
      child: child,
    );
  }
}


// ─── PANEL ────────────────────────────────────────────────────
class _AlertasPanel extends StatefulWidget {
  final List<AlertaSeparado> vencidos;
  final List<AlertaSeparado> porVencer;
  final Offset               anchorOffset;
  final Size                 anchorSize;

  const _AlertasPanel({
    required this.vencidos,
    required this.porVencer,
    required this.anchorOffset,
    required this.anchorSize,
  });

  @override
  State<_AlertasPanel> createState() => _AlertasPanelState();
}

class _AlertasPanelState extends State<_AlertasPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _scale;
  late final Animation<double>    _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    await _ctrl.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screen     = MediaQuery.of(context).size;
    const panelWidth = 300.0;

    // Posición: debajo del badge, alineado a la derecha
    double left = widget.anchorOffset.dx + widget.anchorSize.width - panelWidth;
    double top  = widget.anchorOffset.dy + widget.anchorSize.height + 8;

    // Ajustar si sale de pantalla
    if (left < 8) left = 8;
    if (left + panelWidth > screen.width - 8) {
      left = screen.width - panelWidth - 8;
    }

    return GestureDetector(
      onTap: _cerrar,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            left:  left,
            top:   top,
            width: panelWidth,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale:     _scale,
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () {}, // evita cerrar al tocar el panel
                  child: _PanelContent(
                    vencidos:  widget.vencidos,
                    porVencer: widget.porVencer,
                    onCerrar:  _cerrar,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── CONTENIDO DEL PANEL ──────────────────────────────────────
class _PanelContent extends StatelessWidget {
  final List<AlertaSeparado> vencidos;
  final List<AlertaSeparado> porVencer;
  final VoidCallback         onCerrar;

  const _PanelContent({
    required this.vencidos,
    required this.porVencer,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation:    8,
      shadowColor:  Colors.black26,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded,
                      size: 18, color: _colorError),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Historial de alertas',
                      style: GoogleFonts.poppins(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF28251D),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:   onCerrar,
                    icon:        const Icon(Icons.close_rounded, size: 18),
                    color:       const Color(0xFF7A7974),
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEDEAE5)),

            // ── Lista ──
            Flexible(
              child: ListView(
                padding:  const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                children: [
                  if (vencidos.isNotEmpty) ...[
                    _SeccionHeader(
                      label: 'Vencidos (${vencidos.length})',
                      color: _colorError,
                      icon:  Icons.error_outline_rounded,
                    ),
                    ...vencidos.map((a) => _AlertaItem(alerta: a)),
                  ],
                  if (porVencer.isNotEmpty) ...[
                    if (vencidos.isNotEmpty)
                      const SizedBox(height: 4),
                    _SeccionHeader(
                      label: 'Por vencer (${porVencer.length})',
                      color: _colorWarning,
                      icon:  Icons.schedule_rounded,
                    ),
                    ...porVencer.map((a) => _AlertaItem(alerta: a)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


// ─── HEADER DE SECCIÓN ────────────────────────────────────────
class _SeccionHeader extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;

  const _SeccionHeader({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
    child: Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize:      11,
            fontWeight:    FontWeight.w700,
            color:         color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}


// ─── ÍTEM DE ALERTA ───────────────────────────────────────────
class _AlertaItem extends StatelessWidget {
  final AlertaSeparado alerta;
  const _AlertaItem({required this.alerta});

  @override
  Widget build(BuildContext context) {
    final esVencido = alerta.esVencido;
    final color     = esVencido ? _colorError : _colorWarning;
    final bgColor   = esVencido
        ? const Color(0xFFE0CED7)
        : const Color(0xFFE7D7C4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Container(
        padding:    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        bgColor.withOpacity(0.45),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono
            Container(
              margin:     const EdgeInsets.only(top: 1),
              padding:    const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color:  color.withOpacity(0.12),
                shape:  BoxShape.circle,
              ),
              child: Icon(
                esVencido
                    ? Icons.warning_amber_rounded
                    : Icons.access_time_rounded,
                size:  13,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alerta.cliente,
                    style: GoogleFonts.poppins(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      const Color(0xFF28251D),
                    ),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alerta.etiquetaDias,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color:    color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Saldo: \$${alerta.saldoPendiente.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color:    const Color(0xFF7A7974),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}