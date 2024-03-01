import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ListsPage extends StatefulWidget {
  @override
  _ListsPageState createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  late SharedPreferences prefs;
  List<String> lists = [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      final userKey = 'user_lists_$userId';
      setState(() {
        lists = prefs.getStringList(userKey) ?? [];
      });
    } else {
      print('user ID not found // lists.dart');
    }
  }

  void _saveLists() {
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      final userKey = 'user_lists_$userId';
      prefs.setStringList(userKey, lists);
    } else {
      print('User ID not found // _savelists');
    }
  }

  void createNewList(String newList) {
    setState(() {
      lists.add(newList);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.separated(
        itemCount: lists.length,
        separatorBuilder: (context, index) => Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              lists[index],
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: Icon(Icons.list),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListDetailsPage(listName: lists[index]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _navigateToCreateListScreen();
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _navigateToCreateListScreen() async {
    final newList = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateListPage(),
      ),
    );

    if (newList != null) {
      createNewList(newList);

      _saveLists();
    }
  }
}

class CreateListPage extends StatelessWidget {
  final TextEditingController _listNameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create a New List"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _listNameController,
              decoration: InputDecoration(labelText: "List Name"),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(),
              onPressed: () {
                String newList = _listNameController.text;
                Navigator.pop(context, newList);
              },
              child: Text("Create List"),
            ),
          ],
        ),
      ),
    );
  }
}

class ListDetailsPage extends StatefulWidget {
  final String listName;
  const ListDetailsPage({required this.listName});
  @override
  _ListDetailsPageState createState() => _ListDetailsPageState();
}

class _ListDetailsPageState extends State<ListDetailsPage> {
  late SharedPreferences prefs;
  List<String> booksInList = [];
  @override
  void initState() {
    super.initState();
    _loadBooksInList();
  }

  Future<void> _loadBooksInList() async {
    prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      final listKey = 'list_books_$userId${widget.listName}';
      setState(() {
        booksInList = prefs.getStringList(listKey) ?? [];
      });
    } else {
      print('user ID not found // ListDetailsPage');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
      ),
      body: ListView.builder(
        itemCount: booksInList.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(booksInList[index]),
          );
        },
      ),
    );
  }
}
