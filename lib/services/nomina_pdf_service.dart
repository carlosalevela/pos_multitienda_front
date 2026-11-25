// lib/services/nomina_pdf_service.dart
//
// PDFs de nómina con el formato que ya usan las tiendas:
//   - Planilla de la quincena (horizontal): bloque NÓMINA, bloque TEMPORAL y
//     los pagos.
//   - Desprendible de cada persona (ingresos, deducciones, neto, pagado y
//     firmas).
//   - Planilla del mes (para la contabilidad).
//   - Liquidación de salida, con los anexos pegados al final.
//   - Memorando para imprimir y firmar.
//
// Con la fuente estándar del PDF: solo caracteres latinos (nada de "−").

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'nomina_service.dart';

const _verde = PdfColor.fromInt(0xFF006C49);
const _salmon = PdfColor.fromInt(0xFFF4D9CC);
const _salmonClaro = PdfColor.fromInt(0xFFFBEDE6);
const _gris = PdfColor.fromInt(0xFFA6A6A6);
const _grisClaro = PdfColor.fromInt(0xFFE5E7EB);
const _texto2 = PdfColor.fromInt(0xFF555555);

String _n(num v) => pesosNomina(v).replaceFirst(r'$', '');
String _p(num v) => pesosNomina(v);

pw.TextStyle _t(double s, {bool b = false, PdfColor? c}) => pw.TextStyle(
    fontSize: s, fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: c ?? PdfColors.black);

pw.Widget _celda(String s, {bool b = false, double size = 8,
        pw.TextAlign a = pw.TextAlign.left, PdfColor? fondo}) =>
    pw.Container(
      color: fondo,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(s, textAlign: a, style: _t(size, b: b)),
    );

pw.Widget _banda(String s, {pw.Alignment al = pw.Alignment.center}) => pw.Container(
      width: double.infinity,
      alignment: al,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      decoration: pw.BoxDecoration(color: _salmon, border: pw.Border.all(color: _texto2, width: .6)),
      child: pw.Text(s, style: _t(9, b: true)),
    );

pw.Widget _firmas(String trabajador, String cedula, String empleador,
        {String rotuloTrabajador = 'Firma del trabajador'}) =>
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: _lineaFirma(rotuloTrabajador, trabajador,
          cedula.isEmpty ? '' : 'C.C. ${_cedula(cedula)}')),
      pw.SizedBox(width: 40),
      pw.Expanded(child: _lineaFirma('Firma del empleador', empleador, '')),
    ]);

pw.Widget _lineaFirma(String rotulo, String nombre, String extra) => pw.Column(children: [
      pw.Container(height: .8, color: PdfColors.black),
      pw.SizedBox(height: 4),
      pw.Text(rotulo, style: _t(8.5, c: _texto2)),
      if (nombre.isNotEmpty) pw.Text(nombre, style: _t(9, b: true)),
      if (extra.isNotEmpty) pw.Text(extra, style: _t(8.5)),
    ]);

/// 1088234567 → 1.088.234.567
String _cedula(String c) {
  final d = c.replaceAll('.', '');
  if (int.tryParse(d) == null) return c;
  return _n(int.parse(d));
}

const _nota = 'Soporte interno de pago. No reemplaza el documento soporte de nómina '
    'electrónica ante la DIAN.';

class NominaPdf {
  // ── Planilla de la quincena ─────────────────────────────────

  static Future<Uint8List> planilla(QuincenaNomina q) async {
    final doc = pw.Document(title: 'Planilla ${q.periodo}');
    final nom = q.guardadas.where((f) => f.esNomina).toList();
    final tmp = q.guardadas.where((f) => !f.esNomina).toList();
    final pagos = [
      for (final f in q.guardadas)
        for (final p in f.pagos) (f.nombres, p),
    ]..sort((a, b) => a.$2.fecha.compareTo(b.$2.fecha));

    pw.Widget meta(List<(String, String)> items) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(color: _salmonClaro,
              border: pw.Border.all(color: _texto2, width: .6)),
          child: pw.Row(children: [
            for (final (k, v) in items) ...[
              pw.Text(k, style: _t(8)),
              pw.SizedBox(width: 6),
              pw.Text(v, style: _t(8.5, b: true)),
              pw.SizedBox(width: 26),
            ],
          ]),
        );

