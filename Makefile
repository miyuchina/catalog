.PHONY: db load elm release

PYTHON=python3
FLASK_DIR=catalog
ELM_DIR=src
LIB_DIR=lib
LOADER=$(LIB_DIR)/load.py
OUTPUT=$(FLASK_DIR)/static/catalog.js

load:
	$(PYTHON) $(LOADER)

elm:
	elm make $(ELM_DIR)/*.elm --output=$(OUTPUT)

release:
	elm make $(ELM_DIR)/*.elm --output=$(OUTPUT) --optimize
	uglifyjs $(OUTPUT) --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output=$(OUTPUT)
