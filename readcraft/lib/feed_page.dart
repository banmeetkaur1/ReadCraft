import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'bookclub.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({Key? key}) : super(key: key);
  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<dynamic> books = [];
  @override
  void initState() {
    super.initState();
    _getBooks();
  }

  Future<void> _getBooks() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:5001/books'));
    if (response.statusCode == 200) {
      setState(() {
        books = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load books');
    }
  }

  Future<void> _getBookDetails(String bookTitle, String isbn) async {
    final response = await http.get(Uri.parse(
        'http://127.0.0.1:5001/book_details?title=$bookTitle&isbn=$isbn'));

    if (response.statusCode == 200) {
      dynamic decodedResponse = json.decode(response.body);

      if (decodedResponse is List) {
        if (decodedResponse.isNotEmpty) {
          _showBookDetailsDialog(
            [Map<String, dynamic>.from(decodedResponse.first)],
            bookTitle: bookTitle,
          );
        } else {
          //list is empty...
        }
      } else if (decodedResponse is Map) {
        _showBookDetailsDialog([Map<String, dynamic>.from(decodedResponse)],
            bookTitle: bookTitle);
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

  _showBookDetailsDialog(List<Map<String, dynamic>> bookDetailsList,
      {required String bookTitle}) async {
    double userRating = 0; // track the user's rating
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

    // retrieve existing book list for the selected list name
    List<String> booksInList = prefs.getStringList(listKey) ?? [];
    // add the new book title to the list
    booksInList.add(bookTitle);
    // save the updated list of books for the selected list name
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
        //other status coded
        throw Exception('Failed to get image URL: ${image_url.statusCode}');
      }
    } catch (e) {
      // handle other exceptions
      print('Error getting image URL: $e');
      return 'https://via.placeholder.com/600x800.png?text=Placeholder+Image';
    }
  }

  // function to save user's rating to the backend
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

  // function to get the user ID
  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    print('user ID: $userId');
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
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        children: List.generate(
          books.length,
          (index) {
            return GestureDetector(
              onTap: () {
                _getBookDetails(
                    books[index]['Book-Title'], books[index]['ISBN']);
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                color: Colors.white,
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
                          books[index]['Book-Title'],
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
    );
  }
}

class RecommendationsPage extends StatefulWidget {
  @override
  _RecommendationsPageState createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  List<String> recommendedBooks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _getRecommendedBooks();
  }

  Future<void> _getRecommendedBooks() async {
    final userId = await _getUserId();

    if (userId != null) {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5001/recommendations?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          recommendedBooks = List<String>.from(json.decode(response.body));
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          print('Failed to load recommended books');
        });
      }
    } else {
      print('Failed to retrieve user ID');
    }
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    print('user ID: $userId');

    return userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recommended Books'),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : recommendedBooks.isEmpty
              ? Center(
                  child: Text('Please rate some books first!'),
                )
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: recommendedBooks.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {},
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        color: Colors.white,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 100,
                              height: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Center(
                                child: Text(
                                  recommendedBooks[index],
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
    );
  }
}
