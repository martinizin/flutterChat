import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  Location location = Location();

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLocation();
  }

  Future<void> _checkPermissionsAndLocation() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      FirebaseFirestore.instance.collection('chats').add({
        'text': _controller.text,
        'createdAt': Timestamp.now(),
      });
      _controller.clear();
    }
  }

  void _sendLocation() async {
    LocationData _locationData = await location.getLocation();
    String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${_locationData.latitude},${_locationData.longitude}';
    FirebaseFirestore.instance.collection('chats').add({
      'text': '$googleMapsUrl',
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> _editMessage(String docId, String newText) async {
    await FirebaseFirestore.instance.collection('chats').doc(docId).update({
      'text': newText,
    });
  }

  Future<void> _deleteMessage(String docId) async {
    await FirebaseFirestore.instance.collection('chats').doc(docId).delete();
  }

  void _showEditDeleteDialog(String docId, String currentText) {
    final editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Aquí puedes editar el mensaje'),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(labelText: 'Mensaje'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                _editMessage(docId, editController.text);
                Navigator.of(context).pop();
              },
              child: Text('Editar'),
            ),
            TextButton(
              onPressed: () {
                _deleteMessage(docId);
                Navigator.of(context).pop();
              },
              child: Text('Borrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, chatSnapshot) {
                if (chatSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (chatSnapshot.hasError) {
                  return Center(
                    child: Text('Error: ${chatSnapshot.error}'),
                  );
                }
                if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('Envía un mensaje.'),
                  );
                }
                final chatDocs = chatSnapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: chatDocs.length,
                  itemBuilder: (ctx, index) {
                    final docId = chatDocs[index].id;
                    final messageText = chatDocs[index]['text'];
                    return GestureDetector(
                      onTap: () => _showEditDeleteDialog(docId, messageText),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            messageText,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(labelText: 'Mensaje'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
                IconButton(
                  icon: Icon(Icons.location_on),
                  onPressed: _sendLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
