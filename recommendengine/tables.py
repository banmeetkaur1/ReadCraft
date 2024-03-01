import pandas as pd
from sqlalchemy import create_engine


db_params = {
    'dbname': 'readcraft',
    'user': 'postgres',
    'password': 'potato',
}

def create_table_from_csv(engine, table_name, csv_path):
    df = pd.read_csv(csv_path, encoding='utf-8')
    df.to_sql(table_name, engine, index=False, if_exists='replace')


engine = create_engine(f'postgresql://{db_params["user"]}:{db_params["password"]}@localhost/{db_params["dbname"]}')


create_table_from_csv(engine, 'books', 'books.csv')
create_table_from_csv(engine, 'users', 'users.csv')
create_table_from_csv(engine, 'ratings', 'ratings.csv')

print("Data imported successfully.")
