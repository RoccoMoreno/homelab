FROM python:3.12-slim

WORKDIR /app

xCOPY app.py .

RUN pip install flask psycopg2-binary
CMD ["python", "app.py"]
