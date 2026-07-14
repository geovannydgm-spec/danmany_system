import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'reports_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final Color _primaryColor = Colors.deepPurple;
  final Color _accentColor = const Color.fromARGB(255, 30, 233, 213);
  final Color _mainContentBackgroundColor = const Color.fromARGB(255, 230, 230, 230);
  final Color _cardColor = const Color.fromARGB(255, 240, 240, 240);

  // ⚠️ API Key de Firebase (solo para crear usuarios sin cerrar sesión del admin)
  static const String _firebaseApiKey = 'AIzaSyAvBfnmXD1ncPtTHmCupLz-ehYdygP-STk';

  String _selectedNavItem = 'Inicio';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentPaternalNameController = TextEditingController();
  final TextEditingController _studentMaternalNameController = TextEditingController();
  final TextEditingController _studentGradeController = TextEditingController();
  final TextEditingController _studentShiftController = TextEditingController();
  final TextEditingController _studentGroupController = TextEditingController();
  final TextEditingController _studentTeacherController = TextEditingController();
  final TextEditingController _studentSchoolController = TextEditingController();
  final TextEditingController _studentSchoolYearController = TextEditingController();

  late final FirebaseFirestore _firestore;
  int _totalStudents = 0;
  int _todayAttendance = 0;
  List<DocumentSnapshot> _students = [];
  List<DocumentSnapshot> _studentsFiltrados = []; // lista filtrada por búsqueda
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<QuerySnapshot>? _studentSubscription;
  final GlobalKey _qrKey = GlobalKey();

  List<DocumentSnapshot> _usuarios = [];
  StreamSubscription<QuerySnapshot>? _usuariosSubscription;

  List<String> _opcionesEscuelas = [];
  List<String> _opcionesGrados = [];
  List<String> _opcionesGrupos = [];
  List<String> _opcionesTurnos = [];
  List<String> _opcionesCiclos = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _firestore = FirebaseFirestore.instance;
    _fetchStudents();
    _fetchUsuarios();
    _loadOpcionesFromFirestore();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _studentSubscription?.cancel();
    _usuariosSubscription?.cancel();
    _studentNameController.dispose();
    _studentPaternalNameController.dispose();
    _studentMaternalNameController.dispose();
    _studentGradeController.dispose();
    _studentShiftController.dispose();
    _studentGroupController.dispose();
    _studentTeacherController.dispose();
    _studentSchoolController.dispose();
    _studentSchoolYearController.dispose();
    super.dispose();
  }

  // ------------------------------------------------
  // Métodos de Alumnos
  // ------------------------------------------------

  void _fetchStudents() {
    _studentSubscription?.cancel();
    _studentSubscription = _firestore.collection('students').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _students = snapshot.docs;
          _totalStudents = snapshot.docs.length;
          _filtrarAlumnos(_searchController.text);
        });
        _countTodayAttendance();
      }
    });
  }

  /// Filtra la lista de alumnos según el texto de búsqueda.
  void _filtrarAlumnos(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _studentsFiltrados = List.from(_students);
      } else {
        _studentsFiltrados = _students.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nombre = '${data['nombres']} ${data['apellido_paterno']} ${data['apellido_materno']}'.toLowerCase();
          final escuela = (data['escuela'] ?? '').toString().toLowerCase();
          final grado = (data['grado'] ?? '').toString().toLowerCase();
          final grupo = (data['grupo'] ?? '').toString().toLowerCase();
          final turno = (data['turno'] ?? '').toString().toLowerCase();
          return nombre.contains(q) || escuela.contains(q) || grado.contains(q) || grupo.contains(q) || turno.contains(q);
        }).toList();
      }
    });
  }

  void _countTodayAttendance() async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    try {
      final querySnapshot = await _firestore
          .collection('students')
          .where('attendance', arrayContains: today)
          .get();
      if (mounted) {
        setState(() {
          _todayAttendance = querySnapshot.docs.length;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al obtener la asistencia de hoy.')),
        );
      }
    }
  }

  Future<void> _showStudentDialog({DocumentSnapshot? student}) async {
    final bool isEditing = student != null;
    if (isEditing) {
      _studentNameController.text = student['nombres'] ?? '';
      _studentPaternalNameController.text = student['apellido_paterno'] ?? '';
      _studentMaternalNameController.text = student['apellido_materno'] ?? '';
      _studentGradeController.text = student['grado'] ?? '';
      _studentShiftController.text = student['turno'] ?? '';
      _studentGroupController.text = student['grupo'] ?? '';
      _studentTeacherController.text = student['profesor'] ?? '';
      _studentSchoolController.text = student['escuela'] ?? '';
      _studentSchoolYearController.text = student['ciclo'] ?? '';
    } else {
      _studentNameController.clear();
      _studentPaternalNameController.clear();
      _studentMaternalNameController.clear();
      _studentGradeController.clear();
      _studentShiftController.clear();
      _studentGroupController.clear();
      _studentTeacherController.clear();
      _studentSchoolController.clear();
      _studentSchoolYearController.clear();
    }

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Alumno' : 'Añadir Alumno'),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(controller: _studentNameController, decoration: const InputDecoration(labelText: 'Nombres')),
                        TextField(controller: _studentPaternalNameController, decoration: const InputDecoration(labelText: 'Apellido Paterno')),
                        TextField(controller: _studentMaternalNameController, decoration: const InputDecoration(labelText: 'Apellido Materno')),
                        TextField(controller: _studentGradeController, decoration: const InputDecoration(labelText: 'Grado')),
                        TextField(controller: _studentGroupController, decoration: const InputDecoration(labelText: 'Grupo')),
                        TextField(controller: _studentShiftController, decoration: const InputDecoration(labelText: 'Turno')),
                        TextField(controller: _studentTeacherController, decoration: const InputDecoration(labelText: 'Profesor')),
                        TextField(controller: _studentSchoolController, decoration: const InputDecoration(labelText: 'Escuela')),
                        TextField(controller: _studentSchoolYearController, decoration: const InputDecoration(labelText: 'Ciclo Escolar')),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (_studentNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre no puede estar vacío.')));
                      return;
                    }
                    try {
                      final Map<String, dynamic> studentData = {
                        'nombres': _studentNameController.text,
                        'apellido_paterno': _studentPaternalNameController.text,
                        'apellido_materno': _studentMaternalNameController.text,
                        'grupo': _studentGroupController.text,
                        'profesor': _studentTeacherController.text,
                        'escuela': _studentSchoolController.text,
                        'ciclo': _studentSchoolYearController.text,
                        'grado': _studentGradeController.text,
                        'turno': _studentShiftController.text,
                      };
                      if (isEditing) {
                        await _firestore.collection('students').doc(student!.id).update(studentData);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alumno actualizado correctamente.')));
                      } else {
                        await _firestore.collection('students').add(studentData);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alumno añadido correctamente.')));
                      }
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ocurrió un error al guardar los datos.')));
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Añadir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStudent(String docId, String name) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text('¿Estás seguro de que quieres eliminar a $name?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _firestore.collection('students').doc(docId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alumno $name eliminado correctamente.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar el alumno.')));
      }
    }
  }

  Future<void> _pickAndProcessExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
      if (result != null && result.files.isNotEmpty) {
        if (result.files.first.bytes == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron leer los datos del archivo.')));
          return;
        }
        var excel = Excel.decodeBytes(result.files.first.bytes!);
        var table = excel.tables[excel.tables.keys.first];
        if (table == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El archivo Excel está vacío o no tiene hojas.')));
          return;
        }
        WriteBatch batch = _firestore.batch();
        final collectionRef = _firestore.collection('students');
        int studentsAdded = 0;
        for (var row in table.rows.skip(1)) {
          final studentData = {
            'nombres': row[0]?.value?.toString() ?? '',
            'apellido_paterno': row[1]?.value?.toString() ?? '',
            'apellido_materno': row[2]?.value?.toString() ?? '',
            'grado': row[3]?.value?.toString() ?? '',
            'grupo': row[4]?.value?.toString() ?? '',
            'profesor': row[5]?.value?.toString() ?? '',
            'escuela': row[6]?.value?.toString() ?? '',
            'ciclo': row[7]?.value?.toString() ?? '',
            'turno': row[8]?.value?.toString() ?? '',
          };
          batch.set(collectionRef.doc(), studentData);
          studentsAdded++;
        }
        if (studentsAdded > 0) {
          await batch.commit();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se han subido $studentsAdded alumnos correctamente.')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El archivo no contiene datos de alumnos.')));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selección de archivo cancelada.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar el archivo. Revisa el formato.')));
    }
  }

  /// Genera las iniciales de la escuela. Ej: "Carmen Serdan" -> "CS"
  String _inicialesEscuela(String escuela) {
    final palabras = escuela.trim().split(RegExp(r'\s+'));
    return palabras.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
  }

  /// Genera el nombre del archivo QR. Ej: CS5A01
  String _nombreArchivoQR(String escuela, String grado, String grupo, int numeroLista) {
    final iniciales = _inicialesEscuela(escuela);
    final num = numeroLista.toString().padLeft(2, '0');
    return '$iniciales$grado${grupo.toUpperCase()}$num';
  }

  Future<void> _showQRDialog(
    String studentId,
    String studentName, {
    required String escuelaNombre,
    required String gradoNombre,
    required String grupoNombre,
    required int numeroLista,
  }) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Código QR para $studentName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: RepaintBoundary(
                  key: _qrKey,
                  child: QrImageView(
                    data: studentId,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    embeddedImage: const AssetImage('assets/images/logo.png'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _nombreArchivoQR(escuelaNombre, gradoNombre, grupoNombre, numeroLista),
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _downloadQR(
                  escuelaNombre: escuelaNombre,
                  gradoNombre: gradoNombre,
                  grupoNombre: grupoNombre,
                  numeroLista: numeroLista,
                ),
                icon: const Icon(Icons.download),
                label: const Text('Descargar QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
          ],
        );
      },
    );
  }

  Future<void> _downloadQR({
    required String escuelaNombre,
    required String gradoNombre,
    required String grupoNombre,
    required int numeroLista,
  }) async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final fileName = '${_nombreArchivoQR(escuelaNombre, gradoNombre, grupoNombre, numeroLista)}.png';

      // Descarga web usando dart:html
      // ignore: avoid_web_libraries_in_flutter
      final blob = html.Blob([pngBytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR descargado como $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al descargar el QR.')),
        );
      }
    }
  }
  // ------------------------------------------------
  // Métodos de Gestión de Usuarios con Permisos
  // ------------------------------------------------

  Future<void> _loadOpcionesFromFirestore() async {
    try {
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
          _opcionesEscuelas = sEsc.toList()..sort();
          _opcionesGrados = sGr.toList()..sort();
          _opcionesGrupos = sGrup.toList()..sort();
          _opcionesTurnos = sTurn.toList()..sort();
          _opcionesCiclos = sCiclo.toList()..sort();
        });
      }
    } catch (e) {
      // Si no hay datos aún, las listas quedan vacías
    }
  }

  void _fetchUsuarios() {
    _usuariosSubscription?.cancel();
    _usuariosSubscription = _firestore.collection('usuarios_permisos').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _usuarios = snapshot.docs;
        });
      }
    });
  }

  /// Crea un usuario usando la API REST de Firebase sin cerrar la sesión del admin.
  Future<String> _crearUsuarioSinCerrarSesion(String email, String password) async {
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_firebaseApiKey',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final responseData = jsonDecode(response.body);
    if (responseData['error'] != null) {
      final errorCode = responseData['error']['message'] as String;
      if (errorCode.contains('EMAIL_EXISTS')) {
        throw FirebaseAuthException(code: 'email-already-in-use', message: 'El correo ya está en uso.');
      } else if (errorCode.contains('WEAK_PASSWORD')) {
        throw FirebaseAuthException(code: 'weak-password', message: 'La contraseña es muy débil.');
      } else {
        throw FirebaseAuthException(code: errorCode, message: errorCode);
      }
    }
    return responseData['localId'] as String;
  }

  Future<void> _showUsuarioDialog({DocumentSnapshot? usuario}) async {
    final bool isEditing = usuario != null;
    final data = isEditing ? (usuario.data() as Map<String, dynamic>) : null;

    final emailCtrl = TextEditingController(text: data?['email'] ?? '');
    final passCtrl = TextEditingController();

    List<String> escuelasSeleccionadas = List<String>.from(data?['escuelas'] ?? []);
    List<String> gradosSeleccionados = List<String>.from(data?['grados'] ?? []);
    List<String> gruposSeleccionados = List<String>.from(data?['grupos'] ?? []);
    List<String> turnosSeleccionados = List<String>.from(data?['turnos'] ?? []);
    List<String> ciclosSeleccionados = List<String>.from(data?['ciclos'] ?? []);
    bool puedeExcel = data?['puede_excel'] ?? true;
    bool puedePdf = data?['puede_pdf'] ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildMultiSelect(String titulo, List<String> opciones, List<String> seleccionados) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  opciones.isEmpty
                      ? const Text('Sin opciones disponibles (agrega alumnos primero)',
                          style: TextStyle(fontSize: 12, color: Colors.grey))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: opciones.map((opcion) {
                            final selected = seleccionados.contains(opcion);
                            return FilterChip(
                              label: Text(opcion, style: const TextStyle(fontSize: 12)),
                              selected: selected,
                              selectedColor: Colors.deepPurple.shade100,
                              checkmarkColor: Colors.deepPurple,
                              onSelected: (val) {
                                setDialogState(() {
                                  if (val) {
                                    seleccionados.add(opcion);
                                  } else {
                                    seleccionados.remove(opcion);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 12),
                ],
              );
            }

            return AlertDialog(
              title: Text(isEditing ? 'Editar Usuario' : 'Nuevo Usuario'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                  maxWidth: 500,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailCtrl,
                        enabled: !isEditing,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isEditing)
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      if (!isEditing) const SizedBox(height: 20),
                      const Divider(),
                      const Text('Permisos de acceso a reportes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurple)),
                      const SizedBox(height: 12),
                      buildMultiSelect('Escuelas', _opcionesEscuelas, escuelasSeleccionadas),
                      buildMultiSelect('Grados', _opcionesGrados, gradosSeleccionados),
                      buildMultiSelect('Grupos', _opcionesGrupos, gruposSeleccionados),
                      buildMultiSelect('Turnos', _opcionesTurnos, turnosSeleccionados),
                      buildMultiSelect('Ciclos Escolares', _opcionesCiclos, ciclosSeleccionados),
                      const Divider(),
                      const Text('Formatos de descarga permitidos',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurple)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Puede descargar Excel'),
                        value: puedeExcel,
                        activeColor: Colors.deepPurple,
                        onChanged: (val) => setDialogState(() => puedeExcel = val),
                      ),
                      SwitchListTile(
                        title: const Text('Puede descargar PDF'),
                        value: puedePdf,
                        activeColor: Colors.deepPurple,
                        onChanged: (val) => setDialogState(() => puedePdf = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (!isEditing && (emailCtrl.text.isEmpty || passCtrl.text.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El correo y la contraseña son obligatorios.')),
                      );
                      return;
                    }

                    try {
                      String uid;

                      if (!isEditing) {
                        // Crear usuario via API REST sin cerrar sesión del admin
                        uid = await _crearUsuarioSinCerrarSesion(
                          emailCtrl.text.trim(),
                          passCtrl.text.trim(),
                        );
                      } else {
                        uid = usuario.id;
                      }

                      // Guardar permisos en Firestore
                      await _firestore.collection('usuarios_permisos').doc(uid).set({
                        'email': emailCtrl.text.trim(),
                        'escuelas': escuelasSeleccionadas,
                        'grados': gradosSeleccionados,
                        'grupos': gruposSeleccionados,
                        'turnos': turnosSeleccionados,
                        'ciclos': ciclosSeleccionados,
                        'puede_excel': puedeExcel,
                        'puede_pdf': puedePdf,
                      }, SetOptions(merge: true));

                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEditing ? 'Usuario actualizado correctamente.' : 'Usuario creado correctamente.')),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      String msg = 'Error al crear el usuario.';
                      if (e.code == 'email-already-in-use') msg = 'El correo ya está en uso.';
                      if (e.code == 'weak-password') msg = 'La contraseña es muy débil (mínimo 6 caracteres).';
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Crear Usuario'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUsuario(String uid, String email) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text('¿Estás seguro de que quieres eliminar a $email?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _firestore.collection('usuarios_permisos').doc(uid).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Usuario $email eliminado.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar el usuario.')));
      }
    }
  }

  // ------------------------------------------------
  // UI
  // ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/icons/icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.school, color: Colors.white, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Panel de Administración',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 250,
            decoration: const BoxDecoration(color: Color.fromARGB(255, 48, 48, 48)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text('Panel de administración',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(color: Colors.white54, thickness: 1),
                  _buildNavItem('Inicio', Icons.dashboard),
                  _buildNavItem('Usuarios', Icons.group),
                  _buildNavItem('Reportes', Icons.assessment),
                  _buildNavItem('Crear Cuenta', Icons.person_add),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: _mainContentBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: _buildMainContent(_selectedNavItem),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(String navItem) {
    switch (navItem) {
      case 'Inicio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Panel de Inicio',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filtrarAlumnos,
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _filtrarAlumnos('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard('Población Escolar', _totalStudents.toString()),
                const SizedBox(width: 20),
                _buildSummaryCard('Asistencia de hoy', _todayAttendance.toString()),
              ],
            ),
            const SizedBox(height: 30),
            const Text('Gestión de Alumnos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 15),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickAndProcessExcelFile,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text('Subir Archivo', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: () => _showStudentDialog(),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Añadir Alumno', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStudentTable(),
          ],
        );

      case 'Usuarios':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gestión de Usuarios',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                ElevatedButton.icon(
                  onPressed: () => _showUsuarioDialog(),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Nuevo Usuario', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: _usuarios.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay usuarios registrados aún.\nPresiona "Nuevo Usuario" para agregar uno.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _usuarios.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final u = _usuarios[index];
                          final d = u.data() as Map<String, dynamic>;
                          final escuelas = (d['escuelas'] as List?)?.join(', ') ?? 'Todas';
                          final grados = (d['grados'] as List?)?.join(', ') ?? 'Todos';
                          final grupos = (d['grupos'] as List?)?.join(', ') ?? 'Todos';
                          final turnos = (d['turnos'] as List?)?.join(', ') ?? 'Todos';
                          final ciclos = (d['ciclos'] as List?)?.join(', ') ?? 'Todos';
                          final puedeExcel = d['puede_excel'] == true;
                          final puedePdf = d['puede_pdf'] == true;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _primaryColor,
                              child: Text(
                                (d['email'] as String? ?? '?')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(d['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                _permisoBadgeRow('Escuelas', escuelas),
                                _permisoBadgeRow('Grados', grados),
                                _permisoBadgeRow('Grupos', grupos),
                                _permisoBadgeRow('Turnos', turnos),
                                _permisoBadgeRow('Ciclos', ciclos),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(puedeExcel ? Icons.check_circle : Icons.cancel,
                                        color: puedeExcel ? Colors.green : Colors.red, size: 16),
                                    const SizedBox(width: 4),
                                    const Text('Excel  ', style: TextStyle(fontSize: 12)),
                                    Icon(puedePdf ? Icons.check_circle : Icons.cancel,
                                        color: puedePdf ? Colors.green : Colors.red, size: 16),
                                    const SizedBox(width: 4),
                                    const Text('PDF', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.deepPurple),
                                  tooltip: 'Editar permisos',
                                  onPressed: () => _showUsuarioDialog(usuario: u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Eliminar usuario',
                                  onPressed: () => _deleteUsuario(u.id, d['email'] ?? ''),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );

      case 'Reportes':
        return const ReportsScreen();

      case 'Crear Cuenta':
        return Center(
          child: Container(
            padding: const EdgeInsets.all(30),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Crear Nuevo Usuario',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor)),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Crear Cuenta', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        );

      default:
        return Center(
          child: Text('Contenido para $_selectedNavItem aún no implementado.', style: const TextStyle(fontSize: 20)),
        );
    }
  }

  Widget _permisoBadgeRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          Flexible(child: Text(valor, style: const TextStyle(fontSize: 12, color: Colors.black87), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildNavItem(String title, IconData icon) {
    bool isSelected = _selectedNavItem == title;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: isSelected ? BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)) : null,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        onTap: () {
          setState(() => _selectedNavItem = title);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navegando a $title')));
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    return Expanded(
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: _cardColor,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTable() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildTableRow(
                id: 'ID', nombres: 'Nombres', apellidoPaterno: 'A. Paterno',
                apellidoMaterno: 'A. Materno', grado: 'Grado', grupo: 'Grupo',
                profesor: 'Profesor', escuela: 'Escuela', cicloEscolar: 'Ciclo Escolar',
                acciones: 'Acciones', isHeader: true,
              ),
              const Divider(),
              Expanded(
                child: _studentsFiltrados.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isNotEmpty
                              ? 'No se encontraron resultados para "${_searchController.text}"'
                              : 'No hay alumnos registrados.',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _studentsFiltrados.length,
                        itemBuilder: (context, index) {
                          final student = _studentsFiltrados[index];
                          final data = student.data() as Map<String, dynamic>;
                          // Número de lista basado en posición en lista filtrada
                          final numeroLista = index + 1;
                          return _buildTableRow(
                            id: '${student.id.substring(0, 4)}...',
                            nombres: data['nombres'] ?? '',
                            apellidoPaterno: data['apellido_paterno'] ?? '',
                            apellidoMaterno: data['apellido_materno'] ?? '',
                            grado: data['grado'] ?? '',
                            grupo: data['grupo'] ?? '',
                            profesor: data['profesor'] ?? '',
                            escuela: data['escuela'] ?? '',
                            cicloEscolar: data['ciclo'] ?? '',
                            isHeader: false,
                            documentId: student.id,
                            studentName: '${data['nombres'] ?? ''} ${data['apellido_paterno'] ?? ''}',
                            escuelaNombre: data['escuela'] ?? '',
                            gradoNombre: data['grado'] ?? '',
                            grupoNombre: data['grupo'] ?? '',
                            numeroLista: numeroLista,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required String id, required String nombres, required String apellidoPaterno,
    required String apellidoMaterno, required String grado, required String grupo,
    required String profesor, required String escuela, required String cicloEscolar,
    String? acciones, required bool isHeader, String? documentId, String? studentName,
    String? escuelaNombre, String? gradoNombre, String? grupoNombre, int? numeroLista,
  }) {
    final TextStyle textStyle = TextStyle(
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      color: Colors.black87,
      fontSize: isHeader ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Expanded(child: Text(id, style: textStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text(nombres, style: textStyle)),
          Expanded(child: Text(apellidoPaterno, style: textStyle)),
          Expanded(child: Text(apellidoMaterno, style: textStyle)),
          Expanded(child: Text(grado, style: textStyle)),
          Expanded(child: Text(grupo, style: textStyle)),
          Expanded(child: Text(profesor, style: textStyle)),
          Expanded(child: Text(escuela, style: textStyle)),
          Expanded(child: Text(cicloEscolar, style: textStyle)),
          if (isHeader)
            Expanded(flex: 2, child: Text(acciones!, style: textStyle))
          else
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => _showStudentDialog(student: _students.firstWhere((doc) => doc.id == documentId)),
                    child: const Text('Editar'),
                  ),
                  TextButton(
                    onPressed: () => _deleteStudent(documentId!, studentName!),
                    child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ),
                  TextButton(
                    onPressed: () => _showQRDialog(
                      documentId!,
                      studentName!,
                      escuelaNombre: escuelaNombre ?? '',
                      gradoNombre: gradoNombre ?? '',
                      grupoNombre: grupoNombre ?? '',
                      numeroLista: numeroLista ?? 0,
                    ),
                    child: const Text('QR'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createAccount() async {
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa el correo y la contraseña.')));
        return;
      }
      // Usar API REST para no cerrar sesión del admin
      final uid = await _crearUsuarioSinCerrarSesion(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario ${_emailController.text} creado exitosamente.')),
        );
      }
      _emailController.clear();
      _passwordController.clear();
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'La contraseña es demasiado débil.';
      } else if (e.code == 'email-already-in-use') {
        message = 'La cuenta ya existe para ese correo.';
      } else {
        message = 'Ocurrió un error al crear la cuenta.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}