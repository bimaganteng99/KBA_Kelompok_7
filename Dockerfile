FROM python:3.10-slim

# Install dependencies sistem untuk dbt dan postgres
RUN apt-get update && apt-get install -y \
    git \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements dan install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# dbt butuh profil, pastikan folder .dbt ada atau diatur lewat env
ENV DBT_PROFILES_DIR=/app

CMD ["python", "main.py"]