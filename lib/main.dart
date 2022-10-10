import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();

  runApp(const CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(brightness: Brightness.dark),
      title: 'Camera App',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Camera'),
        ),
        body: const Center(child: CameraBox()),
      ),
    );
  }
}

class CameraBox extends StatefulWidget {
  const CameraBox({Key? key}) : super(key: key);

  @override
  State<CameraBox> createState() => _CameraBoxState();
}

class _CameraBoxState extends State<CameraBox> {
  late CameraController controller;
  List<Map<String, String?>> imageFiles = [];

  @override
  void initState() {
    super.initState();
    // setImagePath();
    controller = CameraController(_cameras.first, ResolutionPreset.low,);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  Future<void> setImagePath() async {
    // imageFiles = await getPathList();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<List<String>> getPathList() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? paths = prefs.getStringList('paths');
    if (paths == null){
      return [];
    }
    return paths;

  }

  void onCapturePressed(){
    takePicture()?.then((XFile? file) async {
      if (mounted && file != null) {
        GallerySaver.saveImage(file.path, albumName: "compressed cam");
        final compressed = await compressAndGetFile(File(file.path));
        if (compressed != null){
          GallerySaver.saveImage(compressed.path, albumName: "compressed cam");
        }

        setState(() {
          imageFiles.add({
            "original": file.path,
            "compressed": compressed?.path
          });
        });
        // final prefs = await SharedPreferences.getInstance();
        //
        // prefs.setStringList('paths', imageFiles);
        showInSnackBar("${file.path} ");
      }
    });
  }
  void showInSnackBar(String message,){
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<File?> compressAndGetFile(File file) async {
    final tmpDir = (await getTemporaryDirectory()).path;
    final target = '$tmpDir/${DateTime.now().millisecondsSinceEpoch}.png';
    var result = await FlutterImageCompress.compressAndGetFile(file.absolute.path, target, format: CompressFormat.png, quality: 50);

    return result;
  }

  Future<XFile?>? takePicture() async {
    final CameraController cameraController = controller;
    if (!cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      final XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print(e);
      return null;
    }
  }



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 300,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.only(bottom: 20),
            child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(height: 10, child: CameraPreview(controller))),
          ),
          ElevatedButton(
            onPressed: () {
              onCapturePressed();
            },
            style: ElevatedButton.styleFrom(
                primary: Colors.black38,
                minimumSize: const Size.fromHeight(48)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.camera),
                ),
                Text("Capture")
              ],
            ),
          ),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: imageFiles.map((image){
                    return GestureDetector(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (BuildContext context){
                          return ImagePage(original: image['original']!, compressed: image['compressed']!);
                        }));
                      },
                      child: Container(
                        width: 100,
                        height: 180,
                        margin: const EdgeInsets.only(left: 8),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8)
                        ),
                        child: FittedBox(
                          fit: BoxFit.cover,
                            child: Image.file(File(image['original']!))),
                      ),
                    );
                  }).toList()
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ImagePage extends StatelessWidget {
  final String original;
  final String compressed;
  const ImagePage({Key? key, required this.original, required this.compressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final originalFile = File(original);
    final compressedFile = File(compressed);
    return Scaffold(
      appBar: AppBar(
        title: Text(originalFile.path.split('/').last),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        height: double.infinity,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Container(
                    height: 180,
                    width: 100,
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8)
                    ),
                    child: Image.file(originalFile),
                  ),
                  Text('Original \n ${(originalFile.lengthSync() / (1000 * 1000)).toStringAsPrecision(3)} mb', textAlign: TextAlign.center,)
                ],
              ),
              Column(
                children: [
                  Container(
                    height: 180,
                    width: 100,
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8)
                    ),
                    child: Image.file(compressedFile),
                  ),
                  Text('Compressed \n ${(compressedFile.lengthSync() / (1000 * 1000)).toStringAsPrecision(3)} mb', textAlign: TextAlign.center,)
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

