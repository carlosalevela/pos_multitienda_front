import 'package:flutter/material.dart';

enum MedioPago { efectivo, datafono, davivienda, daviplata, bancolombia, nequi, bono }

extension MedioPagoX on MedioPago {
  String get etiqueta => switch (this) {
        MedioPago.efectivo    => 'EFECTIVO',
        MedioPago.datafono    => 'DATÁFONO',
        MedioPago.davivienda  => 'TRANSF.\nDAVIVIENDA',
        MedioPago.daviplata   => 'DAVIPLATA',
        MedioPago.bancolombia => 'TRANSF.\nBANCOLOMBIA',
        MedioPago.nequi       => 'NEQUI',
        MedioPago.bono        => 'BONO',
      };
}

class FilaRegistro {
  final String signo;
  final String concepto;
  final int cantidad;
  final Map<MedioPago, double> montos;
  final String? nota;

  const FilaRegistro({
    required this.signo,
    required this.concepto,
    this.cantidad = 0,
    this.montos = const {},
    this.nota,
  });

  double get total => montos.values.fold(0, (a, b) => a + b);
}

class RegistroMovimientoData {
  final String almacen;
  final DateTime fecha;
  final String encargado;
  final int numeroVentas;
  final double totalVentas;
  final List<FilaRegistro> filas;
  final FilaRegistro totalEntregado;
  final String observaciones;
  final String realizo;

  const RegistroMovimientoData({
    required this.almacen,
    required this.fecha,
    required this.encargado,
    required this.numeroVentas,
    required this.totalVentas,
    required this.filas,
    required this.totalEntregado,
    this.observaciones = '',
    required this.realizo,
  });
}

class RegistroMovimientoDiario extends StatelessWidget {
  final RegistroMovimientoData data;
  final double anchoDiseno;

  const RegistroMovimientoDiario({
    super.key,
    required this.data,
    this.anchoDiseno = 960,
  });

  static const int _fConcepto = 27;
  static const int _fNum      = 4;
  static const int _fMonto    = 9;
  static const int _fMontos   = _fMonto * 8;

  static const Color      _ink    = Colors.black;
  static const BorderSide _fina   = BorderSide(color: _ink, width: 1);
  static const BorderSide _gruesa = BorderSide(color: _ink, width: 2);

