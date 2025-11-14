import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detector Anatómico',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  String _result = 'Toma una foto para analizar';
  bool _isAnalyzing = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _result = 'Analizando imagen...';
          _isAnalyzing = true;
        });
        await _analyzeImage(_image!);
      }
    } catch (e) {
      _showError('Error al tomar foto: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _result = 'Analizando imagen...';
          _isAnalyzing = true;
        });
        await _analyzeImage(_image!);
      }
    } catch (e) {
      _showError('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _analyzeImage(File image) async {
    try {
      final inputImage = InputImage.fromFile(image);

      // Configuración del detector de poses
      final options = PoseDetectorOptions();
      final poseDetector = PoseDetector(options: options);

      final List<Pose> poses = await poseDetector.processImage(inputImage);

      setState(() {
        _isAnalyzing = false;

        if (poses.isNotEmpty) {
          final pose = poses.first;
          _result = '✅ Puntos detectados: ${pose.landmarks.length}\n'
              'Pose detectada correctamente';
        } else {
          _result = '❌ No se detectaron puntos anatómicos\n'
              'Intenta con otra imagen';
        }
      });

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _result = '❌ Error en el análisis: $e';
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _resetApp() {
    setState(() {
      _image = null;
      _result = 'Toma una foto para analizar';
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector Anatómico'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_image != null)
            IconButton(
              onPressed: _resetApp,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Área de la imagen
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : const Center(
                child: Icon(Icons.photo_camera, size: 50),
              ),
            ),

            const SizedBox(height: 20),

            // Resultado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isAnalyzing ? Colors.blue[100] :
                _result.contains('✅') ? Colors.green[100] :
                _result.contains('❌') ? Colors.red[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_isAnalyzing)
                    const CircularProgressIndicator()
                  else if (_result.contains('✅'))
                    const Icon(Icons.check, color: Colors.green)
                  else if (_result.contains('❌'))
                      const Icon(Icons.error, color: Colors.red)
                    else
                      const Icon(Icons.info, color: Colors.blue),

                  const SizedBox(width: 12),
                  Expanded(child: Text(_result)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Botones
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAnalyzing ? null : _pickImageFromCamera,
                    child: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAnalyzing ? null : _pickImageFromGallery,
                    child: const Text('Galería'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}