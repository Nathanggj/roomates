import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddMulte extends StatefulWidget {
  final List<Map<String, String>> userIdWithNicknames;
  final String calendarId;

  const AddMulte(
      {Key? key, required this.userIdWithNicknames, required this.calendarId})
      : super(key: key);

  @override
  _AddMulteState createState() => _AddMulteState();
}

class _AddMulteState extends State<AddMulte> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  File? _image;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _initSupa();
  }

  Future<void> _initSupa() async {
    await Supabase.initialize(
      url: 'https://uaietvolnzncudrelble.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhaWV0dm9sbnpuY3VkcmVsYmxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkxOTM5NTQsImV4cCI6MjA1NDc2OTk1NH0.GAPUW4Yapz7gps1l_1ck0qfBb85FX94LoR86ifE8fvQ',
    );
  }

  // Funzione per caricare l'immagine nello storage di Supabase
  Future<String?> _uploadImage() async {
    if (_image == null) return null;
    try {
      final supabase = Supabase.instance.client;
      // Create a unique file name using the current timestamp.
      final fileName =
          "multe_images/${DateTime.now().millisecondsSinceEpoch}.png";
      // Upload the image.
      final response =
          await supabase.storage.from('img').upload(fileName, _image!);
      if (response.isEmpty) {
        if (kDebugMode) {
          print("Error during upload");
        }
        return null;
      }
      // Get the public URL directly (getPublicUrl returns a String).
      final publicUrl = supabase.storage.from('img').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<void> _addDatabase() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seleziona un utente prima di procedere")),
      );
      return;
    }

    // Se è stata scelta un'immagine, esegue l'upload e ottiene l'URL
    String? imageUrl;
    if (_image != null) {
      imageUrl = await _uploadImage();
    }

    await FirebaseFirestore.instance.collection("multe").add({
      "calendarId": widget.calendarId,
      "description": _descriptionController.text,
      "amount": double.parse(_amountController.text),
      "date": _selectedDate.toIso8601String().split("T")[0],
      "user": _selectedUserId,
      "imageUrl": imageUrl,
    });
    await _addDebito();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Multa aggiunta con successo!")),
    );
    // Pulizia del form
    _descriptionController.clear();
    _amountController.clear();
    setState(() {
      _selectedUserId = null; // Reset della selezione
      _selectedDate = DateTime.now();
      _image = null;
    });
    Navigator.of(context).pop();
  }

  Future<void> _addDebito() async {
    // Convertiamo l'importo della multa in double.
    final fineAmount = double.parse(_amountController.text);
    final calendarId = widget.calendarId;
    final userId =
        _selectedUserId!; // _selectedUserId non è null perché lo verifichiamo prima

    // Riferimento al documento "salvadanaio" per il calendario corrente.
    final docRef =
        FirebaseFirestore.instance.collection('salvadanaio').doc(calendarId);

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      // Se il documento esiste, aggiorna i valori esistenti.
      final data = docSnapshot.data() as Map<String, dynamic>;
      final currentTotal = (data['totaleSalvadanaio'] ?? 0) as num;
      // "debitiUtenti" è una mappa con userId come chiave e il debito come valore.
      final currentDebiti =
          (data['debitiUtenti'] ?? {}) as Map<String, dynamic>;
      final currentUserDebt = (currentDebiti[userId] ?? 0) as num;

      final newTotal = currentTotal + fineAmount;
      final newUserDebt = currentUserDebt + fineAmount;

      await docRef.update({
        "totaleSalvadanaio": newTotal,
        "debitiUtenti": {
          ...currentDebiti, // mantieni i debiti già registrati per gli altri utenti
          userId: newUserDebt, // aggiorna o imposta il debito per questo utente
        },
        // È possibile aggiornare anche un timestamp per tenere traccia dell'ultima modifica
        "lastUpdated": FieldValue.serverTimestamp(),
      });
    } else {
      // Se il documento non esiste, creane uno nuovo.
      await docRef.set({
        "calendarId": calendarId,
        "totaleSalvadanaio": fineAmount,
        "debitiUtenti": {userId: fineAmount},
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _image = File(image.path);
        });
      }
    } catch (e) {
      print("Errore nell'aprire la galleria: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Aggiungi Multa',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF121212),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Seleziona Utente',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.black),
                  items: widget.userIdWithNicknames.map((user) {
                    return DropdownMenuItem<String>(
                      value: user['userId'],
                      child: Text(user['nickname'] ?? 'Anonimo',
                          style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Seleziona un utente';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci una descrizione';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Importo',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci un importo';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Inserisci un importo valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(_selectedDate.year - 5),
                          lastDate: DateTime(_selectedDate.year + 5),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.blueAccent,
                                  onPrimary: Colors.white,
                                  surface: Colors.grey[800]!,
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.black,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _selectedDate = pickedDate;
                          });
                        }
                      },
                      child: const Text(
                        'Seleziona Data',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _image == null
                        ? const Icon(Icons.camera_alt, color: Colors.white)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _image!,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _addDatabase();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Aggiungi Multa',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
