import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coinquiz/multe.dart';
import 'package:coinquiz/shopping_list.dart';
import 'package:coinquiz/turni.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:page_transition/page_transition.dart';
import 'package:table_calendar/table_calendar.dart';
import 'splitwise.dart';

class CalendarScreen extends StatefulWidget {
  final String calendarName;
  final String nickname;

  const CalendarScreen(
      {super.key, required this.calendarName, required this.nickname});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final TextEditingController _eventController = TextEditingController();
  int anonymousCounter = 1;
  List<Map<String, String>> userIdWithNicknames = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, String> userIdToNickname = {};

  // Liste per gli eventi e per i turni
  List<Map<String, dynamic>> _events = []; // da "events"
  List<Map<String, dynamic>> _turniForDay =
      []; // da "turni" per il giorno selezionato

  // Mappa per i marker nel calendario (sia eventi che turni)
  Map<DateTime, List> _eventMarkers = {};

  @override
  void initState() {
    super.initState();
    _fetchUserIdsAndNicknames();
    _loadEventsForCalendar();
    _loadTurniForCalendar();
    _selectedDay = _focusedDay;
    _loadEventsForDay(_focusedDay);
    _loadTurniForDay(_focusedDay);
  }

  Future<void> _fetchUserIdsAndNicknames() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('calendars')
          .where('name', isEqualTo: widget.calendarName)
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

