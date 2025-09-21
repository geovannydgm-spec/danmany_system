// Importaciones de paquetes de Flutter y Firebase
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:ui' as ui;
import 'reports_screen.dart';

/// `AdminScreen` es un `StatefulWidget` que muestra el panel de administración.
/// Contiene una barra lateral de navegación y un área de contenido principal que cambia
/// según el ítem seleccionado en la barra lateral.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

/// El estado de `AdminScreen` gestiona la lógica de la UI, la conexión a Firestore y
/// la interacción con Firebase Authentication.
class _AdminScreenState extends State<AdminScreen> {
  // ------------------------------------------------
  // 1. Variables de Estado y Controladores
  // ------------------------------------------------

  // Colores principales de la interfaz, basados en las imágenes proporcionadas.
  final Color _primaryColor = Colors.deepPurple;
  final Color _accentColor = const Color.fromARGB(255, 30, 233, 213);
  final Color _mainContentBackgroundColor =
      const Color.fromARGB(255, 230, 230, 230);
  final Color _cardColor = const Color.fromARGB(255, 240, 240, 240);

  // Variable para controlar qué sección de la barra lateral está seleccionada.
  String _selectedNavItem = 'Inicio';

  // Controladores para los campos de texto del formulario de creación de usuario.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Controladores para los campos de texto del formulario de alumnos.
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentPaternalNameController =
      TextEditingController();
  final TextEditingController _studentMaternalNameController =
      TextEditingController();
  final TextEditingController _studentGradeController = TextEditingController();
  final TextEditingController _studentShiftController = TextEditingController();
  final TextEditingController _studentGroupController = TextEditingController();
  final TextEditingController _studentTeacherController =
      TextEditingController();
  final TextEditingController _studentSchoolController =
      TextEditingController();
  final TextEditingController _studentSchoolYearController =
      TextEditingController();
  // Instancia de Firestore para interactuar con la base de datos.
  late final FirebaseFirestore _firestore;
  // Variables para almacenar los datos de los estudiantes y la asistencia.
  int _totalStudents = 0;
  int _todayAttendance = 0;
  List<DocumentSnapshot> _students = [];