    pw.Widget tabla(List<String> cab, List<List<String>> filas, List<String>? total,
            Map<int, pw.TableColumnWidth> anchos, Set<int> derecha) =>
        pw.Table(
          border: pw.TableBorder.all(color: _texto2, width: .5),
          columnWidths: anchos,
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _salmon), children: [
              for (final c in cab) _celda(c, b: true, size: 6.5, a: pw.TextAlign.center),
            ]),
            for (final f in filas)
              pw.TableRow(children: [
                for (var i = 0; i < f.length; i++)
                  _celda(f[i], size: 7.5, a: derecha.contains(i) ? pw.TextAlign.right : pw.TextAlign.left),
              ]),
            if (total != null)
              pw.TableRow(decoration: const pw.BoxDecoration(color: _salmonClaro), children: [
                for (var i = 0; i < total.length; i++)
                  _celda(total[i], b: true, size: 7.5,
                      a: derecha.contains(i) ? pw.TextAlign.right : pw.TextAlign.left),
              ]),
          ],
        );

    int s(List<FilaQuincena> l, int Function(CalculoFila) f) =>
        l.fold(0, (a, x) => a + f(x.calculo));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        if (nom.isNotEmpty) ...[
          _banda('NÓMINA'),
          meta([('EMPLEADOR', q.empleador.isEmpty ? '-' : q.empleador),
                ('TIENDA', q.tiendaNombre), ('PERIODO', q.periodo)]),
          pw.SizedBox(height: 4),
          tabla(
            ['NOMBRES Y APELLIDOS', 'CC', 'SUELDO BÁSICO', 'DÍAS TRAB.', 'SUELDO',
             'AUX. TRANSP.', 'TOTAL DEVENGADO', 'SALUD', 'PENSIÓN', 'ROBOS/ DAÑOS',
             'ADELANTOS', 'TOTAL DEDUCIDO', 'PAGAR', 'FIRMA'],
            [
              for (final f in nom)
                [f.nombres.toUpperCase(), _cedula(f.cedula),
                 _n(f.ganaMinimo ? q.salarioMinimo : (f.valorDia * 30).round()),
                 diasTexto(f.dias), _n(f.calculo.sueldo), _n(f.calculo.auxilio),
                 _n(f.calculo.devengado), _n(f.calculo.salud), _n(f.calculo.pension),
                 _n(f.calculo.danos), _n(f.calculo.adelantos), _n(f.calculo.deducido),
                 _n(f.calculo.pagar), ''],
            ],
            ['TOTAL', '', '', '', _n(s(nom, (c) => c.sueldo)), _n(s(nom, (c) => c.auxilio)),
             _n(s(nom, (c) => c.devengado)), _n(s(nom, (c) => c.salud)),
             _n(s(nom, (c) => c.pension)), _n(s(nom, (c) => c.danos)),
             _n(s(nom, (c) => c.adelantos)), _n(s(nom, (c) => c.deducido)),
             _n(s(nom, (c) => c.pagar)), ''],
            {0: const pw.FlexColumnWidth(2.6), 13: const pw.FlexColumnWidth(1.6)},
            {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},
          ),
          pw.SizedBox(height: 14),
        ],
        if (tmp.isNotEmpty) ...[
          _banda('TEMPORAL'),
          meta([('TIENDA', q.tiendaNombre), ('PERIODO', q.periodo)]),
          pw.SizedBox(height: 4),
          tabla(
            ['NOMBRES Y APELLIDOS', 'CC', 'VALOR DÍA', 'FECHAS', 'DÍAS', 'TOTAL',
             'ROBOS/ DAÑOS', 'ADELANTOS', 'TOTAL A PAGAR', 'FIRMA'],
            [
              for (final f in tmp)
                [f.nombres.toUpperCase(), _cedula(f.cedula), _n(f.valorDia), f.fechas,
                 diasTexto(f.dias), _n(f.calculo.sueldo), _n(f.calculo.danos),
                 _n(f.calculo.adelantos), _n(f.calculo.pagar), ''],
            ],
            ['TOTAL', '', '', '', '', _n(s(tmp, (c) => c.sueldo)), _n(s(tmp, (c) => c.danos)),
             _n(s(tmp, (c) => c.adelantos)), _n(s(tmp, (c) => c.pagar)), ''],
            {0: const pw.FlexColumnWidth(2.6), 3: const pw.FlexColumnWidth(2.4),
             9: const pw.FlexColumnWidth(1.6)},
            {2, 4, 5, 6, 7, 8},
          ),
          pw.SizedBox(height: 14),
        ],
        _banda('PAGOS', al: pw.Alignment.centerLeft),
        pw.SizedBox(height: 4),
        if (pagos.isEmpty)
          pw.Text('Todavía no hay pagos registrados.', style: _t(8, c: _texto2))
        else
          tabla(['PERSONA', 'FECHA', 'MEDIO DE PAGO', 'VALOR'], [
            for (final (n, p) in pagos) [n, fechaCorta(p.fecha), p.medio, _n(p.valor)],
          ], ['TOTAL PAGADO', '', '', _n(q.totalPagado)], {}, {3}),
        pw.SizedBox(height: 8),
        pw.Text('Total a pagar: ${_p(q.totalPagar)}   ·   Pagado: ${_p(q.totalPagado)}   ·   '
            'Falta: ${_p(q.totalPagar - q.totalPagado)}', style: _t(8.5, b: true)),
        pw.SizedBox(height: 6),
        pw.Text(_nota, style: _t(7, c: _texto2)),
      ],
    ));
    return doc.save();
  }

  // ── Desprendibles ───────────────────────────────────────────

  static Future<Uint8List> desprendibles(QuincenaNomina q, List<FilaQuincena> filas) async {
    final doc = pw.Document(title: 'Desprendibles ${q.periodo}');
    final ini = q.numero == 1 ? 1 : 16;
    final fin = q.numero == 1 ? 15 : DateTime(q.anio, q.mes + 1, 0).day;
    final desde = fechaCorta(DateTime(q.anio, q.mes, ini));
    final hasta = fechaCorta(DateTime(q.anio, q.mes, fin));
    for (final f in filas) {
      final c = f.calculo;
      final ultimoPago = f.pagos.isEmpty ? null : f.pagos.last;
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _encabezado(q.tiendaNombre, 'DESPRENDIBLE DE PAGO DE NÓMINA', [
            ('Periodo de pago:', '$desde - $hasta'),
            ('Comprobante número:', '${f.comprobante ?? '-'}'),
            ('Nombre:', f.nombres.toUpperCase()),
            ('Identificación:', f.cedula.isEmpty ? '-' : _cedula(f.cedula)),
            ('Cargo:', f.cargo.isEmpty ? '-' : f.cargo),
            if (f.esNomina)
              ('Sueldo básico:', '${_n(f.ganaMinimo ? q.salarioMinimo : (f.valorDia * 30).round())} al mes')
            else
              ('Valor del día:', _n(f.valorDia)),
            ('Tipo:', f.esNomina ? 'Nómina' : 'Temporal'),
            ('Fecha de emisión:', fechaCorta(ultimoPago?.fecha ?? DateTime.now())),
          ]),
          pw.SizedBox(height: 14),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: _bloque('INGRESOS', ['Concepto', 'Cantidad', 'Valor'], [
              [f.esNomina ? 'Sueldo' : 'Días trabajados × ${_n(f.valorDia)}', diasTexto(f.dias), _n(c.sueldo)],
              if (f.esNomina && c.auxilio > 0) ['Auxilio de transporte', diasTexto(f.dias), _n(c.auxilio)],
            ], ['Total de ingresos', '', _n(c.devengado)])),
            pw.SizedBox(width: 16),
            pw.Expanded(child: pw.Column(children: [
              _bloque('DEDUCCIONES', ['Concepto', '%', 'Valor'], [
                if (f.esNomina) ['Fondo de salud', '4 %', _n(c.salud)],
                if (f.esNomina) ['Fondo de pensión', '4 %', _n(c.pension)],
                if (c.danos > 0) ['Robos / daños (autorizado)', '', _n(c.danos)],
                if (c.adelantos > 0) ['Adelantos', '', _n(c.adelantos)],
                if (c.deducido == 0) ['Sin deducciones', '', '0'],
              ], ['Total deducciones', '', _n(c.deducido)]),
              pw.SizedBox(height: 10),
              _barra('NETO A PAGAR', _n(c.neto)),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Row(children: [
                  pw.Text(f.pagado >= c.pagar ? 'PAGADO' : 'A PAGAR', style: _t(10, b: true)),
                  pw.Spacer(),
                  pw.Text(_n(c.pagar), style: _t(10, b: true)),
                ]),
              ),
            ])),
          ]),
          if (f.fechas.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Fechas trabajadas: ${f.fechas}', style: _t(9)),
          ],
          pw.SizedBox(height: 10),
          pw.Text('Medio de pago:', style: _t(9, c: _texto2)),
          if (f.pagos.isEmpty)
            pw.Text('Pendiente', style: _t(9.5, b: true))
          else
            for (final p in f.pagos)
              pw.Text('${fechaCorta(p.fecha)} · ${p.medio} · ${_p(p.valor)}', style: _t(9.5, b: true)),
          if (f.cuentaPago.isNotEmpty)
            pw.Text('Cuenta del colaborador: ${f.cuentaPago}', style: _t(9)),
          pw.SizedBox(height: 54),
          _firmas(f.nombres, f.cedula, q.empleador),
          pw.Spacer(),
          pw.Center(child: pw.Text(_nota, style: _t(7.5, c: _texto2))),
        ]),
      ));
    }
    return doc.save();
  }

  static pw.Widget _encabezado(String tienda, String titulo, List<(String, String)> datos) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _verde, width: 2))),
          child: pw.Row(children: [
            pw.Text(tienda.toUpperCase(), style: _t(14, b: true)),
            pw.Spacer(),
            pw.Text(titulo, style: _t(9.5, b: true, c: _verde)),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Wrap(spacing: 0, runSpacing: 4, children: [
          for (final (k, v) in datos)
            pw.SizedBox(
              width: 260,
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.SizedBox(width: 105, child: pw.Text(k, style: _t(9, c: _texto2))),
                pw.Expanded(child: pw.Text(v, style: _t(9.5, b: true))),
              ]),
            ),
        ]),
      ]);

  static pw.Widget _barra(String a, String b) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: pw.BoxDecoration(color: _gris, border: pw.Border.all(width: .7)),
        child: pw.Row(children: [
          pw.Text(a, style: _t(10, b: true)),
          pw.Spacer(),
          pw.Text(b, style: _t(10, b: true)),
        ]),
      );

  static pw.Widget _bloque(String titulo, List<String> cab, List<List<String>> filas,
          List<String> total) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(color: _gris, border: pw.Border.all(width: .7)),
          child: pw.Text(titulo, style: _t(10, b: true)),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
          columnWidths: {0: const pw.FlexColumnWidth(2.4), 1: const pw.FlexColumnWidth(1),
                         2: const pw.FlexColumnWidth(1.3)},
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _grisClaro), children: [
              _celda(cab[0], b: true, size: 8.5),
              _celda(cab[1], b: true, size: 8.5, a: pw.TextAlign.right),
              _celda(cab[2], b: true, size: 8.5, a: pw.TextAlign.right),
            ]),
            for (final f in filas)
              pw.TableRow(children: [
                _celda(f[0], size: 9),
                _celda(f[1], size: 9, a: pw.TextAlign.right),
                _celda(f[2], size: 9, a: pw.TextAlign.right),
              ]),
            pw.TableRow(children: [
              _celda(total[0], b: true, size: 9),
              _celda(total[1], size: 9),
              _celda(total[2], b: true, size: 9, a: pw.TextAlign.right),
            ]),
          ],
        ),
      ]);

  // ── Planilla del mes ────────────────────────────────────────

  static Future<Uint8List> planillaMes(MesNomina m, String tienda) async {
    final doc = pw.Document(title: 'Nómina ${meses[m.mes]} ${m.anio}');
    final tot = m.totales;
    int t(String k) => tot[k] ?? 0;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        _banda('NÓMINA DEL MES · ${meses[m.mes].toUpperCase()} ${m.anio}'),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(color: _salmonClaro,
              border: pw.Border.all(color: _texto2, width: .6)),
          child: pw.Row(children: [
            pw.Text('TIENDA  ', style: _t(8)), pw.Text(tienda, style: _t(8.5, b: true)),
            pw.SizedBox(width: 26),
            pw.Text('MÍNIMO  ', style: _t(8)), pw.Text(_n(m.valores.salarioMinimo), style: _t(8.5, b: true)),
            pw.SizedBox(width: 26),
            pw.Text('AUXILIO  ', style: _t(8)), pw.Text(_n(m.valores.auxilioTransporte), style: _t(8.5, b: true)),
          ]),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _texto2, width: .5),
          columnWidths: {0: const pw.FlexColumnWidth(2.4)},
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _salmon), children: [
              for (final c in ['NOMBRES', 'TIPO', 'DÍAS', '1.ª QUINC.', '2.ª QUINC.', 'SUELDO',
                               'AUX. TRANSP.', 'DEVENGADO', 'SALUD', 'PENSIÓN', 'OTROS DESC.',
                               'PAGADO', 'APORTES EMPRESA', 'PRESTACIONES', 'COSTO TOTAL'])
                _celda(c, b: true, size: 6.5, a: pw.TextAlign.center),
            ]),
            for (final p in m.personas)
              pw.TableRow(children: [
                _celda(p.nombres, size: 7.5),
                _celda(p.tipo == 'nomina' ? 'Nómina' : 'Temporal', size: 7.5),
                for (final v in [diasTexto(p.dias), p.q1 == null ? '-' : _n(p.q1!),
                                 p.q2 == null ? '-' : _n(p.q2!), _n(p.sueldo), _n(p.auxilio),
                                 _n(p.devengado), _n(p.salud), _n(p.pension),
                                 _n(p.danos + p.adelantos), _n(p.pagar), _n(p.aportes),
                                 _n(p.provisiones), _n(p.costo)])
                  _celda(v, size: 7.5, a: pw.TextAlign.right),
              ]),
            pw.TableRow(decoration: const pw.BoxDecoration(color: _salmonClaro), children: [
              _celda('TOTAL', b: true, size: 7.5), _celda('', size: 7.5), _celda('', size: 7.5),
              _celda('', size: 7.5), _celda('', size: 7.5),
              for (final v in [t('sueldo'), t('auxilio'), t('devengado'), t('salud'), t('pension'),
                               t('danos') + t('adelantos'), t('pagar'), t('aportes'),
                               t('provisiones'), t('costo')])
                _celda(_n(v), b: true, size: 7.5, a: pw.TextAlign.right),
            ]),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Resumen', style: _t(10, b: true)),
            pw.SizedBox(height: 4),
            for (final (k, v) in [
              ('Pagado a las personas', t('pagar')),
              ('Salud y pensión retenidas (se pagan en la PILA)', t('salud') + t('pension')),
              ('Aportes del empleador (pensión, ARL, caja)', t('aportes')),
              ('Provisión de prestaciones (prima, cesantías, intereses, vacaciones)', t('provisiones')),
              ('COSTO TOTAL DE NÓMINA', t('costo')),
            ])
              pw.Row(children: [
                pw.Expanded(child: pw.Text(k, style: _t(8.5))),
                pw.Text(_p(v), style: _t(8.5, b: true)),
              ]),
          ])),
          pw.SizedBox(width: 30),
          pw.Expanded(child: pw.Text(
              'Aportes: pensión 12 %, ARL ${m.valores.arlPct.toString().replaceAll('.', ',')} %, '
              'caja de compensación 4 %${m.valores.exonerado ? '; salud del empleador, ICBF y SENA exonerados (menos de 10 mínimos)' : ''}. '
              'Prestaciones: prima y cesantías 8,33 % (con auxilio), intereses 1 %, vacaciones 4,17 % (sin auxilio). '
              'Los temporales no tienen aportes ni prestaciones en este cálculo. $_nota',
              style: _t(7.5, c: _texto2))),
        ]),
      ],
    ));
    return doc.save();
  }

  // ── Liquidación de salida ───────────────────────────────────

  static Future<Uint8List> liquidacion(Trabajador t, Liquidacion lq, String tienda,
      {List<(String, Uint8List)> anexos = const []}) async {
    final doc = pw.Document(title: 'Liquidación ${t.nombres}');
    final d = lq;
    String dias(String k) => diasTexto(d.n(k));
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _encabezado(tienda, 'LIQUIDACIÓN FINAL DE CONTRATO DE TRABAJO', [
          ('Nombre:', t.nombres.toUpperCase()),
          ('Identificación:', t.cedula.isEmpty ? '-' : _cedula(t.cedula)),
          ('Cargo:', t.cargo.isEmpty ? '-' : t.cargo),
          ('Tipo de contrato:', contratos[d.d['tipo_contrato']] ?? '-'),
          ('Fecha de ingreso:', fechaCorta(d.f('fecha_ingreso'))),
          ('Fecha de retiro:', fechaCorta(d.f('fecha_retiro'))),
          ('Motivo:', d.motivoTexto),
          ('Tiempo laborado:', '${d.v('dias_total')} días'),
          ('Sueldo básico:', _n(d.v('mensual'))),
          ('Base prestaciones:', '${_n(d.v('base_prestaciones'))} (sueldo + auxilio)'),
          if (d.comprobante != null) ('Comprobante número:', '${d.comprobante}'),
        ]),
        pw.SizedBox(height: 14),
        _bloque('INGRESOS', ['Concepto', 'Días', 'Valor'], [
          if (d.v('sueldo') > 0) ['Sueldo pendiente', dias('dias_pendientes'), _n(d.v('sueldo'))],
          if (d.v('auxilio') > 0) ['Auxilio de transporte', dias('dias_pendientes'), _n(d.v('auxilio'))],
          ['Cesantías (desde ${fechaCorta(d.f('cesantias_desde'))})', '${d.v('dias_cesantias')}', _n(d.v('cesantias'))],
          ['Intereses sobre cesantías (12 % anual)', '${d.v('dias_cesantias')}', _n(d.v('intereses'))],
          ['Prima de servicios (desde ${fechaCorta(d.f('prima_desde'))})', '${d.v('dias_prima')}', _n(d.v('prima'))],
          ['Vacaciones compensadas (${dias('vacaciones_dias')} días hábiles)', '${d.v('dias_total')}', _n(d.v('vacaciones'))],
          if (d.v('indemnizacion') > 0)
            ['Indemnización por despido sin justa causa (${dias('indemnizacion_dias')} días)', '', _n(d.v('indemnizacion'))],
        ], ['Total ingresos', '', _n(d.v('ingresos'))]),
        pw.SizedBox(height: 10),
        _bloque('DEDUCCIONES', ['Concepto', '%', 'Valor'], [
          ['Fondo de salud (sobre el sueldo pendiente)', '4 %', _n(d.v('salud'))],
          ['Fondo de pensión', '4 %', _n(d.v('pension'))],
          if (d.v('otros_descuentos') > 0) ['Otros descuentos (autorizados por escrito)', '', _n(d.v('otros_descuentos'))],
        ], ['Total deducciones', '', _n(d.v('deducido'))]),
        pw.SizedBox(height: 10),
        _barra('NETO A PAGAR', _n(d.neto)),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Row(children: [
            pw.Text(d.pagado >= d.pagar ? 'PAGADO' : 'A PAGAR', style: _t(10, b: true)),
            pw.Spacer(),
            pw.Text(_n(d.pagar), style: _t(10, b: true)),
          ]),
        ),
        if (d.pagos.isNotEmpty) ...[
          pw.Text('Medio de pago:', style: _t(9, c: _texto2)),
          for (final p in d.pagos)
            pw.Text('${fechaCorta(p.fecha)} · ${p.medio} · ${_p(p.valor)}', style: _t(9.5, b: true)),
        ],
        if (d.anexos.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('ANEXOS (al final de este documento)', style: _t(9, b: true)),
          for (final (i, a) in d.anexos.indexed)
            pw.Text('${i + 1}. ${a.tipoTexto}${a.detalle.isEmpty ? '' : ' - ${a.detalle}'} · ${fechaCorta(a.fecha)}',
                style: _t(9)),
        ],
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: .6)),
          child: pw.Text('Con el pago de esta liquidación declaro recibidos los salarios y prestaciones '
              'sociales causados hasta la fecha de retiro, según el detalle anterior.', style: _t(8.5)),
        ),
        pw.Spacer(),
        _firmas(t.nombres, t.cedula, d.empleador),
        pw.SizedBox(height: 14),
        pw.Center(child: pw.Text('Cálculo según el Código Sustantivo del Trabajo con año de 360 días. '
            'Revisar con el contador antes de pagar.', style: _t(7.5, c: _texto2))),
      ]),
    ));
    await _pegarAnexos(doc, anexos);
    return doc.save();
  }

  /// Fotos como páginas; los PDF se convierten en imágenes página por página.
  static Future<void> _pegarAnexos(pw.Document doc, List<(String, Uint8List)> anexos) async {
    for (final (nombre, bytes) in anexos) {
      final paginas = <pw.ImageProvider>[];
      if (tipoDeArchivo(nombre) == 'application/pdf') {
        try {
          await for (final p in Printing.raster(bytes, dpi: 110)) {
            paginas.add(pw.MemoryImage(await p.toPng()));
          }
        } catch (_) {}
      } else {
        paginas.add(pw.MemoryImage(bytes));
      }
      for (final img in paginas) {
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(children: [
            pw.Text('Anexo: $nombre', style: _t(8, c: _texto2)),
            pw.SizedBox(height: 6),
            pw.Expanded(child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))),
          ]),
        ));
      }
    }
  }

  // ── Memorando ───────────────────────────────────────────────

  static Future<Uint8List> memorando(Trabajador t, DocumentoTrabajador m,
      {required String tienda, String ciudad = '', String empleador = ''}) async {
    final doc = pw.Document(title: 'Memorando ${m.numero}');
    final f = m.fecha;
    final fecha = '${f.day} de ${meses[f.month]} de ${f.year}';
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _verde, width: 2))),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(tienda.toUpperCase(), style: _t(14, b: true)),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(ciudad.isEmpty ? fecha : '$ciudad, $fecha', style: _t(9.5, c: _texto2)),
              pw.Text('Memorando N.º ${m.numero}', style: _t(9.5, b: true)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 18),
        pw.RichText(text: pw.TextSpan(style: _t(10.5), children: [
          pw.TextSpan(text: 'Para: ', style: _t(10.5, b: true)),
          pw.TextSpan(text: '${t.nombres}${t.cedula.isEmpty ? '' : ' · C.C. ${_cedula(t.cedula)}'}'
              '${t.cargo.isEmpty ? '' : ' · ${t.cargo}'}\n'),
          pw.TextSpan(text: 'De: ', style: _t(10.5, b: true)),
          pw.TextSpan(text: '${empleador.isEmpty ? 'Administración' : empleador} · Administración\n'),
          pw.TextSpan(text: 'Asunto: ', style: _t(10.5, b: true)),
          pw.TextSpan(text: 'Llamado de atención${m.motivo.isEmpty ? '' : ' por ${m.motivo.toLowerCase()}'}'),
        ])),
        pw.SizedBox(height: 16),
        pw.Text('Por medio del presente se le hace un llamado de atención por los siguientes hechos:',
            style: _t(10.5)),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: .6)),
          child: pw.Text(m.hechos, style: _t(10.5)),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Le recordamos que cumplir con el horario y las funciones de su cargo es una de sus '
            'obligaciones como trabajador(a). Si lo desea, puede presentar sus explicaciones por '
            'escrito dentro de los tres (3) días hábiles siguientes.', style: _t(10.5)),
        pw.SizedBox(height: 10),
        pw.Text('Una copia de este documento se guarda en su hoja de vida.', style: _t(10.5)),
        pw.SizedBox(height: 70),
        _firmas(t.nombres, t.cedula, empleador, rotuloTrabajador: 'Recibí · Firma del trabajador'),
        pw.SizedBox(height: 6),
        pw.Text('Fecha de recibido: ____ / ____ / ________', style: _t(9)),
        pw.SizedBox(height: 50),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: _lineaFirma('Testigo 1 (solo si se niega a firmar)', '', 'Nombre y C.C.')),
          pw.SizedBox(width: 40),
          pw.Expanded(child: _lineaFirma('Testigo 2', '', 'Nombre y C.C.')),
        ]),
      ]),
    ));
    return doc.save();
  }

  // ── Mostrar ─────────────────────────────────────────────────

  /// Abre el PDF: en el computador con el visor de PDF; en el celular con
  /// la vista para imprimir o compartir.
  static Future<void> abrir(Uint8List bytes, String nombre) async {
    final archivo = nombre.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: archivo);
      return;
    }
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}$archivo');
      await f.writeAsBytes(bytes);
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', f.path]);
      } else {
        await Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [f.path]);
      }
      return;
    }
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: archivo);
  }
}
