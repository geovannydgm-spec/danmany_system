import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:developer' as developer;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic>? permisos;
  const ReportsScreen({super.key, this.permisos});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class KardexGrupo {
  final String grado;
  final String grupo;
  final String turno;
  final String escuela;
  final String ciclo;
  final List<String> alumnos;
  final List<DateTime> diasHabiles;
  final Map<String, Set<String>> asistenciasPorDia;
  final Set<String> diasConClase;

  KardexGrupo({
    required this.grado,
    required this.grupo,
    required this.turno,
    required this.escuela,
    required this.ciclo,
    required this.alumnos,
    required this.diasHabiles,
    required this.asistenciasPorDia,
    required this.diasConClase,
  });
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedEscuela;
  String? _selectedGrado;
  String? _selectedGrupo;
  String? _selectedTurno;
  String? _selectedCiclo;

  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = false;
  List<KardexGrupo> _kardexList = [];
  String _statusMessage = 'Ajusta los filtros y genera un reporte.';

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List<String> escuelas = [];
  List<String> grados = [];
  List<String> grupos = [];
  List<String> turnos = [];
  List<String> ciclos = [];

  bool get _esAdmin => widget.permisos == null;
  bool get _puedeExcel => _esAdmin || (widget.permisos?['puede_excel'] == true);
  bool get _puedePdf => _esAdmin || (widget.permisos?['puede_pdf'] == true);

  List<String> get _escuelasPermitidas =>
      _esAdmin ? [] : List<String>.from(widget.permisos?['escuelas'] ?? []);
  List<String> get _gradosPermitidos =>
      _esAdmin ? [] : List<String>.from(widget.permisos?['grados'] ?? []);
  List<String> get _gruposPermitidos =>
      _esAdmin ? [] : List<String>.from(widget.permisos?['grupos'] ?? []);
  List<String> get _turnosPermitidos =>
      _esAdmin ? [] : List<String>.from(widget.permisos?['turnos'] ?? []);
  List<String> get _ciclosPermitidos =>
      _esAdmin ? [] : List<String>.from(widget.permisos?['ciclos'] ?? []);

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // Convierte índice de columna (0-based) a letra Excel (A, B, ... Z, AA, AB...)
  String _columnLetter(int index) {
    String result = '';
    int n = index + 1;
    while (n > 0) {
      n--;
      result = String.fromCharCode(65 + (n % 26)) + result;
      n = n ~/ 26;
    }
    return result;
  }

  // Genera el nombre del archivo con escuela_grado_grupo_fechas
  String _generarNombreArchivo(String extension) {
    // Usar el primer kardex para el nombre (escuela, grado, grupo)
    final k = _kardexList.first;
    final escuela = k.escuela.replaceAll(' ', '_').toUpperCase();
    final inicio = DateFormat('dd-MM-yy').format(_startDate!);
    final fin = DateFormat('dd-MM-yy').format(_endDate!);

    if (_kardexList.length == 1) {
      // Un solo grupo: incluir grado y grupo
      final grado = k.grado;
      final grupo = k.grupo;
      return '${escuela}_${grado}_${grupo}_${inicio}_al_$fin.$extension';
    } else {
      // Varios grupos: solo escuela y fechas
      return '${escuela}_${inicio}_al_$fin.$extension';
    }
  }

  // Descarga directa en el navegador
  void _downloadWeb(List<int> bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _loadFilterOptions() async {
    try {
      if (!_esAdmin) {
        if (mounted) {
          setState(() {
            escuelas = List<String>.from(_escuelasPermitidas)..sort();
            grados = List<String>.from(_gradosPermitidos)..sort();
            grupos = List<String>.from(_gruposPermitidos)..sort();
            turnos = List<String>.from(_turnosPermitidos)..sort();
            ciclos = List<String>.from(_ciclosPermitidos)..sort();
            if (escuelas.length == 1) _selectedEscuela = escuelas.first;
            if (grados.length == 1) _selectedGrado = grados.first;
            if (grupos.length == 1) _selectedGrupo = grupos.first;
            if (turnos.length == 1) _selectedTurno = turnos.first;
            if (ciclos.length == 1) _selectedCiclo = ciclos.first;
          });
        }
      } else {
        final snapshot = await _firestore.collection('students').get();
        final Set<String> sEsc = {}, sGr = {}, sGrup = {}, sTurn = {}, sCiclo = {};
        for (var doc in snapshot.docs) {
          final d = doc.data();
          if ((d['escuela'] as String?)?.isNotEmpty ?? false) sEsc.add(d['escuela']);
          if ((d['grado'] as String?)?.isNotEmpty ?? false) sGr.add(d['grado']);
          if ((d['grupo'] as String?)?.isNotEmpty ?? false) sGrup.add(d['grupo']);
          if ((d['turno'] as String?)?.isNotEmpty ?? false) sTurn.add(d['turno']);
          if ((d['ciclo'] as String?)?.isNotEmpty ?? false) sCiclo.add(d['ciclo']);
        }
        if (mounted) {
          setState(() {
            escuelas = sEsc.toList()..sort();
            grados = sGr.toList()..sort();
            grupos = sGrup.toList()..sort();
            turnos = sTurn.toList()..sort();
            ciclos = sCiclo.toList()..sort();
          });
        }
      }
    } catch (e) {
      developer.log('Error cargando opciones: $e');
    }
  }

  Future<void> _pickStartDate() async {
    final res = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'ES'),
    );
    if (res != null && mounted) {
      setState(() {
        _startDate = res;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(res);
      });
    }
  }

  Future<void> _pickEndDate() async {
    final res = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'ES'),
    );
    if (res != null && mounted) {
      setState(() {
        _endDate = res;
        _endDateController.text = DateFormat('yyyy-MM-dd').format(res);
      });
    }
  }

  List<DateTime> _generarDiasHabiles(DateTime fechaInicio, DateTime fechaFin) {
    final mes = fechaFin.month;
    final anio = fechaFin.year;
    final primerDia = DateTime(anio, mes, 1);
    final ultimoDia = DateTime(anio, mes + 1, 0);
    final inicio = fechaInicio.isBefore(primerDia) ? primerDia : fechaInicio;
    final fin = fechaFin.isAfter(ultimoDia) ? ultimoDia : fechaFin;
    final List<DateTime> dias = [];
    DateTime current = inicio;
    while (!current.isAfter(fin)) {
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
        dias.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dias;
  }

  String _nombreMes(int mes) {
    const meses = ['', 'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
        'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    return meses[mes];
  }

  Future<void> _generateReport() async {
    if (!mounted) return;
    if (_startDate == null || _endDate == null) {
      _showSnackBar('Por favor selecciona la fecha inicial y final.');
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      _showSnackBar('La fecha de inicio no puede ser posterior a la fecha de fin.');
      return;
    }

    setState(() { _loading = true; _kardexList = []; _statusMessage = 'Generando reporte...'; });
    _showLoadingDialog();

    try {
      Query studentsQuery = _firestore.collection('students');
      final escuelaFiltro = _selectedEscuela ?? (_escuelasPermitidas.length == 1 ? _escuelasPermitidas.first : null);
      final gradoFiltro = _selectedGrado ?? (_gradosPermitidos.length == 1 ? _gradosPermitidos.first : null);
      final grupoFiltro = _selectedGrupo ?? (_gruposPermitidos.length == 1 ? _gruposPermitidos.first : null);
      final turnoFiltro = _selectedTurno ?? (_turnosPermitidos.length == 1 ? _turnosPermitidos.first : null);
      final cicloFiltro = _selectedCiclo ?? (_ciclosPermitidos.length == 1 ? _ciclosPermitidos.first : null);

      if (escuelaFiltro?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('escuela', isEqualTo: escuelaFiltro);
      if (gradoFiltro?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('grado', isEqualTo: gradoFiltro);
      if (grupoFiltro?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('grupo', isEqualTo: grupoFiltro);
      if (turnoFiltro?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('turno', isEqualTo: turnoFiltro);
      if (cicloFiltro?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('ciclo', isEqualTo: cicloFiltro);

      final studentsSnap = await studentsQuery.get();
      if (studentsSnap.docs.isEmpty) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          setState(() { _loading = false; _statusMessage = 'No se encontraron estudiantes.'; });
        }
        return;
      }

      final Map<String, List<Map<String, dynamic>>> gruposMap = {};
      for (var doc in studentsSnap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final key = '${d['grado']}|${d['grupo']}|${d['turno']}|${d['escuela']}|${d['ciclo']}';
        gruposMap.putIfAbsent(key, () => []);
        gruposMap[key]!.add({...d, '_id': doc.id});
      }

      final diasHabiles = _generarDiasHabiles(_startDate!, _endDate!);
      final startTs = Timestamp.fromDate(DateTime(_startDate!.year, _startDate!.month, _startDate!.day));
      final endTs = Timestamp.fromDate(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59));
      final List<KardexGrupo> kardexList = [];

      for (var entry in gruposMap.entries) {
        final parts = entry.key.split('|');
        final alumnosDelGrupo = entry.value;
        alumnosDelGrupo.sort((a, b) {
          final aN = '${a['apellido_paterno']} ${a['apellido_materno']} ${a['nombres']}';
          final bN = '${b['apellido_paterno']} ${b['apellido_materno']} ${b['nombres']}';
          return aN.compareTo(bN);
        });
        final nombresAlumnos = alumnosDelGrupo.map((a) =>
          '${a['apellido_paterno']} ${a['apellido_materno']} ${a['nombres']}'.trim()).toList();

        final Map<String, Set<String>> asistenciasPorDia = {
          for (var dia in diasHabiles) DateFormat('yyyy-MM-dd').format(dia): <String>{}
        };

        for (var alumno in alumnosDelGrupo) {
          final String alumnoId = alumno['_id'];
          final String nombre = '${alumno['apellido_paterno']} ${alumno['apellido_materno']} ${alumno['nombres']}'.trim();
          final attSnap = await _firestore
              .collection('asistencia').doc(alumnoId).collection('registros')
              .where('timestamp', isGreaterThanOrEqualTo: startTs)
              .where('timestamp', isLessThanOrEqualTo: endTs)
              .get();
          for (var rec in attSnap.docs) {
            final ts = rec.data()['timestamp'] as Timestamp?;
            if (ts != null) {
              final fecha = DateFormat('yyyy-MM-dd').format(ts.toDate());
              asistenciasPorDia[fecha]?.add(nombre);
            }
          }
        }

        final Set<String> diasConClase = {
          for (var e in asistenciasPorDia.entries) if (e.value.isNotEmpty) e.key
        };

        kardexList.add(KardexGrupo(
          grado: parts[0], grupo: parts[1], turno: parts[2],
          escuela: parts[3], ciclo: parts[4],
          alumnos: nombresAlumnos,
          diasHabiles: diasHabiles,
          asistenciasPorDia: asistenciasPorDia,
          diasConClase: diasConClase,
        ));
      }

      kardexList.sort((a, b) {
        final c = a.grado.compareTo(b.grado);
        return c != 0 ? c : a.grupo.compareTo(b.grupo);
      });

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _kardexList = kardexList;
          _loading = false;
          _statusMessage = kardexList.isEmpty ? 'Sin registros.' : '${kardexList.length} grupo(s) generados.';
        });
      }
    } catch (e, st) {
      developer.log('Error: $e\n$st');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() { _loading = false; _statusMessage = 'Error: $e'; });
        _showSnackBar('Error: $e');
      }
    }
  }

  bool _asistio(KardexGrupo k, String alumno, String dia) =>
      k.asistenciasPorDia[dia]?.contains(alumno) ?? false;

  bool _esFalta(KardexGrupo k, String alumno, String dia) =>
      k.diasConClase.contains(dia) && !_asistio(k, alumno, dia);

  Future<void> _exportExcel() async {
    if (_kardexList.isEmpty) { _showSnackBar('No hay datos.'); return; }
    setState(() => _loading = true);
    _showLoadingDialog();
    try {
      var excelFile = Excel.createExcel();

      // Crear primero todas las hojas reales
      for (var k in _kardexList) {
        final sheetName = '${k.grado}${k.grupo}-${k.turno.substring(0, 3)}';
        excelFile[sheetName]; // solo crea la hoja
      }
      // Ahora sí eliminar Sheet1 porque ya hay otras hojas
      if (excelFile.sheets.containsKey('Sheet1')) {
        excelFile.delete('Sheet1');
      }

      for (var k in _kardexList) {
        final sheetName = '${k.grado}${k.grupo}-${k.turno.substring(0, 3)}';
        final Sheet sheet = excelFile[sheetName];
        final mesNombre = _nombreMes(_endDate!.month);
        final anio = _endDate!.year;

        final headerStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#4527A0'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true, horizontalAlign: HorizontalAlign.Center,
        );
        final subHeaderStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#EDE7F6'),
          bold: true, horizontalAlign: HorizontalAlign.Center,
        );
        final greenStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#A5D6A7'),
          horizontalAlign: HorizontalAlign.Center, bold: true,
        );
        final redStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#EF9A9A'),
          horizontalAlign: HorizontalAlign.Center, bold: true,
        );

        // Total de columnas: # + Nombre + días + A + F
        final totalCols = 2 + k.diasHabiles.length + 2;
        // Escribir título en A1
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
            TextCellValue('$mesNombre $anio - ${k.escuela} | ${k.grado}° ${k.grupo} | ${k.turno} | ${k.ciclo}');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = headerStyle;
        // Aplicar color a todas las celdas del título para que se vea el fondo
        for (int c = 1; c < totalCols; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = headerStyle;
        }
        // Combinar celdas de la fila 1 (merge)
        final lastColLetter = _columnLetter(totalCols - 1);
        sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('${lastColLetter}1'));

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('#');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subHeaderStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('NOMBRE Y APELLIDOS');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).cellStyle = subHeaderStyle;
        sheet.setColumnWidth(1, 35);

        int col = 2;
        for (var dia in k.diasHabiles) {
          final c = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1));
          c.value = IntCellValue(dia.day);
          c.cellStyle = subHeaderStyle;
          sheet.setColumnWidth(col, 4);
          col++;
        }
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1)).value = TextCellValue('A');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1)).cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#C8E6C9'), bold: true, horizontalAlign: HorizontalAlign.Center);
        col++;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1)).value = TextCellValue('F');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1)).cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#FFCDD2'), bold: true, horizontalAlign: HorizontalAlign.Center);

        int row = 2;
        for (var i = 0; i < k.alumnos.length; i++) {
          final alumno = k.alumnos[i];
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(i + 1);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(alumno);
          int asistencias = 0, faltas = 0, diaCol = 2;
          for (var dia in k.diasHabiles) {
            final diaStr = DateFormat('yyyy-MM-dd').format(dia);
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: diaCol, rowIndex: row));
            if (_asistio(k, alumno, diaStr)) {
              cell.value = TextCellValue('A'); cell.cellStyle = greenStyle; asistencias++;
            } else if (_esFalta(k, alumno, diaStr)) {
              cell.value = TextCellValue('F'); cell.cellStyle = redStyle; faltas++;
            }
            diaCol++;
          }
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: diaCol, rowIndex: row)).value = IntCellValue(asistencias);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: diaCol, rowIndex: row)).cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#C8E6C9'), bold: true, horizontalAlign: HorizontalAlign.Center);
          diaCol++;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: diaCol, rowIndex: row)).value = IntCellValue(faltas);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: diaCol, rowIndex: row)).cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFCDD2'), bold: true, horizontalAlign: HorizontalAlign.Center);
          row++;
        }
      }

      final bytes = excelFile.encode()!;
      _downloadWeb(bytes, _generarNombreArchivo('xlsx'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('Descarga de Excel iniciada.');
      }
    } catch (e) {
      developer.log('Error Excel: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('Error exportando Excel: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_kardexList.isEmpty) { _showSnackBar('No hay datos.'); return; }
    setState(() => _loading = true);
    _showLoadingDialog();
    try {
      final pdf = pw.Document();

      for (var k in _kardexList) {
        final mesNombre = _nombreMes(_endDate!.month);
        final anio = _endDate!.year;
        final totalDias = k.diasHabiles.length;

        // Calcular anchos de columna proporcionales al ancho de la página
        // Página A4 landscape = 841pt - 32pt márgenes = 809pt disponibles
        const double pageWidth = 809;
        const double colNum = 18;
        const double colNombre = 140;
        const double colAF = 20;
        final double colDia = (pageWidth - colNum - colNombre - colAF * 2) / (totalDias > 0 ? totalDias : 1);

        final Map<int, pw.TableColumnWidth> columnWidths = {
          0: const pw.FixedColumnWidth(colNum),
          1: const pw.FixedColumnWidth(colNombre),
          ...{ for (var i = 0; i < totalDias; i++) i + 2: pw.FixedColumnWidth(colDia) },
          totalDias + 2: const pw.FixedColumnWidth(colAF),
          totalDias + 3: const pw.FixedColumnWidth(colAF),
        };

        // Construir filas manualmente para control total de colores
        pw.Widget buildHeaderRow() {
          final cells = <pw.Widget>[
            _pdfCell('#', isHeader: true, align: pw.Alignment.center),
            _pdfCell('NOMBRE Y APELLIDOS', isHeader: true, align: pw.Alignment.centerLeft),
            ...k.diasHabiles.map((d) => _pdfCell('${d.day}', isHeader: true, align: pw.Alignment.center)),
            _pdfCell('A', isHeader: true, align: pw.Alignment.center, bg: PdfColor(0.784, 0.902, 0.788)),
            _pdfCell('F', isHeader: true, align: pw.Alignment.center, bg: PdfColor(1.0, 0.804, 0.824)),
          ];
          return pw.Row(children: cells.asMap().entries.map((e) {
            final width = columnWidths[e.key]!;
            return pw.SizedBox(width: (width as pw.FixedColumnWidth).width, child: e.value);
          }).toList());
        }

        pw.Widget buildAlumnoRow(int idx, String alumno, bool isEven) {
          int a = 0, f = 0;
          final dayCells = k.diasHabiles.map((dia) {
            final diaStr = DateFormat('yyyy-MM-dd').format(dia);
            final asistio = _asistio(k, alumno, diaStr);
            final falta = _esFalta(k, alumno, diaStr);
            if (asistio) a++;
            if (falta) f++;
            PdfColor? bg;
            String txt = '';
            if (asistio) { bg = const PdfColor(0.647, 0.839, 0.655); txt = 'A'; }
            else if (falta) { bg = const PdfColor(0.937, 0.604, 0.604); txt = 'F'; }
            else { bg = isEven ? PdfColors.grey100 : PdfColors.white; }
            return _pdfCell(txt, align: pw.Alignment.center, bg: bg);
          }).toList();

          final rowBg = isEven ? PdfColors.grey100 : PdfColors.white;
          final allCells = <pw.Widget>[
            _pdfCell('${idx + 1}', align: pw.Alignment.center, bg: rowBg),
            _pdfCell(alumno, align: pw.Alignment.centerLeft, bg: rowBg, fontSize: 6),
            ...dayCells,
            _pdfCell('$a', align: pw.Alignment.center, bg: const PdfColor(0.784, 0.902, 0.788),
                textColor: PdfColors.green900),
            _pdfCell('$f', align: pw.Alignment.center, bg: const PdfColor(1.0, 0.804, 0.824),
                textColor: PdfColors.red900),
          ];

          return pw.Row(children: allCells.asMap().entries.map((e) {
            final width = columnWidths[e.key]!;
            return pw.SizedBox(width: (width as pw.FixedColumnWidth).width, child: e.value);
          }).toList());
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(16),
            build: (context) {
              return [
                // Encabezado título
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: const pw.BoxDecoration(color: PdfColors.deepPurple700),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('$mesNombre $anio',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${k.escuela} | ${k.grado}° ${k.grupo} | ${k.turno} | ${k.ciclo}',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                // Tabla
                pw.Column(
                  children: [
                    buildHeaderRow(),
                    ...k.alumnos.asMap().entries.map((e) =>
                        buildAlumnoRow(e.key, e.value, e.key.isEven)),
                  ],
                ),
              ];
            },
          ),
        );
      }

      final bytes = await pdf.save();
      _downloadWeb(bytes, _generarNombreArchivo('pdf'), 'application/pdf');

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('Descarga de PDF iniciada.');
      }
    } catch (e, st) {
      developer.log('Error PDF: $e\n$st');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('Error exportando PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Widget auxiliar para celdas del PDF
  pw.Widget _pdfCell(
    String text, {
    pw.Alignment align = pw.Alignment.center,
    PdfColor? bg,
    bool isHeader = false,
    double fontSize = 7,
    PdfColor? textColor,
  }) {
    return pw.Container(
      height: 16,
      color: bg ?? (isHeader ? PdfColors.deepPurple : PdfColors.white),
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (textColor ?? PdfColors.black),
        ),
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text('Generando...')]),
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildDropdown(String label, List<String> opciones, String? valor, void Function(String?) onChanged) {
    if (!_esAdmin && opciones.length == 1) {
      return SizedBox(width: 200, child: InputDecorator(
        decoration: InputDecoration(labelText: label, filled: true, border: const OutlineInputBorder()),
        child: Text(opciones.first, style: const TextStyle(fontSize: 14)),
      ));
    }
    return SizedBox(width: 200, child: DropdownButtonFormField<String>(
      value: valor,
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todos')),
        ...opciones.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, filled: true, border: const OutlineInputBorder()),
    ));
  }

  Widget _buildKardexWidget(KardexGrupo k) {
    final mesNombre = _nombreMes(_endDate!.month);
    final anio = _endDate!.year;
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$mesNombre $anio',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${k.escuela} | ${k.grado}° ${k.grupo} | ${k.turno}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.deepPurple.shade50),
              columnSpacing: 8,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 40,
              columns: [
                const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('NOMBRE Y APELLIDOS', style: TextStyle(fontWeight: FontWeight.bold))),
                ...k.diasHabiles.map((dia) => DataColumn(
                  label: Text('${dia.day}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                const DataColumn(label: Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                const DataColumn(label: Text('F', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
              ],
              rows: k.alumnos.asMap().entries.map((entry) {
                final alumno = entry.value;
                int asistencias = 0, faltas = 0;
                final celdas = k.diasHabiles.map((dia) {
                  final diaStr = DateFormat('yyyy-MM-dd').format(dia);
                  final asistio = _asistio(k, alumno, diaStr);
                  final esFalta = _esFalta(k, alumno, diaStr);
                  if (asistio) asistencias++;
                  if (esFalta) faltas++;
                  return DataCell(Container(
                    width: 28, height: 32,
                    color: asistio ? Colors.green.shade200 : esFalta ? Colors.red.shade200 : null,
                    alignment: Alignment.center,
                    child: Text(
                      asistio ? 'A' : esFalta ? 'F' : '',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: asistio ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ));
                }).toList();
                return DataRow(cells: [
                  DataCell(Text('${entry.key + 1}', style: const TextStyle(fontSize: 12))),
                  DataCell(SizedBox(width: 220,
                    child: Text(alumno, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                  ...celdas,
                  DataCell(Text('$asistencias', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text('$faltas', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Asistencia'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFFE9E9E9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_esAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user, color: Colors.deepPurple, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(
                    'Acceso limitado a: ${_escuelasPermitidas.isNotEmpty ? _escuelasPermitidas.join(", ") : "todas las escuelas"}',
                    style: const TextStyle(fontSize: 13, color: Colors.deepPurple),
                  )),
                ]),
              ),
            Wrap(spacing: 12, runSpacing: 8, children: [
              _buildDropdown('Escuela', escuelas, _selectedEscuela, (v) => setState(() => _selectedEscuela = v)),
              _buildDropdown('Grado', grados, _selectedGrado, (v) => setState(() => _selectedGrado = v)),
              _buildDropdown('Grupo', grupos, _selectedGrupo, (v) => setState(() => _selectedGrupo = v)),
              _buildDropdown('Turno', turnos, _selectedTurno, (v) => setState(() => _selectedTurno = v)),
              _buildDropdown('Ciclo escolar', ciclos, _selectedCiclo, (v) => setState(() => _selectedCiclo = v)),
              SizedBox(width: 160, child: TextFormField(
                controller: _startDateController, readOnly: true, onTap: _pickStartDate,
                decoration: const InputDecoration(labelText: 'Fecha inicial', filled: true),
              )),
              SizedBox(width: 160, child: TextFormField(
                controller: _endDateController, readOnly: true, onTap: _pickEndDate,
                decoration: const InputDecoration(labelText: 'Fecha final', filled: true),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _generateReport,
                icon: const Icon(Icons.bar_chart),
                label: const Text('Generar Reporte'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              ),
              if (_puedeExcel) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _kardexList.isNotEmpty && !_loading ? _exportExcel : null,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Descargar Excel'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                ),
              ],
              if (_puedePdf) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _kardexList.isNotEmpty && !_loading ? _exportPdf : null,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Descargar PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                ),
              ],
            ]),
            const SizedBox(height: 18),
            Expanded(
              child: _kardexList.isEmpty
                  ? Center(child: Text(_statusMessage,
                      style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center))
                  : ListView.builder(
                      itemCount: _kardexList.length,
                      itemBuilder: (context, i) => _buildKardexWidget(_kardexList[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}