  // Suscripción para escuchar cambios en tiempo real en la colección de alumnos.
  StreamSubscription<QuerySnapshot>? _studentSubscription;
  // Key para capturar la imagen del QR.
  final GlobalKey _qrKey = GlobalKey();
  // ------------------------------------------------
  // 2. Ciclo de Vida del Widget
  // ------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Inicializa la configuración de idioma para el formato de fecha.
    initializeDateFormatting('es', null);
    // Obtiene la instancia de Firestore.
    _firestore = FirebaseFirestore.instance;
    // Llama al método para obtener los datos de los alumnos al iniciar.
    _fetchStudents();
  }

  @override
  void dispose() {
    // Libera los controladores y cancela la suscripción para evitar fugas de memoria.
    _emailController.dispose();
    _passwordController.dispose();
    _studentSubscription?.cancel();
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
  // 3. Métodos de Lógica de Negocio (Firebase y Firestore)
  // ------------------------------------------------

  /// Obtiene los datos de la colección `students` en tiempo real.
  /// La suscripción se actualiza automáticamente cuando hay cambios en la base de datos.
  void _fetchStudents() {
    _studentSubscription?.cancel();
    _studentSubscription =
        _firestore.collection('students').snapshots().listen((snapshot) {
      // Verifica si el widget aún está montado antes de actualizar el estado.
      if (mounted) {
        setState(() {
          _students = snapshot.docs;
          _totalStudents = snapshot.docs.length;
        });
        // Llama a la función para actualizar la asistencia cada vez que los datos cambian.
        _countTodayAttendance();
      }
    });
  }

  /// Cuenta la asistencia de los alumnos para el día actual.
  /// Busca en la colección `students` a los alumnos cuya asistencia
  /// contenga la fecha de hoy.
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
          const SnackBar(
              content: Text('Error al obtener la asistencia de hoy.')),
        );
      }
    }
  }

  /// Crea un nuevo usuario con correo electrónico y contraseña usando Firebase Auth.
  Future<void> _createAccount() async {
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Por favor, ingresa el correo y la contraseña.')),
        );
        return;
      }

      // Obtiene el correo del usuario actual (administrador).
      final adminEmail = FirebaseAuth.instance.currentUser?.email;
      // Crea un nuevo usuario con el correo y contraseña proporcionados.
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text, password: _passwordController.text);
      // Inicia sesión de nuevo con la cuenta del administrador para mantener la sesión activa.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: adminEmail!,
        password: '123456789', // Contraseña hardcodeada del administrador.
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Usuario ${userCredential.user?.email} creado exitosamente.')),
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
        message = 'Ocurrió un error al crear la cuenta. Inténtalo de nuevo.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocurrió un error inesperado.')),
        );
      }
    }
  }

  /// Muestra un diálogo para añadir o editar los datos de un alumno en Firestore.
  /// Si se pasa un objeto `student`, se entra en modo de edición.
  Future<void> _showStudentDialog({DocumentSnapshot? student}) async {
    final bool isEditing = student != null;
    if (isEditing) {
      // Precarga los datos del alumno en los controladores en modo de edición.
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
      // Limpia los controladores para un nuevo alumno.
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
              content: ConstrainedBox( // Utiliza ConstrainedBox para establecer una altura máxima
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _studentNameController,
                          decoration: const InputDecoration(labelText: 'Nombres'),
                        ),
                        TextField(
                          controller: _studentPaternalNameController,
                          decoration:
                              const InputDecoration(labelText: 'Apellido Paterno'),
                        ),
                        TextField(
                          controller: _studentMaternalNameController,
                          decoration:
                              const InputDecoration(labelText: 'Apellido Materno'),
                        ),
                        TextField(
                          controller: _studentGradeController,
                          decoration: const InputDecoration(labelText: 'Grado'),
                        ),
                        TextField(
                          controller: _studentGroupController,
                          decoration: const InputDecoration(labelText: 'Grupo'),
                        ),
                        TextField(
                          controller: _studentShiftController,
                          decoration: const InputDecoration(labelText: 'Turno'),
                        ),
                        TextField(
                          controller: _studentTeacherController,
                          decoration: const InputDecoration(labelText: 'Profesor'),
                        ),
                        TextField(
                          controller: _studentSchoolController,
                          decoration: const InputDecoration(labelText: 'Escuela'),
                        ),
                        TextField(
                          controller: _studentSchoolYearController,
                          decoration:
                              const InputDecoration(labelText: 'Ciclo Escolar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_studentNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'El nombre del alumno no puede estar vacío.')),
                      );
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
                        // Actualiza el documento existente.
                        await _firestore
                            .collection('students')
                            .doc(student!.id)
                            .update(studentData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Alumno actualizado correctamente.')),
                        );
                      } else {
                        // Crea un nuevo documento.
                        await _firestore.collection('students').add(studentData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Alumno añadido correctamente.')),
                        );
                      }

                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Ocurrió un error al guardar los datos.')),
                      );
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

  /// Muestra un diálogo de confirmación y elimina un alumno de Firestore.
  Future<void> _deleteStudent(String docId, String name) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text('¿Estás seguro de que quieres eliminar a $name?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child:
                    const Text('Eliminar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _firestore.collection('students').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Alumno $name eliminado correctamente.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al eliminar el alumno.')),
          );
        }
      }
    }
  }

  /// Método para cargar y procesar archivos Excel.
  Future<void> _pickAndProcessExcelFile() async {
    try {
      // Abre el selector de archivos, aceptando solo archivos .xlsx.
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result != null && result.files.isNotEmpty) {
        if (result.files.first.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No se pudieron leer los datos del archivo.')),
            );
          }
          return;
        }

        // Lee el archivo Excel.
        var excel = Excel.decodeBytes(result.files.first.bytes!);
        var table = excel.tables[excel.tables.keys.first];

        if (table == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('El archivo Excel está vacío o no tiene hojas.')),
            );
          }
          return;
        }

        // Crea un batch de Firestore para subir los documentos de manera eficiente.
        WriteBatch batch = _firestore.batch();
        final collectionRef = _firestore.collection('students');
        int studentsAdded = 0;
        // Itera sobre las filas de la tabla de Excel.
        // Se asume que la primera fila es el encabezado y se omite.
        for (var row in table.rows.skip(1)) {
          // Asume el orden de las columnas: nombres, apellido_paterno, apellido_materno, grado, grupo, profesor, escuela, ciclo_escolar, turno.
          // Asegúrate de que este orden coincida con las columnas en tu archivo Excel.
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
          
          // Agrega la operación de creación al batch.
          batch.set(collectionRef.doc(), studentData);
          studentsAdded++;
        }

        // Envía el batch a Firestore.
        if (studentsAdded > 0) {
          await batch.commit();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Se han subido $studentsAdded alumnos correctamente.')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('El archivo no contiene datos de alumnos.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selección de archivo cancelada.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al procesar el archivo. Revisa el formato.')),
        );
      }
    }
  }

  /// Muestra un diálogo con el QR del alumno y un botón para descargarlo.
  Future<void> _showQRDialog(String studentId, String studentName) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Código QR para $studentName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ENVUELVE EL QR EN UN SIZEDBOX CON DIMENSIONES FIJAS
              SizedBox(
                width: 200,
                height: 200,
                child: RepaintBoundary(
                  key: _qrKey, // Asigna la key al widget para poder capturarlo.
                  child: QrImageView(
                    data: studentId, // Los datos del QR serán el ID del estudiante.
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    embeddedImage: const AssetImage('assets/images/logo.png'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(40, 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _downloadQR(studentName),
                icon: const Icon(Icons.download),
                label: const Text('Descargar QR'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  /// Captura el widget del QR y lo guarda como una imagen en la galería del dispositivo.
  Future<void> _downloadQR(String studentName) async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      if (Platform.isAndroid || Platform.isIOS) {
        // Guarda la imagen en la galería del teléfono.
        final result = await ImageGallerySaver.saveImage(
          pngBytes,
          quality: 100,
          name: "QR_Estudiante_$studentName.png",
        );
        if (result['isSuccess']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR descargado en la galería.')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al guardar en la galería.')),
            );
          }
        }
      } else {
        // Guarda la imagen en un directorio local para web/escritorio.
        final directory = (await getApplicationDocumentsDirectory()).path;
        final file = File('$directory/QR_Estudiante_$studentName.png');
        await file.writeAsBytes(pngBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('QR guardado en: ${file.path}')),
          );
        }
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
  // 4. Métodos de Construcción de la UI (Widgets)
  // ------------------------------------------------

  /// El método `build` construye la estructura principal de la pantalla de administración.
  /// Contiene un `Scaffold` con un `AppBar` y un `Row` para la barra lateral y el contenido.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Cierra la sesión del usuario actual.
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. Barra Lateral de Navegación
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 48, 48, 48),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'Panel de administración',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
          // 2. Contenido Principal del Panel
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

  /// Construye el widget del contenido principal según el `_selectedNavItem`.
  /// Utiliza un `switch` para mostrar diferentes secciones de la interfaz.
  Widget _buildMainContent(String navItem) {
    switch (navItem) {
      case 'Inicio':
        // Vista del panel principal con tarjetas de resumen y la tabla de alumnos.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Panel de Inicio',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
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
                _buildSummaryCard('Poblacion Escolar', _totalStudents.toString()),
                const SizedBox(width: 20),
                _buildSummaryCard(
                    'Asistencia de hoy', _todayAttendance.toString()),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Gestión de Alumnos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                // Botón para cargar y procesar archivos Excel.
                ElevatedButton.icon(
                  onPressed: _pickAndProcessExcelFile,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text('Subir Archivo', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Botón para añadir un solo alumno.
                ElevatedButton.icon(
                  onPressed: () => _showStudentDialog(),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Añadir Alumno', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
            const Text(
              'Gestión de Usuarios',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Text(
                  'Contenido para $_selectedNavItem aún no implementado.',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        );
      case 'Reportes':
        // Navega a la pantalla de reportes.
        return ReportsScreen();
      case 'Crear Cuenta':
        // Vista del formulario para crear nuevas cuentas de usuario.
        return Center(
          child: Container(
            padding: const EdgeInsets.all(30),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Crear Nuevo Usuario',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Crear Cuenta',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        // Contenido por defecto para secciones no implementadas.
        return Center(
          child: Text(
            'Contenido para $_selectedNavItem aún no implementado.',
            style: const TextStyle(fontSize: 20),
          ),
        );
    }
  }

  /// Construye un widget para un ítem de la barra lateral.
  /// Cambia su estilo si está seleccionado.
  Widget _buildNavItem(String title, IconData icon) {
    bool isSelected = _selectedNavItem == title;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: isSelected
          ? BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedNavItem = title;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navegando a $title')),
          );
        },
      ),
    );
  }

  /// Construye una tarjeta de resumen para mostrar estadísticas.
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye la tabla de alumnos.
  /// La tabla se compone de una fila de encabezados y un `ListView.builder`
  /// para las filas de datos.
  Widget _buildStudentTable() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Fila de encabezados de la tabla
              _buildTableRow(
                id: 'ID',
                nombres: 'Nombres',
                apellidoPaterno: 'A. Paterno',
                apellidoMaterno: 'A. Materno',
                grado: 'Grado',
                grupo: 'Grupo',
                profesor: 'Profesor',
                escuela: 'Escuela',
                cicloEscolar: 'Ciclo Escolar',
                acciones: 'Acciones',
                isHeader: true,
              ),
              const Divider(),
              // Filas de datos de la tabla, generadas dinámicamente.
              Expanded(
                child: ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final data = student.data() as Map<String, dynamic>;

                    return _buildTableRow(
                      id: student.id.substring(0, 4) + '...',
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
                      studentName:
                          (data['nombres'] ?? '') + ' ' + (data['apellido_paterno'] ?? ''),
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

  /// Widget auxiliar para construir una fila de la tabla, ya sea un encabezado o una fila de datos.
  Widget _buildTableRow({
    required String id,
    required String nombres,
    required String apellidoPaterno,
    required String apellidoMaterno,
    required String grado,
    required String grupo,
    required String profesor,
    required String escuela,
    required String cicloEscolar,
    String? acciones,
    required bool isHeader,
    String? documentId,
    String? studentName,
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
            Expanded(
              flex: 2,
              child: Text(acciones!, style: textStyle),
            )
          else
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      // Busca el documento del estudiante y abre el diálogo de edición.
                      _showStudentDialog(
                          student: _students.firstWhere((doc) => doc.id == documentId));
                    },
                    child: const Text('Editar'),
                  ),
                  TextButton(
                    onPressed: () => _deleteStudent(documentId!, studentName!),
                    child: const Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showQRDialog(documentId!, studentName!),
                    child: const Text('QR'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}