  // FUNZIONI PER LA NAVIGAZIONE
  void _openShoppingList() {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        duration: Duration(milliseconds: 900),
        child: ShoppingListScreen(calendarName: widget.calendarName),
      ),
    );
  }

  void _openSplitwise() {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        duration: Duration(milliseconds: 900),
        child: AddExpenseScreen(calendarId: widget.calendarName),
      ),
    );
  }

  void _openMulte() {
    Navigator.push(
      context,
      PageTransition(
          type: PageTransitionType.fade,
          duration: Duration(milliseconds: 900),
          child: MulteScreen(calendarId: widget.calendarName)),
    );
  }

  // Carica gli eventi dalla collezione "events" per il calendario
  Future<void> _loadEventsForCalendar() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('calendarName', isEqualTo: widget.calendarName)
        .get();

    setState(() {
      // Inizializza la mappa (attenzione a non sovrascrivere eventuali marker già aggiunti dai turni)
      _eventMarkers = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final eventDate = DateTime.parse(data['date']);
        final normalizedDate =
            DateTime(eventDate.year, eventDate.month, eventDate.day);
        if (_eventMarkers[normalizedDate] == null) {
          _eventMarkers[normalizedDate] = [];
        }
        // Per gli eventi usiamo una stringa (o qualsiasi identificativo)
        _eventMarkers[normalizedDate]?.add(data['event']);
      }
    });
  }

  // Carica i turni dalla collezione "turni" per il calendario
  Future<void> _loadTurniForCalendar() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('turni')
        .where('calendarName', isEqualTo: widget.calendarName)
        .get();

    setState(() {
      // Aggiungi i turni nella stessa mappa dei marker
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // Il campo data deve essere salvato in formato ISO (es. "2025-02-10")
        final turnoDate = DateTime.parse(data['data']);
        final normalizedDate =
            DateTime(turnoDate.year, turnoDate.month, turnoDate.day);
        if (_eventMarkers[normalizedDate] == null) {
          _eventMarkers[normalizedDate] = [];
        }
        // Aggiungiamo un marker di tipo "turno" con il colore salvato
        _eventMarkers[normalizedDate]?.add({
          'type': 'turno',
          'colore': data['colore'], // es. "fff44336"
        });
      }
    });
  }

  // Carica gli eventi per un giorno specifico dalla collezione "events"
  Future<void> _loadEventsForDay(DateTime day) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('calendarName', isEqualTo: widget.calendarName)
        .where('date',
            isEqualTo: DateTime(day.year, day.month, day.day)
                .toIso8601String()
                .split('T')[0])
        .get();

    setState(() {
      _events = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'data': doc.data(),
                'nickname': (doc.data())['nickname'] ?? 'Sconosciuto'
              })
          .toList();
    });
  }

  // Carica i turni per un giorno specifico dalla collezione "turni"
  Future<void> _loadTurniForDay(DateTime day) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('turni')
        .where('calendarName', isEqualTo: widget.calendarName)
        .where('data',
            isEqualTo: DateTime(day.year, day.month, day.day)
                .toIso8601String()
                .split('T')[0])
        .get();

    setState(() {
      _turniForDay = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'data': doc.data(),
              })
          .toList();
    });
  }

  void _addTurns() {
    final selectedDate = _selectedDay ?? _focusedDay;
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        duration: Duration(milliseconds: 600),
        child:
            AddTurnsScreen(date: selectedDate, calendarId: widget.calendarName),
      ),
    ).then((_) async {
      // Quando si torna alla schermata, ricarica eventi e turni
      _loadEventsForDay(selectedDate);
      _loadTurniForDay(selectedDate);
      _loadEventsForCalendar();
      _loadTurniForCalendar();
    });
  }

  // Funzione per aggiungere un evento (esistente)
  Future<void> _addEvent() async {
    if (_eventController.text.isNotEmpty) {
      final event = _eventController.text;
      final selectedDate = _selectedDay ?? _focusedDay;

      await FirebaseFirestore.instance.collection('events').add({
        'calendarName': widget.calendarName,
        'date': selectedDate.toIso8601String().split('T')[0],
        'event': event,
        'nickname': widget.nickname,
      });

      _eventController.clear();
      Navigator.pop(context);

      // Ricarica gli eventi
      _loadEventsForDay(selectedDate);
      _loadTurniForDay(selectedDate);
      _loadEventsForCalendar();
      _loadTurniForCalendar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evento aggiunto con successo!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F1F1F),
        title: Text(
          widget.calendarName,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.today, color: Colors.white),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = _focusedDay;
              });
              _loadEventsForDay(_focusedDay);
              _loadTurniForDay(_focusedDay);
              _loadEventsForCalendar();
              _loadTurniForCalendar();
            },
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: _openShoppingList,
          ),
          IconButton(
            icon: Icon(Icons.euro, color: Colors.white),
            onPressed: _openSplitwise,
          ),
          IconButton(
            icon: Icon(Icons.gavel_sharp, color: Colors.white),
            onPressed: _openMulte,
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Calendario con marker personalizzati
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _loadEventsForDay(selectedDay);
                    _loadTurniForDay(selectedDay);
                    //_loadEventsForCalendar();
                    //_loadTurniForCalendar();
                  },
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    isTodayHighlighted: true,
                    selectedDecoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.tealAccent,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(color: Colors.redAccent),
                    defaultTextStyle: TextStyle(color: Colors.white),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon:
                        Icon(Icons.chevron_left, color: Colors.white),
                    rightChevronIcon:
                        Icon(Icons.chevron_right, color: Colors.white),
                  ),
                  // Combiniamo i marker (eventi e turni)
                  eventLoader: (day) {
                    final normalizedDay =
                        DateTime(day.year, day.month, day.day);
                    return _eventMarkers[normalizedDay] ?? [];
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, markers) {
                      if (markers.isEmpty) return SizedBox();

                      // Creiamo una lista di widget per ciascun marker
                      List<Widget> markerWidgets =
                          markers.map<Widget>((marker) {
                        Color markerColor;
                        if (marker is Map &&
                            marker.containsKey('type') &&
                            marker['type'] == 'turno') {
                          // Per il turno, usa il colore salvato (convertendo la stringa esadecimale)
                          String hex = marker['colore'];
                          markerColor = Color(int.parse('0xff$hex'));
                        } else {
                          // Per gli eventi, usa un colore di default
                          markerColor = Colors.deepOrange;
                        }
                        return Container(
                          width: 7,
                          height: 7,
                          margin: EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList();

                      // Posiziona i marker in una Row in basso
                      return Positioned(
                        bottom: 4,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: markerWidgets,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Divider(color: Colors.grey),
              // Sezione per gli eventi (senza checkbox)
              _events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Nessun evento per questo giorno.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.only(bottom: 30),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return Card(
                          color: Color(0xFF1F1F1F),
                          margin: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: ListTile(
                            title: Text(
                              event['data']['event'],
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'aggiunto da: ${event['nickname']}',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('events')
                                    .doc(event['id'])
                                    .delete();

                                setState(() {
                                  _events.removeAt(index);
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Evento eliminato con successo!')),
                                );

                                _loadEventsForDay(_selectedDay!);
                                _loadTurniForCalendar();
                                _loadEventsForCalendar();
                              },
                            ),
                          ),
                        );
                      },
                    ),
              // Sezione per i turni con checkbox
              _turniForDay.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Nessun turno per questo giorno.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Turni',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: BouncingScrollPhysics(),
                          itemCount: _turniForDay.length,
                          itemBuilder: (context, index) {
                            final turno = _turniForDay[index];
                            // Estrai il colore e la proprietà "check"
                            String hexColor =
                                turno['data']['colore'] ?? 'ffffff';
                            bool checkValue = turno['data']['check'] ?? false;
                            // Converte la stringa in Color (aggiungendo "0xff")
                            Color turnoColor =
                                Color(int.parse('0xff$hexColor'));

                            return Dismissible(
                              key: Key(turno['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.symmetric(horizontal: 20.0),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) async {
                                // Rimuovi il documento dalla collezione 'turni' su Firestore
                                await FirebaseFirestore.instance
                                    .collection('turni')
                                    .doc(turno['id'])
                                    .delete();

                                // Rimuovi il marker corrispondente dalla mappa
                                final turnoDate =
                                    DateTime.parse(turno['data']['data']);
                                final normalizedDate = DateTime(turnoDate.year,
                                    turnoDate.month, turnoDate.day);
                                _eventMarkers[normalizedDate]?.removeWhere(
                                    (marker) =>
                                        marker is Map &&
                                        marker['type'] == 'turno' &&
                                        marker['colore'] ==
                                            turno['data']['colore']);

                                // Se non ci sono più marker per quella data, rimuovi la chiave dalla mappa
                                if (_eventMarkers[normalizedDate]?.isEmpty ??
                                    false) {
                                  _eventMarkers.remove(normalizedDate);
                                }

                                // Aggiorna lo stato locale per riflettere la rimozione
                                setState(() {
                                  _turniForDay.removeAt(index);
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Evento eliminato con successo!')),
                                );

                                _loadEventsForDay(_selectedDay!);
                                _loadTurniForDay(_selectedDay!);
                              },
                              child: Card(
                                color: Color(0xFF1F1F1F),
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 16.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: turnoColor,
                                  ),
                                  title: Text(
                                    '${userIdToNickname[turno['data']['user']]}\n${turno['data']['categoria'] ?? 'Turno'}',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    'Stato: ${checkValue ? 'Completato' : 'Da Completare'}',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                  trailing: Checkbox(
                                    value: checkValue,
                                    onChanged: (bool? newValue) async {
                                      await FirebaseFirestore.instance
                                          .collection('turni')
                                          .doc(turno['id'])
                                          .update({'check': newValue});
                                      setState(() {
                                        turno['data']['check'] = newValue;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 80),
                      ],
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        backgroundColor: Colors.blueAccent,
        icon: Icons.add,
        overlayOpacity: 0.1,
        activeIcon: Icons.close,
        children: [
          SpeedDialChild(
            child: Icon(Icons.star),
            label: 'Evento',
            labelStyle: TextStyle(color: Colors.black),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    backgroundColor: Color(0xFF1F1F1F),
                    title: Text(
                      'Aggiungi evento',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: TextField(
                      controller: _eventController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Descrizione evento',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annulla',
                            style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: _addEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: Text(
                          'Aggiungi',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.local_laundry_service_sharp),
            label: 'Turni',
            labelStyle: TextStyle(color: Colors.black),
            onTap: _addTurns,
          ),
        ],
      ),
    );
  }
}
