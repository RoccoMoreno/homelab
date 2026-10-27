from flask import Flask
from datetime import datetime
import psycopg2 
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>Hello from Flask in a container</h1>"
@app.route("/time")
def time():
    return f"<h1> The time is {datetime.now()}</h1>"
@app.route("/db")
def db():
    conn = psycopg2.connect(
        host="db",
	dbname="postgres",
	user="postgres",
	password=os.environ["POSTGRES_PASSWORD"]
    )
    cur = conn.cursor()
    cur.execute("SELECT version();")
    result = cur.fetchone()
    cur.close()
    conn.close()
    return f"<h1>Connected to Postgres</h1><p>{result[0]}</p>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