  @override
  Widget build(BuildContext context) {
    final hoja = DefaultTextStyle(
      style: const TextStyle(
        color: _ink, fontSize: 12, fontWeight: FontWeight.w700, height: 1.15,
      ),
      child: Container(
        width: anchoDiseno,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _ink, width: 2.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _encabezado(),
            _datosGenerales(),
            _cabeceraTabla(),
            for (final f in data.filas) _filaMovimiento(f),
            _filaMovimiento(data.totalEntregado, destacada: true),
            _observaciones(),
            _firmas(),
          ],
        ),
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      final escala = c.maxWidth.isFinite && c.maxWidth < anchoDiseno
          ? c.maxWidth / anchoDiseno
          : 1.0;
      return Center(
        child: SizedBox(
          width: anchoDiseno * escala,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: hoja,
          ),
        ),
      );
    });
  }

  Widget _encabezado() => _fila(
        borde: _gruesa,
        alto: 66,
        celdas: [
          _Celda(
            flex: 50,
            child: _etiquetaValor('NOMBRE DEL ALMACÉN / BODEGA', data.almacen, tamValor: 19),
          ),
          const _Celda(
            flex: 50,
            align: Alignment.center,
            child: Text('REGISTRO DE MOVIMIENTO DIARIO',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ],
      );

  Widget _datosGenerales() => _fila(
        alto: 36,
        celdas: [
          _Celda(flex: 30, child: _etiquetaValor('FECHA', _fecha(data.fecha))),
          _Celda(flex: 30,
              child: _etiquetaValor('NOMBRE DE ENCARGADO', data.encargado, tamValor: 14)),
          _Celda(
            flex: 33,
            child: _etiquetaValor(
              '(+) NÚMERO TOTAL DE VENTAS',
              '${data.numeroVentas}   ${_dinero(data.totalVentas, conSigno: true)}',
            ),
          ),
        ],
      );

  Widget _cabeceraTabla() => _fila(
        alto: 34,
        celdas: [
          const _Celda(flex: _fConcepto, child: SizedBox()),
          const _Celda(flex: _fNum,      child: SizedBox()),
          for (final m in MedioPago.values)
            _Celda(flex: _fMonto, align: Alignment.center, child: _th(m.etiqueta)),
          _Celda(flex: _fMonto, align: Alignment.center, child: _th('TOTAL')),
        ],
      );

  Widget _filaMovimiento(FilaRegistro f, {bool destacada = false}) {
    final size  = destacada ? 14.0 : 12.0;
    final peso  = destacada ? FontWeight.w900 : FontWeight.w700;
    final estilo = TextStyle(fontSize: size, fontWeight: peso);

    final concepto = Text.rich(TextSpan(children: [
      TextSpan(text: '(${f.signo}) ',
          style: TextStyle(fontSize: size + 1, fontWeight: FontWeight.w900)),
      TextSpan(text: f.concepto, style: estilo),
    ]));

    final celdas = <_Celda>[
      _Celda(flex: _fConcepto, child: concepto),
      _Celda(flex: _fNum, align: Alignment.center,
          child: Text(f.cantidad == 0 ? '' : '${f.cantidad}', style: estilo)),
    ];

    if (f.nota != null) {
      celdas.add(_Celda(
        flex: _fMontos,
        child: Text(f.nota!,
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic)),
      ));
    } else {
      for (final m in MedioPago.values) {
        celdas.add(_Celda(
          flex: _fMonto, align: Alignment.center,
          child: Text(_dinero(f.montos[m]), style: estilo),
        ));
      }
      celdas.add(_Celda(
        flex: _fMonto, align: Alignment.center,
        child: Text(_dinero(f.total), style: estilo),
      ));
    }

    return _fila(
      alto:        destacada ? 34 : 30,
      borde:       destacada ? _gruesa : _fina,
      bordeArriba: destacada ? _gruesa : null,
      celdas:      celdas,
    );
  }

  Widget _observaciones() => _fila(
        alto: 66,
        borde: _gruesa,
        celdas: [
          const _Celda(
            flex: 16, align: Alignment.topLeft,
            child: Text('OBSERVACIONES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          _Celda(
            flex: 77, align: Alignment.topLeft,
            child: Stack(children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(2,
                    (_) => const Divider(height: 1, thickness: 1, color: Colors.black54)),
              ),
              if (data.observaciones.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(data.observaciones,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w400)),
                ),
            ]),
          ),
        ],
      );

  Widget _firmas() => _fila(
        alto: 78,
        borde: BorderSide.none,
        celdas: [
          _Celda(flex: 50, align: Alignment.topLeft,
              child: _firma('REALIZÓ', data.realizo)),
          _Celda(flex: 50, align: Alignment.topLeft,
              child: _firma('FECHA DE RECIBIDO', '')),
        ],
      );

  Widget _fila({
    required List<_Celda> celdas,
    double alto = 30,
    BorderSide borde = _fina,
    BorderSide? bordeArriba,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: alto),
      decoration: BoxDecoration(
        border: Border(bottom: borde, top: bordeArriba ?? BorderSide.none),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < celdas.length; i++)
              Expanded(
                flex: celdas[i].flex,
                child: Container(
                  alignment: celdas[i].align,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border(
                      right: i == celdas.length - 1 ? BorderSide.none : _fina,
                    ),
                  ),
                  child: celdas[i].child,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _etiquetaValor(String etiqueta, String valor, {double tamValor = 13}) =>
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: tamValor, fontWeight: FontWeight.w900)),
        ],
      );

  Widget _th(String t) => Text(t,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, height: 1.05));

  Widget _firma(String etiqueta, String nombre) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(etiqueta,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const Spacer(),
          const Divider(height: 1, thickness: 1.2, color: Colors.black),
          const SizedBox(height: 4),
          Text(nombre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
        ],
      );

  static String _fecha(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)} / ${dos(d.month)} / ${dos(d.year % 100)}';
  }

  static String _dinero(double? v, {bool conSigno = false}) {
    if (v == null || v == 0) return conSigno ? '\$0' : '';
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}${conSigno ? '\$' : ''}$b';
  }
}

class _Celda {
  final int flex;
  final Widget child;
  final Alignment align;
  const _Celda({
    required this.flex,
    required this.child,
    this.align = Alignment.centerLeft,
  });
}
