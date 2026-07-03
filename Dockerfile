FROM python:3.12-slim

WORKDIR /docs

COPY requirements-docs.txt .
RUN pip install --no-cache-dir -r requirements-docs.txt

COPY . .

EXPOSE 8000

CMD ["mkdocs", "serve", "--dev-addr=0.0.0.0:8000"]
