from tkinter import NE
import pandas as pd
from scipy.sparse import csr_matrix
from sklearn.neighbors import NearestNeighbors
import psycopg2


def generate_recommendations(user_id):

    conn = psycopg2.connect("dbname=readcraft user= postgres password=potato ")
    cursor = conn.cursor()

    users_query = "SELECT * FROM users;"
    users = pd.read_sql(users_query, conn)
    ratings_query = "SELECT * FROM ratings;"
    ratings = pd.read_sql(ratings_query, conn)
    books_query = "SELECT \"ISBN\", \"Book-Title\", \"Book-Author\" FROM books;"
    books = pd.read_sql(books_query, conn)

    conn.close()


    df = pd.merge(ratings, books, on = 'ISBN')
    df = pd.merge(df, users, on = 'User-ID')

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

    return recommended_books
# Print the recommended books
#print(f"Recommended books for user with ID {user_id_test}:")
#for book_isbn in recommended_books:
#    book_title = df[df['ISBN'] == book_isbn]['Book-Title'].values
#    if len(book_title) > 0:
#        print(book_title[0])