import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';

// La pantalla principal para usuarios autenticados.
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

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Inicializa las configuraciones de localización para español.
    initializeDateFormatting('es', null).then((_) {
      Intl.defaultLocale = 'es';
      _updateTime(); // Llama a _updateTime para la fecha y hora iniciales.
      // Configura el temporizador para actualizar la hora cada segundo.
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTime();
      });
    });
  }

  /// Actualiza la hora y fecha actuales y las formatea.
  void _updateTime() {
    
    final now = DateTime.now();
    _currentTime = now; 

    setState(() {
      // Formatea la hora en formato de 12 horas con AM/PM.
      _formattedTime = DateFormat('hh:mm:ss a').format(_currentTime).toUpperCase();
      // Formatea la fecha completa en español.
      _formattedDate = DateFormat('dd/MMMM/yyyy', 'es').format(_currentTime);
      // Obtiene el nombre del día de la semana en español y en mayúsculas.
      _selectedDay = DateFormat('EEEE', 'es').format(_currentTime).toUpperCase();
    });
  }

  /// Guarda la asistencia del estudiante en la colección 'asistencia' de Firestore.
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
        'timestamp': FieldValue.serverTimestamp(), // Usa el timestamp del servidor para mayor precisión.
      });
      // Muestra un mensaje de éxito si el registro fue exitoso.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asistencia registrada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error al guardar en Firestore: $e');
      // Muestra un mensaje de error si falla el registro.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar la asistencia. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Busca los datos de un estudiante en Firestore usando su ID.
  Future<Map<String, dynamic>?> _fetchStudentDataFromFirestore(String studentId) async {
    try {
      // Obtiene el documento del estudiante de la colección 'students'.
      DocumentSnapshot doc = await _firestore.collection('students').doc(studentId).get();
      if (doc.exists) {
        // Devuelve los datos si el documento existe.
        return doc.data() as Map<String, dynamic>;
      } else {
        // Devuelve null si el estudiante no se encuentra.
        return null;
      }
    } catch (e) {
      print('Error buscando el estudiante en Firestore: $e');
      return null; // Devuelve null en caso de error.
    }
  }
/// Muestra un cuadro de diálogo con los datos del estudiante y su foto.
void _showStudentDataDialog(Map<String, dynamic> studentData) {
  String rawPhotoData = studentData['photo']?.toString() ?? '';
  String imageUrl = '';

  // Usar una expresión regular para encontrar la URL.
  // Esto es más robusto que .trim() si hay caracteres extraños.
  final urlRegex = RegExp(r'https?:\/\/[^\s]+');
  final match = urlRegex.firstMatch(rawPhotoData);
  if (match != null) {
    imageUrl = match.group(0) ?? '';
  }

  print("URL extraída: $imageUrl");

  showDialog(
    context: context,
    barrierDismissible: false, // Impide que se cierre al tocar fuera
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
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) {
                        // Imprime el error en la consola para depuración
                        print('Error al cargar la imagen: $error');
                        return Container(
                          color: Colors.grey[300],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(height: 4),
                              Text('Error de imagen', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      },
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

  // Cierra automáticamente el diálogo después de 1 segundo y reanuda el escáner.
  Future.delayed(const Duration(seconds: 1), () {
    if (mounted) {
      Navigator.of(context).pop();
      _scannerController.start();
    }
  });
}




  /// Procesa la detección del código de barras o QR.
  void _handleQrScan(BarcodeCapture capture) async {
    // Detiene el escáner temporalmente para procesar el código.
    _scannerController.stop();
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? studentId = barcodes.first.rawValue;
      if (studentId != null) {
        final studentData = await _fetchStudentDataFromFirestore(studentId);

        if (studentData != null) {
          // Guarda la asistencia del estudiante.
          await _saveAttendance(studentId, studentData);
          // Muestra los datos del estudiante en un diálogo.
          _showStudentDataDialog(studentData);
        } else {
          // Muestra un error si el estudiante no se encuentra.
          _showErrorDialog('Estudiante no encontrado. El ID del QR no corresponde a ningún registro.');
        }
      } else {
        // Muestra un error si el código QR es inválido.
        _showErrorDialog('Código QR inválido. No se pudo leer el contenido.');
      }
    }
  }

  /// Muestra un diálogo de error y reanuda el escáner.
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
        );
      },
    );

    // Cierra el diálogo y reanuda el escáner después de 1 segundo.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
        _scannerController.start();
      }
    });
  }

  /// Cierra la sesión del usuario actual.
  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancela el temporizador al eliminar el widget.
    _scannerController.dispose(); // Libera los recursos del controlador de la cámara.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lista de los días de la semana en español.
    final List<String> weekdays = [
      'LUNES',
      'MARTES',
      'MIÉRCOLES',
      'JUEVES',
      'VIERNES',
      'SÁBADO',
      'DOMINGO',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia Escolar'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white, // Color del texto del AppBar.
        actions: [
          // Botón para cerrar sesión.
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Widget para mostrar la cámara.
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleQrScan,
            ),
          ),
          // Superposición con información de la aplicación.
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
                    // Título principal de la pantalla.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.8),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'REGISTRO DE ASISTENCIA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Días de la semana.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
                                  ? BoxDecoration(
                                      color: Colors.deepPurple,
                                      borderRadius: BorderRadius.circular(8),
                                    )
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _formattedTime.split(' ')[0], // Parte de la hora (ej: '10')
                                style: const TextStyle(
                                  fontSize: 150,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formattedTime.split(' ').length > 1 ? _formattedTime.split(' ')[1] : '', // Parte de AM/PM
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Fecha actual.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _formattedDate,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
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