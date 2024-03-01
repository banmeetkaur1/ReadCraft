from collections import UserList
from flask import Flask, request, jsonify,session
import psycopg2
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
app.secret_key = 'basfcieifsuq38na'

conn = psycopg2.connect("dbname=readcraft user= postgres password=potato ")
cursor = conn.cursor()

cursor.execute('''
    CREATE TABLE IF NOT EXISTS user_login (
        "User-ID" SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL
    )
''')
conn.commit()

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()

    email = data.get('email')
    password = data.get('password')
    age = data.get('age')
    hashed_password = generate_password_hash(password, method='pbkdf2:sha256')


    # find the maximum User-ID in the users table
    cursor.execute("SELECT MAX(\"User-ID\") FROM users")
    max_user_id = cursor.fetchone()[0]

    # generate new user_id
    user_id = max_user_id + 1
    

    #check if user exists already
    cursor.execute("SELECT * FROM user_login WHERE email = %s", (email,))
    existing_user = cursor.fetchone()

    if existing_user:
        return jsonify({'success': False, 'message': 'User with this email already registered'})

    #insert everything:
    cursor.execute("INSERT INTO user_login(\"User-ID\", email, password) VALUES (%s, %s, %s)", (user_id, email, hashed_password))
    cursor.execute("INSERT INTO users(\"User-ID\", \"Age\") VALUES (%s, %s)", (user_id, age))
    
    conn.commit()
    return jsonify({'success': True, 'message': 'Registration successful', 'user_id': user_id})


@app.route('/api/login', methods = ['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

  
    cursor.execute("SELECT * FROM user_login WHERE email = %s", (email,))
    user = cursor.fetchone()


    #check if user exists
    if not user:
   
        return jsonify({'success': False, 'message': 'No user registered with this email'}), 404


    if check_password_hash(user[2], password):
        session['user_id'] = user[0]
      
        return jsonify({'success': True, 'message': 'Login successful', 'user_id': user[0]})
    else:
      
        return jsonify({'success': False, 'message': 'Invalid credentials'}), 401


@app.route('/api/save_rating', methods=['POST'])
def save_rating():
    data = request.get_json()

    user_id = data.get('userId')
    isbn = data.get('isbn')
    book_rating = data.get('book_rating')

    # Check if the user has already rated the book
    cursor.execute("""
        SELECT * FROM ratings
        WHERE "User-ID" = %s AND "ISBN" = %s
    """, (user_id, isbn))
    existing_rating = cursor.fetchone()

    if existing_rating:
        # Update the existing rating
        cursor.execute("""
            UPDATE ratings
            SET "Book-Rating" = %s
            WHERE "User-ID" = %s AND "ISBN" = %s
        """, (book_rating, user_id, isbn))
    else:
        # Insert a new rating
        cursor.execute("""
            INSERT INTO ratings("User-ID", "ISBN", "Book-Rating")
            VALUES (%s, %s, %s)
        """, (user_id, isbn, book_rating))

    conn.commit()

    return jsonify({'success': True, 'message': 'Rating saved successfully'})

    

if __name__ == '__main__':
    app.run(port = 5000, debug=True)