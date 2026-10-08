# backend/app/database.py
import psycopg
from psycopg_pool import ConnectionPool
from app.config import settings

pool = ConnectionPool(settings.DATABASE_URL, min_size=1, max_size=10)

def get_connection():
    return pool.getconn()

def release_connection(conn):
    pool.putconn(conn)
