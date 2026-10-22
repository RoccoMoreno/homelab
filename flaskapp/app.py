from flask import Flask
from datetime import datetime

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>Hello from Flask in a container</h1>"
@app.route("/time")
def time():
    return f"<h1> The time is {datetime.now()}</h1>"
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

