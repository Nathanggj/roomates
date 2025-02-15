import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Importa la pagina AddMulte
import 'add_multe.dart';

class MulteScreen extends StatefulWidget {
  final String calendarId;
  const MulteScreen({Key? key, required this.calendarId}) : super(key: key);

  @override
  _MulteScreenState createState() => _MulteScreenState();
}

class _MulteScreenState extends State<MulteScreen> {
  int anonymousCounter = 1;
  List<Map<String, String>> userIdWithNicknames = [];
  Map<String, String> userIdToNickname = {};
  bool isLoading = true;
  String? errorMessage;
  double totaleSalvadanaio = 0.0;
  Map<String, double> debitiUtenti = {};

  @override
  void initState() {
    super.initState();
    _fetchUserIdsAndNicknames();
    _fetchSalvadanaioData();
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

            final nickname = userDoc.exists &&
                    userDoc.data()!.containsKey('nickname')
                ? userDoc['nickname'] as String
                : 'Anonimo ${anonymousCounter++}'; // Usa il contatore per gli anonimi

            mappedUsers.add({'userId': userId, 'nickname': nickname});
            userIdToNickname[userId] = nickname; // Mappa ID -> Nickname
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
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _fetchSalvadanaioData() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('salvadanaio')
          .doc(widget.calendarId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          totaleSalvadanaio = (data['totaleSalvadanaio'] ?? 0).toDouble();
          final debiti = data['debitiUtenti'] as Map<String, dynamic>? ?? {};
          debitiUtenti =
              debiti.map((key, value) => MapEntry(key, value.toDouble()));
        });
      } else {
        setState(() {
          totaleSalvadanaio = 0.0;
          debitiUtenti = {};
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> multa_reset() async {
    var user = await FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('multe').add({
      'calendarId': widget.calendarId,
      'description': 'Salvadanaio azzerato',
      'amount': totaleSalvadanaio,
      'date': DateTime.now().toIso8601String().split("T")[0],
      'user': user,
      'imageUrl': null,
    });
  }

  Future<void> _resetDebt() async {
    multa_reset();

    FirebaseFirestore.instance
        .collection('salvadanaio')
        .doc(widget.calendarId)
        .get()
        .then((doc) {
      if (doc.exists) {
        Map<String, dynamic> debiti = doc.data()?['debitiUtenti'] ?? {};
        debiti.updateAll((key, value) => 0);
        FirebaseFirestore.instance
            .collection('salvadanaio')
            .doc(widget.calendarId)
            .update({'debitiUtenti': debiti})
            .then((_) => print("Debiti degli utenti azzerati"))
            .catchError(
                (error) => print("Errore nell'azzerare i debiti: $error"));
        _fetchSalvadanaioData();
      }
    }).catchError(
            // ignore: invalid_return_type_for_catch_error
            (error) => print("Errore nel recupero del documento: $error"));
    FirebaseFirestore.instance
        .collection('salvadanaio')
        .doc(widget.calendarId)
        .update({'totaleSalvadanaio': 0})
        .then((_) => print("Salvadanaio azzerato"))
        .catchError(
            (error) => print("Errore nell'azzerare il salvadanaio: $error"));
    _fetchSalvadanaioData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Multe", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Resoconto del salvadanaio

              Card(
                color: const Color.fromARGB(
                    255, 243, 236, 236), // Colore di sfondo distintivo
                elevation:
                    8.0, // Aumenta l'elevazione per un'ombra più pronunciata
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(15.0), // Bordi arrotondati
                  side: BorderSide(
                    color: Colors.deepPurple, // Colore del bordo
                    width: 4.0,
                  ),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(
                    "Totale Salvadanaio: €$totaleSalvadanaio",
                    style: const TextStyle(color: Colors.black),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...debitiUtenti.entries.map((entry) {
                        final nickname =
                            userIdToNickname[entry.key] ?? 'Anonimo';
                        return Text(
                          "$nickname: €${entry.value}",
                          style: const TextStyle(color: Colors.black),
                        );
                      }).toList(),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          _resetDebt();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          backgroundColor:
                              Colors.black, // Colore del testo del pulsante
                        ),
                        child: const Text('Azzera salvadanaio'),
                      ),
                    ],
                  ),
                ),
              ),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("multe")
                    .where("calendarId", isEqualTo: widget.calendarId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text("Errore: ${snapshot.error}",
                            style: const TextStyle(color: Colors.white)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text("Nessuna multa presente.",
                            style: TextStyle(color: Colors.white70)));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final description =
                          data["description"] ?? "Senza descrizione";
                      final amount = data["amount"] != null
                          ? data["amount"].toString()
                          : "0";
                      final date = data["date"] ?? "";
                      final utente = data['user'];
                      return Card(
                        color: const Color(0xFF1F1F1F),
                        margin: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 0),
                        child: ListTile(
                          title: Text(
                            description,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            "Importo: €$amount ${userIdToNickname[utente]}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Text(
                            date,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            final imageUrl = data['imageUrl'] as String?;
                            if (imageUrl != null && imageUrl.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.black,
                                  content: Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                                0.8,
                                      ),
                                      child: Image.network(
                                        imageUrl,
                                        loadingBuilder: (BuildContext context,
                                            Widget child,
                                            ImageChunkEvent? loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          } else {
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        (loadingProgress
                                                                .expectedTotalBytes ??
                                                            1)
                                                    : null,
                                              ),
                                            );
                                          }
                                        },
                                        fit: BoxFit.contain,
                                      )),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "Chiudi",
                                        style:
                                            TextStyle(color: Colors.blueAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddMulte(
                      userIdWithNicknames: userIdWithNicknames,
                      calendarId: widget.calendarId,
                    )),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
