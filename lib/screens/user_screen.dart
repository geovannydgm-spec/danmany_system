import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'reports_screen.dart';

class UserScreen extends StatefulWidget {
  final String role;

  const UserScreen({super.key, required this.role});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late Timer _timer;
  late DateTime _currentTime;
  String _formattedTime = '';
  String _formattedDate = '';
  String _selectedDay = '';

  late MobileScannerController _scannerController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CameraFacing _currentCamera = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    initializeDateFormatting('es', null).then((_) {
      Intl.defaultLocale = 'es';
      _updateTime();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTime();
      });
    });
  }

  /// Alterna entre cámara frontal y trasera.
  void _switchCamera() {
    setState(() {
      _currentCamera = _currentCamera == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back;
    });
    _scannerController.switchCamera();
  }

  void _updateTime() {
    final now = DateTime.now();
    _currentTime = now;
    setState(() {
      _formattedTime = DateFormat('hh:mm:ss a').format(_currentTime).toUpperCase();
      _formattedDate = DateFormat('dd/MMMM/yyyy', 'es').format(_currentTime);
      _selectedDay = DateFormat('EEEE', 'es').format(_currentTime).toUpperCase();
    });
  }

  Future<void> _saveAttendance(String studentId, Map<String, dynamic> studentData) async {
    try {
      await _firestore.collection('asistencia').doc(studentId).collection('registros').add({
        'nombreCompleto': '${studentData['nombres']} ${studentData['apellido_paterno']} ${studentData['apellido_materno']}',
        'grado': studentData['grado'],
        'grupo': studentData['grupo'],
        'turno': studentData['turno'],
        'escuela': studentData['escuela'],
        'fecha': _formattedDate,
        'hora': _formattedTime,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asistencia registrada con éxito!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al registrar la asistencia. Intenta de nuevo.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchStudentDataFromFirestore(String studentId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('students').doc(studentId).get();
      if (doc.exists) return doc.data() as Map<String, dynamic>;
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showStudentDataDialog(Map<String, dynamic> studentData) {
    String rawPhotoData = studentData['photo']?.toString() ?? '';
    String imageUrl = '';
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final match = urlRegex.firstMatch(rawPhotoData);
    if (match != null) imageUrl = match.group(0) ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Asistencia Registrada'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 150,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[200]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[300], child: const Center(child: CircularProgressIndicator())),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.error, color: Colors.red),
                            SizedBox(height: 4),
                            Text('Error de imagen', style: TextStyle(fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                Text('Escuela: ${studentData['escuela']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Nombre(s): ${studentData['nombres']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Apellido Paterno: ${studentData['apellido_paterno']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Apellido Materno: ${studentData['apellido_materno']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Turno: ${studentData['turno']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Grado: ${studentData['grado']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Grupo: ${studentData['grupo']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Ciclo Escolar: ${studentData['ciclo']}', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
        _scannerController.start();
      }
    });
  }

  void _handleQrScan(BarcodeCapture capture) async {
    _scannerController.stop();
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? studentId = barcodes.first.rawValue;
      if (studentId != null) {
        final studentData = await _fetchStudentDataFromFirestore(studentId);
        if (studentData != null) {
          await _saveAttendance(studentId, studentData);
          _showStudentDataDialog(studentData);
        } else {
          _showErrorDialog('Estudiante no encontrado. El ID del QR no corresponde a ningún registro.');
        }
      } else {
        _showErrorDialog('Código QR inválido. No se pudo leer el contenido.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(title: const Text('Error'), content: Text(message)),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
        _scannerController.start();
      }
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // ------------------------------------------------
  // Login de Reportes
  // ------------------------------------------------

  /// Muestra el diálogo de login para acceder a Reportes.
  /// Verifica credenciales en Firebase Auth y luego carga los permisos de Firestore.
  Future<void> _showReportesLogin() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isLoading = false;
    String errorMsg = '';

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.assessment, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Acceso a Reportes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ingresa tus credenciales para acceder a los reportes de asistencia.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.deepPurple),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                        ),
                      ),
                    ),
                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Flexible(child: Text(errorMsg, style: const TextStyle(color: Colors.red, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                            setDialogState(() => errorMsg = 'Por favor ingresa tu correo y contraseña.');
                            return;
                          }
                          setDialogState(() {
                            isLoading = true;
                            errorMsg = '';
                          });

                          try {
                            // Guardar usuario actual (maestro escaneando)
                            final usuarioActual = FirebaseAuth.instance.currentUser;
                            final emailActual = usuarioActual?.email;
                            final passActual = passCtrl.text.trim(); // No tenemos la pass del maestro actual

                            // Intentar login con las credenciales ingresadas
                            UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text.trim(),
                            );

                            final uid = cred.user!.uid;

                            // Buscar permisos en Firestore
                            final permisosDoc = await FirebaseFirestore.instance
                                .collection('usuarios_permisos')
                                .doc(uid)
                                .get();

                            if (!permisosDoc.exists) {
                              // No tiene permisos asignados
                              setDialogState(() {
                                isLoading = false;
                                errorMsg = 'No tienes permisos para acceder a los reportes. Contacta al administrador.';
                              });
                              // Volver a loguear al usuario que estaba activo
                              if (emailActual != null) {
                                await FirebaseAuth.instance.signInWithEmailAndPassword(
                                  email: emailActual,
                                  password: passCtrl.text.trim(),
                                );
                              }
                              return;
                            }

                            final permisos = permisosDoc.data() as Map<String, dynamic>;

                            // Cerrar diálogo y abrir reportes con permisos
                            if (mounted) {
                              Navigator.of(context).pop();
                              _abrirReportesConPermisos(permisos);
                            }
                          } on FirebaseAuthException catch (e) {
                            String msg = 'Credenciales incorrectas.';
                            if (e.code == 'user-not-found') msg = 'No existe una cuenta con ese correo.';
                            if (e.code == 'wrong-password') msg = 'Contraseña incorrecta.';
                            if (e.code == 'invalid-credential') msg = 'Correo o contraseña incorrectos.';
                            setDialogState(() {
                              isLoading = false;
                              errorMsg = msg;
                            });
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              errorMsg = 'Ocurrió un error inesperado. Intenta de nuevo.';
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Entrar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Abre la pantalla de reportes pasando los permisos del usuario.
  void _abrirReportesConPermisos(Map<String, dynamic> permisos) {
    _scannerController.stop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReportsScreen(permisos: permisos),
      ),
    ).then((_) {
      // Al regresar, reanudar el escáner
      if (mounted) _scannerController.start();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> weekdays = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia Escolar'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: false,
        // Botón de cambio de cámara centrado en el AppBar
        flexibleSpace: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: _switchCamera,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        actions: [
          // Botón de REPORTES con candado
          TextButton.icon(
            onPressed: _showReportesLogin,
            icon: const Icon(Icons.assessment, color: Colors.white),
            label: const Text(
              'REPORTES',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          // Botón de cerrar sesión
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleQrScan,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(204, 103, 58, 183),
                    Color.fromARGB(255, 30, 233, 213),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.8),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 3))],
                      ),
                      child: const Text(
                        'REGISTRO DE ASISTENCIA',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: weekdays.map((day) {
                          bool isSelected = day == _selectedDay;
                          return Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: isSelected
                                  ? BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(8))
                                  : null,
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.deepPurple,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _formattedTime.split(' ')[0],
                                style: const TextStyle(fontSize: 150, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formattedTime.split(' ').length > 1 ? _formattedTime.split(' ')[1] : '',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 3))],
                      ),
                      child: Text(
                        _formattedDate,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}