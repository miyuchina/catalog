.PHONY: db load elm

PYTHON=python3
FLASK_DIR=catalog
ELM_DIR=src
LIB_DIR=lib
DB_NAME=app.sqlite
LOADER=$(LIB_DIR)/load.py
SCHEMA=$(LIB_DIR)/schema.sql

db:
	sqlite3 $(DB_NAME) < $(SCHEMA)

load: db
	$(PYTHON) $(LOADER)

elm:
	elm make $(ELM_DIR)/*.elm --output=$(FLASK_DIR)/static/catalog.js
