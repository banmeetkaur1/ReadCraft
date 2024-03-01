
from flask import Blueprint, Flask, request, jsonify
from flask_cors import CORS
import psycopg2



app = Flask(__name__)
CORS(app)


conn = psycopg2.connect("dbname=readcraft user= postgres password=potato ")
cursor = conn.cursor()

cursor.execute('''
    CREATE TABLE IF NOT EXISTS lists (
        "User-ID" INTEGER REFERENCES user_login("User-ID"),
        "List-Name" VARCHAR(255) NOT NULL,
        "Book-Titles" TEXT[] NOT NULL,
        PRIMARY KEY ("User-ID", "List-Name")
    )
''')
conn.commit()

@app.route('/lists', methods=['GET'])
def get_lists():
 
    user_id = request.headers.get('User-ID')

    # Retrieve the lists for the given User-ID
    cursor.execute("SELECT * FROM lists WHERE \"User-ID\" = %s", (user_id,))
    user_lists = cursor.fetchall()


    lists_data = [{"List-Name": row[1], "Book-Titles": row[2]} for row in user_lists]

    return jsonify(lists_data)


@app.route('/lists/create', methods=['POST'])
def create_list():
    data = request.get_json()
    user_id = data.get('User-ID')
    list_name = data.get('List-Name')
 

    # Check if the list already exists for the user
    cursor.execute("SELECT * FROM lists WHERE \"User-ID\" = %s AND \"List-Name\" = %s", (user_id, list_name))
    existing_list = cursor.fetchone()

    if existing_list:
        return jsonify({'success': False, 'message': 'List already exists for the user'}), 400

    # Insert the new list
    cursor.execute("INSERT INTO lists(\"User-ID\", \"List-Name\", \"Book-Titles\") VALUES (%s, %s, %s)", (user_id, list_name, []))
    conn.commit()

    return jsonify({'success': True, 'message': 'List created successfully'})

@app.route('/lists/delete', methods=['POST'])
def delete_list():
    data = request.get_json()
    user_id = data.get('User-ID')
    list_name = data.get('List-Name')

    # Delete the list for the user
    cursor.execute("DELETE FROM lists WHERE \"User-ID\" = %s AND \"List-Name\" = %s", (user_id, list_name))
    conn.commit()

    return jsonify({'success': True, 'message': 'List deleted successfully'})


if __name__ == '__main__':
    app.run(port=5002, debug=True)