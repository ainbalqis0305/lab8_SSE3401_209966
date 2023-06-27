import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  FirebaseStorage storage = FirebaseStorage.instance;
  late CollectionReference imageRef;
  String _locationMessage = "";
  String _uploadTime = "";
  String _userDesc = "";
  final _descController = TextEditingController();

  //Get the location when uploading
  void _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    print(position);

    setState(() {
      _locationMessage = "${position.latitude}, ${position.longitude}";
      _uploadTime = "${position.timestamp}";
    });
  }

  // choose photo(s) from gallery/camera to be upload
  Future<void> _upload(String uploadType) async {
    final picker = ImagePicker();
    PickedFile? pickedImage;
    try {
      pickedImage = await picker.getImage(
        source:
            uploadType == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
      );

      final String fName = path.basename(pickedImage!.path);
      File imgFile = File(pickedImage.path);

      _getCurrentLocation();

      try {
        //Upload choosen photo(s) with some custom meta data
        final uploadTask = storage.ref().child('Gallery/${fName}').putFile(
            imgFile,
            SettableMetadata(customMetadata: {
              'description': 'Latest Image',
              'location': _locationMessage,
              'dateTime': _uploadTime,
            }));
        await uploadTask.whenComplete(() async {
          final urlImage = await uploadTask.snapshot.ref.getDownloadURL();
          imageRef.add({
            'url': urlImage,
            'description': 'Latest Image',
            'location': _locationMessage,
            'dateTime': _uploadTime
          });
          //);
        });
        setState(() {});
      } on FirebaseException catch (error) {
        print(error);
        if (error.code == 'object not found') {
          print('File does not exist at the specified reference');
        } else {
          print('Error uploading file: $error');
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    super.initState();
    imageRef = FirebaseFirestore.instance.collection('Posts');
  }

  //To retrieve uploaded photo(s)
  Future<List<Map<String, dynamic>>> _loadImages() async {
    List<Map<String, dynamic>> files = [];

    try {
      final ListResult result = await storage.ref().child('Gallery').listAll();
      final List<Reference> allFiles = result.items;

      if (allFiles.isEmpty) {
        print('Gallery folder is kosong');
      }

      await Future.forEach<Reference>(allFiles, (file) async {
        try {
          final String fileUrl = await file.getDownloadURL();
          final FullMetadata fileMeta = await file.getMetadata();
          files.add({
            "url": fileUrl,
            "path": file.fullPath,
            "description": fileMeta.customMetadata!['description'],
            "location": _locationMessage,
            "dateTime": _uploadTime
          });
        } catch (error) {
          if (error is FirebaseException && error.code == 'object not found') {
            print('File does not exist st the specified reference');
          } else {
            print('Error handling file: $error');
          }
        }
      });
    } catch (e) {
      print('Error loading images: $e');
    }
    return files;
  }

  //To delete choosen image
  Future<void> _delete(String ref) async {
    try {
      await storage.ref(ref).delete();
      //Rebuild the UI
      setState(() {});
    } catch (e) {
      if (e is FirebaseException && e.code == 'object not found') {
        print('File does not exist st the specified reference');
      } else {
        print('Error handling file: $e');
      }
    }
  }

  //Edit description
  void _setDescription(String ref) async {
    try {
      await storage.ref(ref).updateMetadata(
          SettableMetadata(customMetadata: {'description': _userDesc}));

      //Rebuild UI
      setState(() {});
    } catch (e) {
      if (e is FirebaseException && e.code == 'object not found') {
        print('File does not exist st the specified reference');
      } else {
        print('Error updating file: $e');
      }
    }
  }

  //Edit description form
  Future<void> _showEditForm(String ref) {
    return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (param) {
          return AlertDialog(
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: () async {
                  setState(() {
                    _userDesc = _descController.text;
                  });
                  _setDescription(ref);
                  imageRef
                      .doc(ref)
                      .update({'description': _descController.text});

                  if (_descController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _descController.text = "";
                  }
                },
                child: Text('Update'),
              ),
            ],
            title: Text('Edit discription'),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _descController,
                    decoration:
                        InputDecoration(hintText: 'Enter a new description'),
                  )
                ],
              ),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your photos'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                    onPressed: () => _upload('camera'),
                    icon: Icon(Icons.camera),
                    label: Text('Camera')),
                ElevatedButton.icon(
                    onPressed: () => _upload('gallery'),
                    icon: Icon(Icons.library_add),
                    label: Text('Gallery')),
              ],
            ),
            Expanded(
              child: FutureBuilder(
                future: _loadImages(),
                builder: (context,
                    AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return ListView.builder(
                      itemCount: snapshot.data?.length,
                      itemBuilder: (context, index) {
                        final image = snapshot.data![index];
                        return Card(
                          elevation: 5,
                          margin: EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                              dense: false,
                              leading: Image.network(image['url']),
                              title: Text(image['description']),
                              subtitle: Column(children: <Widget>[
                                IconButton(
                                  onPressed: () => _showEditForm(image['path']),
                                  icon: Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _delete(image['path']),
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                              ])),
                        );
                      },
                    );
                  }
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/*class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: Image.asset(
              "assets/san.jpeg",
              fit: BoxFit.cover,
            ),
          ),
          Text(
            "Super duper safe acc balance",
            style: GoogleFonts.passionOne(fontSize: 32.0),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            "0 %",
            style: GoogleFonts.passionOne(fontSize: 32.0),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}*/
