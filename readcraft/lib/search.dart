import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'bookclub.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  List<dynamic> books = [];
  bool showCancel = false;

  void _performSearch(String query) async {
    final response =
        await http.get(Uri.parse('http://127.0.0.1:5001/search?query=$query'));

    if (response.statusCode == 200) {
      List<Map<String, dynamic>> results =
          List<Map<String, dynamic>>.from(json.decode(response.body));
      setState(() {
        searchResults = results;
        showCancel = true;
      });
    } else {
      throw Exception('Failed to perform search');
    }
  }

  void _cancelSearch() {
    _searchController.clear();
    setState(() {
      searchResults.clear();
      showCancel = false;
    });
  }

  Future<void> _getBookDetails(String bookTitle, String isbn) async {
    final response = await http.get(Uri.parse(
        'http://127.0.0.1:5001/book_details?title=$bookTitle&isbn=$isbn'));

    if (response.statusCode == 200) {
      dynamic decodedResponse = json.decode(response.body);

      if (decodedResponse is List) {
        if (decodedResponse.isNotEmpty) {
          _showBookDetailsDialog(
              [Map<String, dynamic>.from(decodedResponse.first)]);
        } else {
          //list is empty
        }
      } else if (decodedResponse is Map) {
        _showBookDetailsDialog([Map<String, dynamic>.from(decodedResponse)]);
      } else {
        throw Exception('Invalid response type');
      }
    } else {
      throw Exception('Failed to load book details');
    }
  }

  Future<void> _joinBookClub(String bookTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      final userKey = 'joined_book_clubs_$userId';
      final List<String> joinedBookClubs = prefs.getStringList(userKey) ?? [];
      joinedBookClubs.add(bookTitle);
      prefs.setStringList(userKey, joinedBookClubs);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage()),
      );
    } else {
      print('User ID not found');
    }
  }

  _showBookDetailsDialog(List<Map<String, dynamic>> bookDetailsList) async {
    double userRating = 0;
    for (var bookDetails in bookDetailsList) {
      String isbn = bookDetails['ISBN'];
      String imageUrl = await _getImageUrl(isbn);
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                  'Book Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                content: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: ListView(
                    children: bookDetailsList.map((bookDetails) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Title: ${bookDetails['Book-Title']}',
                            style: TextStyle(fontSize: 20),
                          ),
                          Text('Author: ${bookDetails['Book-Author']}'),
                          Text(
                            'Year of Publication: ${bookDetails['Year-Of-Publication']}',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'ISBN: ${bookDetails['ISBN']}',
                            style: TextStyle(fontSize: 16),
                          ),
                          Divider(),
                          Image.network(
                            imageUrl,
                            height: 350,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Image.network(
                                  'https://via.placeholder.com/600x800.png?text=Placeholder+Image');
                            },
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              _joinBookClub(bookDetails['Book-Title']);
                              Navigator.of(context).pop;
                            },
                            child: Text('Join Book Club'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _addToUserList(bookDetails['Book-Title']);
                              Navigator.of(context).pop();
                            },
                            child: Text('Add to List'),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Average-Rating: ${bookDetails['Average-Rating']}',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Your Rating: $userRating',
                            style: TextStyle(fontSize: 16),
                          ),
                          Slider(
                            value: userRating,
                            onChanged: (value) {
                              setState(() {
                                userRating = value;
                              });
                            },
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: userRating.toString(),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              _saveUserRating(bookDetails['ISBN'], userRating);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(),
                            child: Text('Save Rating'),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Close',
                    ),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _addToUserList(String bookTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      final List<String> userLists =
          prefs.getStringList('user_lists_$userId') ?? [];
      if (userLists.isNotEmpty) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Choose a List'),
              content: Container(
                width: 300,
                height: 500,
                child: Column(
                  children: userLists.map((list) {
                    return ListTile(
                      title: Text(list),
                      onTap: () {
                        _addBookToList(userId, list, bookTitle);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      } else {
        _showCreateListDialog();
      }
    } else {
      print('user ID not found');
    }
  }

  void _addBookToList(int userId, String listName, String bookTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final listKey = 'list_books_$userId$listName';
    List<String> booksInList = prefs.getStringList(listKey) ?? [];
    booksInList.add(bookTitle);
    prefs.setStringList(listKey, booksInList);
    print('Book added to list: $listName');
  }

  void _showCreateListDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create a List'),
          content: Text('Please first create a list to add books.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _getImageUrl(String isbn) async {
    try {
      final image_url = await http.get(
        Uri.parse('http://127.0.0.1:5001/get_book_image?isbn=$isbn'),
      );
      if (image_url.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(image_url.body);
        return data['image_url'];
      } else if (image_url.statusCode == 404) {
        print('Image not found for given ISBN, using placeholder');
        return 'https://via.placeholder.com/600x800.png?text=Placeholder+Image';
      } else {
        throw Exception('Failed to get image URL: ${image_url.statusCode}');
      }
    } catch (e) {
      print('Error getting image URL: $e');
      return 'https://via.placeholder.com/600x800.png?text=Placeholder+Image';
    }
  }

  Future<void> _saveUserRating(String isbn, double userRating) async {
    final userId = await _getUserId();
    if (userId != null) {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/save_rating'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'isbn': isbn,
          'book_rating': userRating,
        }),
      );

      if (response.statusCode == 200) {
        _showRatingSavedMessage();
      } else {
        print('Failed to save rating: ${response.body}');
      }
    } else {
      print('Failed to retrieve user ID');
    }
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    print('User ID: $userId');

    return userId;
  }

  void _showRatingSavedMessage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rating Saved'),
          content: Text('Your rating has been saved successfully!'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(
                        Icons.search,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        showCancel = value.isNotEmpty;
                      });
                      _performSearch(value);
                    },
                    onSubmitted: (value) {
                      _performSearch(value);
                    },
                  ),
                ),
                if (showCancel)
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: _cancelSearch,
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    String bookTitle = searchResults[index]['Book-Title'];
                    String isbn = searchResults[index]['ISBN'];
                    _getBookDetails(bookTitle, isbn);
                  },
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 100,
                          height: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Center(
                            child: Text(
                              searchResults[index]['Book-Title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
