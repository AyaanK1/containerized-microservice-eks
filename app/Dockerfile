FROM python:3.12-slim

WORKDIR /app

COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ .

EXPOSE 8080

# Run under gunicorn rather than the Flask dev server for production-realistic behavior
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]
