import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart' as sharing;
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;

// Importación condicional para web
import 'dart:html' as html if (dart.library.io) 'dart:io';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
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
  List<Map<String, dynamic>> _reportData = [];
  String _statusMessage = 'Ajusta los filtros y genera un reporte.';

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List<String> escuelas = [];
  List<String> grados = [];
  List<String> grupos = [];
  List<String> turnos = [];
  List<String> ciclos = [];

  @override
  void initState() {
    super.initState();
    developer.log('initState: Cargando opciones de filtro.');
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // Carga de filtros ahora consulta la colección 'students'
  Future<void> _loadFilterOptions() async {
    try {
      developer.log('loadFilterOptions: Consultando Firestore para los filtros.');
      final snapshot = await _firestore.collection('students').get();
      final Set<String> sEsc = {}, sGr = {}, sGrup = {}, sTurn = {}, sCiclo = {};

      for (var doc in snapshot.docs) {
        final d = doc.data();
        if (d != null) {
          if ((d['escuela'] as String?)?.isNotEmpty ?? false) sEsc.add(d['escuela']);
          if ((d['grado'] as String?)?.isNotEmpty ?? false) sGr.add(d['grado']);
          if ((d['grupo'] as String?)?.isNotEmpty ?? false) sGrup.add(d['grupo']);
          if ((d['turno'] as String?)?.isNotEmpty ?? false) sTurn.add(d['turno']);
          if ((d['ciclo'] as String?)?.isNotEmpty ?? false) sCiclo.add(d['ciclo']);
        }
      }
      if (mounted) {
        setState(() {
          escuelas = sEsc.toList()..sort();
          grados = sGr.toList()..sort();
          grupos = sGrup.toList()..sort();
          turnos = sTurn.toList()..sort();
          ciclos = sCiclo.toList()..sort();
        });
        developer.log('loadFilterOptions: Filtros cargados con éxito.');
      }
    } catch (e) {
      developer.log('loadFilterOptions: Error cargando opciones de filtro: $e');
      if (mounted) {
        showSnackBar('Error al cargar las opciones de filtro: $e');
      }
    }
  }

  Future<void> _pickStartDate() async {
    DateTime now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
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
    DateTime now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
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

  // Lógica de generación de reporte
  Future<void> _generateReport() async {
    if (!mounted) return;
    if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!)) {
      showSnackBar('La fecha de inicio no puede ser posterior a la fecha de fin.');
      return;
    }

    setState(() {
      _loading = true;
      _reportData = [];
      _statusMessage = 'Generando reporte...';
    });

    _showLoadingDialog();
    developer.log('generateReport: Iniciando la generación del reporte.');

    try {
      Query studentsQuery = _firestore.collection('students');
      if (_selectedEscuela?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('escuela', isEqualTo: _selectedEscuela);
      if (_selectedGrado?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('grado', isEqualTo: _selectedGrado);
      if (_selectedGrupo?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('grupo', isEqualTo: _selectedGrupo);
      if (_selectedTurno?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('turno', isEqualTo: _selectedTurno);
      if (_selectedCiclo?.isNotEmpty ?? false) studentsQuery = studentsQuery.where('ciclo', isEqualTo: _selectedCiclo);

      final studentsSnap = await studentsQuery.get();
      developer.log('generateReport: Consulta de estudiantes exitosa. Documentos encontrados: ${studentsSnap.docs.length}');

      if (studentsSnap.docs.isEmpty) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            _loading = false;
            _statusMessage = 'No se encontraron estudiantes con los filtros seleccionados.';
          });
          showSnackBar(_statusMessage);
        }
        return;
      }

      final List<Map<String, dynamic>> rows = [];
      final startDate = _startDate != null ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day, 0, 0, 0) : null;
      final endDate = _endDate != null ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59) : null;

      for (var studentDoc in studentsSnap.docs) {
        final studentData = studentDoc.data() as Map<String, dynamic>?;
        if (studentData == null) continue;

        final String nombreCompleto = "${studentData['nombres'] ?? ''} ${studentData['apellido_paterno'] ?? ''} ${studentData['apellido_materno'] ?? ''}".trim();

        Query attendanceQuery = _firestore.collection('asistencia')
            .doc(studentDoc.id)
            .collection('registros');

        if (startDate != null) {
          attendanceQuery = attendanceQuery.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          attendanceQuery = attendanceQuery.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }

        attendanceQuery = attendanceQuery.orderBy('timestamp', descending: true);

        final attendanceSnap = await attendanceQuery.get();
        developer.log('generateReport: Encontrados ${attendanceSnap.docs.length} registros para el estudiante ${studentDoc.id}');

        for (var recordDoc in attendanceSnap.docs) {
          final recordData = recordDoc.data() as Map<String, dynamic>?;
          if (recordData == null) continue;

          final Timestamp? timestamp = recordData['timestamp'] is Timestamp ? recordData['timestamp'] as Timestamp : null;
          final DateTime? date = timestamp?.toDate();

          rows.add({
            'nombre': nombreCompleto,
            'grado': studentData['grado'] ?? '',
            'grupo': studentData['grupo'] ?? '',
            'turno': studentData['turno'] ?? '',
            'escuela': studentData['escuela'] ?? '',
            'fecha': date != null ? DateFormat('yyyy-MM-dd').format(date) : '',
            'hora': date != null ? DateFormat('HH:mm:ss').format(date) : '',
            'timestamp': timestamp,
          });
        }
      }

      if (mounted) {
        setState(() {
          _reportData = rows;
          _statusMessage = _reportData.isEmpty
              ? 'No se encontraron registros de asistencia para los estudiantes filtrados.'
              : 'Reporte generado con éxito. (Mostrando un máximo de ${_reportData.length} registros)';
        });
        showSnackBar(_statusMessage);
      }
    } catch (e, st) {
      developer.log('generateReport: Error al generar reporte: $e\nStack: $st', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error al generar el reporte: $e';
        });
        showSnackBar('Error al generar el reporte: $e');
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _loading = false);
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Generando reporte..."),
            ],
          ),
        );
      },
    );
  }

  void showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Exportación a Excel - VERSIÓN UNIVERSAL (Web y Móvil)
  Future<String> _saveExcelFile(List<Map<String, dynamic>> data) async {
    developer.log('saveExcelFile: Iniciando exportación a Excel.');
    var excel = Excel.createExcel();
    final Sheet sheet = excel['Asistencia'];

    sheet.appendRow([
      TextCellValue('FECHA'),
      TextCellValue('HORA'),
      TextCellValue('NOMBRE COMPLETO'),
      TextCellValue('GRADO'),
      TextCellValue('GRUPO'),
      TextCellValue('TURNO'),
      TextCellValue('ESCUELA'),
    ]);

    for (var r in data) {
      final timestamp = r['timestamp'] as Timestamp?;
      String fechaStr = timestamp != null ? DateFormat('yyyy-MM-dd').format(timestamp.toDate()) : '';
      String horaStr = timestamp != null ? DateFormat('HH:mm:ss').format(timestamp.toDate()) : '';

      sheet.appendRow([
        TextCellValue(fechaStr),
        TextCellValue(horaStr),
        TextCellValue(r['nombre'] ?? ''),
        TextCellValue(r['grado'] ?? ''),
        TextCellValue(r['grupo'] ?? ''),
        TextCellValue(r['turno'] ?? ''),
        TextCellValue(r['escuela'] ?? ''),
      ]);
    }

    final bytes = excel.encode()!;

    if (kIsWeb) {
      // Para WEB
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'reporte_asistencia_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);
      return 'descargado';
    } else {
      // Para MÓVIL
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'reporte_asistencia_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      developer.log('saveExcelFile: Archivo Excel guardado en ${file.path}');
      return file.path;
    }
  }

  // Exportación a PDF - VERSIÓN UNIVERSAL (Web y Móvil)
  Future<String> _savePdfFile(List<Map<String, dynamic>> data) async {
    developer.log('savePdfFile: Iniciando exportación a PDF.');
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4.landscape;

    final headers = [
      'FECHA',
      'HORA',
      'NOMBRE',
      'GRADO',
      'GRUPO',
      'TURNO',
      'ESCUELA'
    ];

    final tableData = <List<String>>[];
    for (var r in data) {
      final timestamp = r['timestamp'] as Timestamp?;
      String fechaStr = timestamp != null ? DateFormat('yyyy-MM-dd').format(timestamp.toDate()) : '';
      String horaStr = timestamp != null ? DateFormat('HH:mm:ss').format(timestamp.toDate()) : '';

      tableData.add([
        fechaStr,
        horaStr,
        r['nombre'] ?? '',
        r['grado'] ?? '',
        r['grupo'] ?? '',
        r['turno'] ?? '',
        r['escuela'] ?? '',
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Reporte de Asistencia')),
          pw.Table.fromTextArray(
            headers: headers,
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      // Para WEB
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'reporte_asistencia_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);
      return 'descargado';
    } else {
      // Para MÓVIL
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'reporte_asistencia_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      developer.log('savePdfFile: Archivo PDF guardado en ${file.path}');
      return file.path;
    }
  }

  // Exportación a Excel - VERSIÓN UNIVERSAL
  Future<void> _exportExcel() async {
    if (_reportData.isEmpty) {
      if (mounted) {
        showSnackBar('No hay datos para exportar.');
      }
      return;
    }
    
    if (!mounted) return;
    
    setState(() => _loading = true);
    try {
      if (!kIsWeb) {
        _showLoadingDialog();
      }
      
      final path = await _saveExcelFile(_reportData);
      
      if (kIsWeb) {
        // En web ya se descargó automáticamente
        showSnackBar('Descarga de Excel iniciada');
      } else {
        // En móvil usamos share
        Navigator.of(context, rootNavigator: true).pop();
        await sharing.Share.shareXFiles(
          [sharing.XFile(path)], 
          text: 'Reporte de Asistencia'
        );
      }
    } catch (e) {
      developer.log('exportExcel: Error exportando Excel: $e');
      if (mounted) {
        if (!kIsWeb) Navigator.of(context, rootNavigator: true).pop();
        showSnackBar('Error exportando Excel: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Exportación a PDF - VERSIÓN UNIVERSAL
  Future<void> _exportPdf() async {
    if (_reportData.isEmpty) {
      if (mounted) {
        showSnackBar('No hay datos para exportar.');
      }
      return;
    }
    
    if (!mounted) return;
    
    setState(() => _loading = true);
    try {
      if (!kIsWeb) {
        _showLoadingDialog();
      }
      
      final path = await _savePdfFile(_reportData);
      
      if (kIsWeb) {
        // En web ya se descargó automáticamente
        showSnackBar('Descarga de PDF iniciada');
      } else {
        // En móvil usamos share
        Navigator.of(context, rootNavigator: true).pop();
        await sharing.Share.shareXFiles(
          [sharing.XFile(path)], 
          text: 'Reporte de Asistencia (PDF)'
        );
      }
    } catch (e) {
      developer.log('exportPdf: Error exportando PDF: $e');
      if (mounted) {
        if (!kIsWeb) Navigator.of(context, rootNavigator: true).pop();
        showSnackBar('Error exportando PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildFilterRow() {
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                value: _selectedEscuela,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todas')),
                ] +
                    escuelas
                        .map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() {
                  _selectedEscuela = v;
                }),
                decoration: const InputDecoration(labelText: 'Escuela', filled: true),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _selectedGrado,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                ] +
                    grados
                        .map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() {
                  _selectedGrado = v;
                }),
                decoration: const InputDecoration(labelText: 'Grado', filled: true),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _selectedGrupo,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                ] +
                    grupos
                        .map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() {
                  _selectedGrupo = v;
                }),
                decoration: const InputDecoration(labelText: 'Grupo', filled: true),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _selectedTurno,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                ] +
                    turnos
                        .map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() {
                  _selectedTurno = v;
                }),
                decoration: const InputDecoration(labelText: 'Turno', filled: true),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _selectedCiclo,
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                ] +
                    ciclos
                        .map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() {
                  _selectedCiclo = v;
                }),
                decoration: const InputDecoration(labelText: 'Ciclo escolar', filled: true),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextFormField(
                controller: _startDateController,
                readOnly: true,
                onTap: _pickStartDate,
                decoration: const InputDecoration(
                  labelText: 'Fecha inicial',
                  filled: true,
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextFormField(
                controller: _endDateController,
                readOnly: true,
                onTap: _pickEndDate,
                decoration: const InputDecoration(
                  labelText: 'Fecha final',
                  filled: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _generateReport,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('Generar Reporte'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _reportData.isNotEmpty && !_loading ? _exportExcel : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              child: const Text('Descargar en Excel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _reportData.isNotEmpty && !_loading ? _exportPdf : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
              child: const Text('Descargar en PDF'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    developer.log('build: Reconstruyendo ReportsScreen.');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulario de Asistencia - Reportes'),
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
            _buildFilterRow(),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: _reportData.isEmpty
                    ? Center(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('FECHA')),
                              DataColumn(label: Text('HORA')),
                              DataColumn(label: Text('NOMBRE')),
                              DataColumn(label: Text('GRADO')),
                              DataColumn(label: Text('GRUPO')),
                              DataColumn(label: Text('TURNO')),
                              DataColumn(label: Text('ESCUELA')),
                            ],
                            rows: _reportData.map((r) {
                              return DataRow(cells: [
                                DataCell(Text(r['fecha'] ?? '')),
                                DataCell(Text(r['hora'] ?? '')),
                                DataCell(Text(r['nombre'] ?? '')),
                                DataCell(Text(r['grado'] ?? '')),
                                DataCell(Text(r['grupo'] ?? '')),
                                DataCell(Text(r['turno'] ?? '')),
                                DataCell(Text(r['escuela'] ?? '')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}