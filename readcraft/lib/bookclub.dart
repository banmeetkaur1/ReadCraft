import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<String> bookClubs = [];

  @override
  void initState() {
    super.initState();
    _loadBookClubs();
  }

  Future<void> _loadBookClubs() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      final userKey = 'joined_book_clubs_$userId';
      final List<String>? storedBookClubs = prefs.getStringList(userKey);

      if (storedBookClubs != null) {
        setState(() {
          bookClubs = storedBookClubs;
        });
      }
    } else {
      print('User Id not found//bookclub.dart');
    }
  }

  Future<void> _saveBookClubs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('joined_book_clubs', bookClubs);
  }

  void _joinBookClub(String bookClub) {
    setState(() {
      bookClubs.add(bookClub);
    });
    _saveBookClubs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Clubs'),
      ),
      body: Container(
        alignment: Alignment.center,
        child: bookClubs.isEmpty
            ? Center(
                child: Text('No book clubs joined yet.'),
              )
            : ListView.builder(
                itemCount: bookClubs.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      bookClubs[index],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            bookClub: bookClubs[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String bookClub;

  ChatScreen({required this.bookClub});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Club: ${widget.bookClub}'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        //borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    String message = _messageController.text;
                    if (message.isNotEmpty) {
                      setState(() {
                        _messages.add(message);
                        _messageController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.all(8),
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(color: Colors.black),
        ),
      ),
    );
  }
}
