from flask import Flask, jsonify,request
from bs4 import BeautifulSoup
import requests
from flask_cors import CORS
import pandas as pd
from tkinter import NE
import pandas as pd
from scipy.sparse import csr_matrix
from sklearn.neighbors import NearestNeighbors
import psycopg2

app = Flask(__name__)
CORS(app)

#static data
books_data = pd.read_csv('books_data.csv')
ratings_data = pd.read_csv('ratings.csv')
books = books_data.to_dict(orient = 'records')
ratings = ratings_data.to_dict(orient= 'records')

#dyanmic data
con = psycopg2.connect("dbname=readcraft user= postgres password=potato ")
cur = con.cursor()



#engine
def generate_recommendations(user_id):

    conn = psycopg2.connect("dbname=readcraft user= postgres password=potato ")
    cursor = conn.cursor()
    users_query = "SELECT * FROM users;"
    engine_users = pd.read_sql(users_query, conn)
    ratings_query = "SELECT * FROM ratings;"
    engine_ratings = pd.read_sql(ratings_query, conn)
    books_query = "SELECT \"ISBN\", \"Book-Title\", \"Book-Author\" FROM books;"
    engine_books = pd.read_sql(books_query, conn)
    conn.close()
    df = pd.merge(engine_ratings, engine_books, on = 'ISBN')
    df = pd.merge(df, engine_users, on = 'User-ID')

    #to solve the large matrix issue // filter out ratings below 1
    df = df[df['Book-Rating'] > 0]
    # calculate book popularity
    book_popularity = df.groupby('ISBN')['Book-Rating'].count().reset_index()
    book_popularity.rename(columns={'Book-Rating': 'RatingCount'}, inplace=True)
    #set threshold 
    popularity_threshold = 5
    popular_books = book_popularity[book_popularity['RatingCount'] >= popularity_threshold]
    # filter df to include popular books
    df = df[df['ISBN'].isin(popular_books['ISBN'])]
    
    user_item_matrix = df.pivot_table(index='User-ID', columns='ISBN', values='Book-Rating', fill_value=0)
    user_item_matrix_csr = csr_matrix(user_item_matrix.values)
    #knn model
    model_knn = NearestNeighbors(metric='cosine', algorithm='brute')
    model_knn.fit(user_item_matrix_csr)
   
    k = 50
    desired_recommendations = 5
    user_age = df[df['User-ID'] == user_id]['Age'].values[0]
    age_similarity_threshold = 10

    # Get distances and indices of similar users
    distances, indices = model_knn.kneighbors(user_item_matrix.loc[user_id].values.reshape(1, -1), n_neighbors=k)
    recommended_books = set()
    for i in range(1, k):
        index = indices.flatten()[i]
        # get the age of the similar user
        similar_user_id = user_item_matrix.index[index]
        similar_user_age = df[df['User-ID'] == similar_user_id]['Age'].values[0]
        # get  ISBNs of books that the similar user has liked
        similar_user_ratings = user_item_matrix.iloc[index]
        similar_user_liked_books = similar_user_ratings[similar_user_ratings > 0].index
    
        # filter out books that the target user has already rated
        new_books = set(similar_user_liked_books) - set(user_item_matrix.loc[user_id][user_item_matrix.loc[user_id] > 0].index)
        # add  new books  to recommendations
        recommended_books.update(new_books)

        # check if there are enough recommendations, if not, consider age as an extra boost
        if len(recommended_books) < desired_recommendations:
            # check if age is similar 
            if abs(user_age - similar_user_age) <= age_similarity_threshold:
                recommended_books.update(new_books)
        # check if you have enough recommendations
        if len(recommended_books) >= desired_recommendations:
            break
    recommended_books = books_data[books_data['ISBN'].isin(recommended_books)]['Book-Title'].tolist()
    return recommended_books


#dynamic data: dataabse used in engine
@app.route('/recommendations', methods = ['GET'])
def get_recommendations():
    user_id = request.args.get('user_id', None)
    if user_id is None:
        return jsonify({'error': 'User ID is required'}), 400

    recommendations = generate_recommendations(int(user_id))

    return jsonify(recommendations)

#books data doesnt change: use csv files
@app.route('/books', methods=['GET'])
def get_books():
    return jsonify(books)


#best rated books can change regularly: use database
@app.route('/best_rated_books', methods=['GET'])
def best_rated_books():

    #get isbns of best rated books directly from database
    cur.execute("SELECT \"ISBN\" FROM ratings WHERE \"Book-Rating\" = 10")
    best_rated_isbns = [result["ISBN"] for result in cur.fetchall()]

    #get book details of best books
    cur.execute("SELECT * FROM books WHERE \"ISBN\" IN %s", (tuple(best_rated_isbns),))

    best_rated_books_data = cur.fetchall()

    best_rated_books = [dict(book) for book in best_rated_books_data]
    
    return jsonify(best_rated_books)

#book details can change reuglary: use database
@app.route('/book_details', methods = ['GET'])
def get_book_details():
    title = request.args.get('title', '')
    isbn = request.args.get('isbn', '')

    cur.execute('''
    SELECT "ISBN", "Book-Title", "Book-Author", "Year-Of-Publication"
    FROM books
    WHERE "Book-Title" = %s AND "ISBN" = %s
    ''', (title, isbn))
    book_details_data = cur.fetchall()

    book_details = dict(zip(['ISBN', 'Book-Title', 'Book-Author', 'Year-Of-Publication'], book_details_data[0]))

    #fetch ratings
    cur.execute('''
    SELECT "Book-Rating"
    FROM ratings
    WHERE "ISBN" = %s
    ''', (isbn,))
    ratings_query = cur.fetchall()

    if ratings_query:
        ratings = [rating[0] for rating in ratings_query]
        average_rating = round(sum(ratings) / len(ratings), 2)
    else:
        average_rating = None

    book_details['Average-Rating'] = average_rating
    #print(book_details)
    return jsonify(book_details)



#search results are also static: use csv
@app.route('/search', methods = ['GET'])
def search_books():
    query = request.args.get('query', '')
    search_results = books_data[books_data['Book-Title'].str.lower().str.contains(query.lower())]
    search_results = search_results.to_dict(orient = 'records')

    return jsonify(search_results)



#image data
@app.route('/get_book_image', methods = ['GET'])
def get_book_image():
    isbn = request.args.get('isbn')
    #use abebooks search results to get urls

    search_url = f'https://www.abebooks.com/servlet/SearchResults?isbn={isbn}'
    response = requests.get(search_url)
    
    if response.status_code == 200:
        #print('this is the response.text:', response.text)
        soup = BeautifulSoup(response.text, 'html.parser')

        #extract first result's image url
        result = soup.find('div', class_ = 'srp-image-holder')
        
        image_url = result.find('img', class_ = 'srp-item-image')['src'] if result and result.find('img', class_ = 'srp-item-image') else None
    
    

        if image_url:
           
            return jsonify({'image_url': image_url})
        else:
            print('no image url found')
            return jsonify({'error': 'Image not found for given ISBN', 'status_code': 404})
    else:
        return jsonify({'error': 'Failed to fetch search results', 'status_code': response.status_code})

   


if __name__ == '__main__':
    app.run(port = 5001, debug=True)