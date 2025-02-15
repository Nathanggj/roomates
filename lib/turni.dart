import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTurnsScreen extends StatefulWidget {
  final DateTime date;
  final String calendarId;
  const AddTurnsScreen({
    Key? key,
    required this.date,
    required this.calendarId,
  }) : super(key: key);

  @override
  _AddTurnsScreenState createState() => _AddTurnsScreenState();
}

class _AddTurnsScreenState extends State<AddTurnsScreen> {
  bool isLoading = true;
  List<Map<String, String>> userIdWithNicknames = [];
  int anonymousCounter = 1;
  String? selectedUserId;
  String? selectedCategory;
  Color selectedColor = Colors.blue; // Default color is blue

  final List<String> categories = [
    'Buttare la spazzatura',
    'Pulizia totale',
    'Lavare i piatti',
    'Pulire il bagno',
    'Passare la scopa',
  ];

  final List<Color> predefinedColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.pink,
  ];

  bool isRepeating = false;
  String selectedFrequency = 'Giornaliera';
  int customDays = 1;
  String check = 'Incompleto';

  final List<String> repetitionOptions = [
    'Giornaliera',
    'Settimanale',
    'Mensile',
    'Personalizzata',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserIdsAndNicknames();
  }

  Future<void> _fetchUserIdsAndNicknames() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('calendars')
          .where('name', isEqualTo: widget.calendarId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final calendarData = querySnapshot.docs.first.data();
        if (calendarData.containsKey('userIds') &&
            calendarData['userIds'] is List) {
          final List<String> userIds =
              List<String>.from(calendarData['userIds']);
          final List<Map<String, String>> mappedUsers = [];

          for (final userId in userIds) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            final nickname = (userDoc.exists &&
                    userDoc.data() != null &&
                    userDoc.data()!.containsKey('nickname'))
                ? userDoc.data()!['nickname'] as String
                : 'Anonimo ${anonymousCounter++}';
            mappedUsers.add({'userId': userId, 'nickname': nickname});
          }

          setState(() {
            userIdWithNicknames = mappedUsers;
            isLoading = false;
          });
        } else {
          throw Exception('Il campo "userIds" non è presente o non è valido.');
        }
      } else {
        throw Exception('Calendario non trovato.');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint(e.toString());
    }
  }

  void _selectUser() async {
    final selectedUser = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleziona un utente'),
          content: isLoading
              ? const Center(child: CircularProgressIndicator())
              : userIdWithNicknames.isEmpty
                  ? const Text('Nessun utente trovato.')
                  : SingleChildScrollView(
                      child: ListBody(
                        children: userIdWithNicknames
                            .map(
                              (user) => ListTile(
                                title: Text(user['nickname'] ?? 'Anonimo'),
                                onTap: () {
                                  Navigator.of(context).pop(user);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    if (selectedUser != null) {
      setState(() {
        selectedUserId = selectedUser['userId'];
      });
    }
  }

  void _selectCategory() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController customCategoryController =
            TextEditingController();

        return AlertDialog(
          title: const Text('Seleziona una categoria'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  child: ListBody(
                    children: categories
                        .map(
                          (category) => ListTile(
                            title: Text(category),
                            onTap: () {
                              Navigator.of(context).pop(category);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Categoria personalizzata:'),
                TextField(
                  controller: customCategoryController,
                  decoration: const InputDecoration(
                    hintText: 'Nuova categoria...',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Aggiungi'),
              onPressed: () {
                String customCategory = customCategoryController.text.trim();
                if (customCategory.isNotEmpty) {
                  Navigator.of(context).pop(customCategory);
                }
              },
            ),
          ],
        );
      },
    );

    if (selected != null) {
      setState(() {
        selectedCategory = selected;
      });
    }
  }

  void _selectColor() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scegli un colore'),
          content: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: predefinedColors.length,
            itemBuilder: (context, index) {
              final color = predefinedColors[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop(color);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.4),
                      width: 2.0,
                    ),
                  ),
                  width: 40,
                  height: 40,
                ),
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        selectedColor = selected;
      });
    }
  }

  void _add() async {
    // Verifica se l'utente e la categoria sono stati selezionati
    if (selectedUserId == null || selectedCategory == null) {
      // Mostra un messaggio di errore se non sono selezionati
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Devi selezionare un utente e una categoria.')),
      );
      return; // Interrompe l'operazione
    }

    DateTime startDate = widget.date;

    if (isRepeating) {
      int repeatCount = 1; // Numero di ripetizioni predefinito

      // Determina il numero di ripetizioni e l'intervallo
      switch (selectedFrequency) {
        case 'Giornaliera':
          repeatCount = 356;
          break;
        case 'Settimanale':
          repeatCount = 48;
          break;
        case 'Mensile':
          repeatCount = 12;
          break;
        case 'Personalizzata':
          repeatCount = 356; // Puoi regolarlo a piacere
          break;
      }

      for (int i = 0; i < repeatCount; i++) {
        // Calcola la nuova data in base alla frequenza
        DateTime newDate;
        if (selectedFrequency == 'Giornaliera') {
          newDate = startDate.add(Duration(days: i));
        } else if (selectedFrequency == 'Settimanale') {
          newDate = startDate.add(Duration(days: 7 * i));
        } else if (selectedFrequency == 'Mensile') {
          newDate =
              DateTime(startDate.year, startDate.month + i, startDate.day);
        } else {
          newDate = startDate.add(Duration(days: customDays * i));
        }

        // Aggiungi l'evento al database
        await FirebaseFirestore.instance.collection('turni').add({
          'calendarName': widget.calendarId,
          'data': newDate.toIso8601String().split('T')[0],
          'categoria': selectedCategory,
          'user': selectedUserId,
          'colore': selectedColor.value.toRadixString(16),
          'check': false,
        });
      }
    } else {
      // Aggiungi un singolo evento al database
      await FirebaseFirestore.instance.collection('turni').add({
        'calendarName': widget.calendarId,
        'data': startDate.toIso8601String().split('T')[0],
        'categoria': selectedCategory,
        'user': selectedUserId,
        'colore': selectedColor.value.toRadixString(16),
        'check': false,
      });
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Aggiungi un Turno',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        // Scrolla se il contenuto è troppo grande
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    'Aggiungi turno in $formattedDate\nPer il calendario: ${widget.calendarId}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Di chi è il turno?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectUser,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Text(
                      selectedUserId != null
                          ? userIdWithNicknames.firstWhere((user) =>
                                  user['userId'] ==
                                  selectedUserId)['nickname'] ??
                              'Anonimo'
                          : 'Seleziona un utente',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Categoria:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectCategory,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          selectedCategory ?? 'Seleziona una categoria',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _selectColor,
                          child: CircleAvatar(
                            backgroundColor: selectedColor,
                            radius: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ripetizione:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              // Switch per ripetizione evento
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ripeti evento?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Switch(
                    value: isRepeating,
                    onChanged: (value) {
                      setState(() {
                        isRepeating = value;
                        if (!isRepeating) {
                          selectedFrequency =
                              'Giornaliera'; // Reset se disattivato
                          customDays = 1;
                        }
                      });
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dropdown per selezionare la frequenza
              if (isRepeating)
                Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: DropdownButton<String>(
                      value: selectedFrequency,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      items: repetitionOptions.map((String option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedFrequency = newValue;
                            if (selectedFrequency != 'Personalizzata') {
                              customDays = 1; // Reset se non è personalizzato
                            }
                          });
                        }
                      },
                      underline: Container(),
                    ),
                  ),
                ),

              // Input per i giorni personalizzati
              if (isRepeating && selectedFrequency == 'Personalizzata')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Text(
                        'Ogni',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: 'N°',
                            hintStyle: const TextStyle(color: Colors.white54),
                          ),
                          onChanged: (value) {
                            setState(() {
                              customDays = int.tryParse(value) ?? 1;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'giorni',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: FloatingActionButton.extended(
          onPressed: () {
            _add();
          },
          label: const Text(
            'Aggiungi',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
