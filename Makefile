PYTHON := python
PIP := pip
TEST_DIR := tests
.DEFAULT_GOAL := help

.PHONY: build clean install test

help:
	@echo "picocrypto Makefile"
	@echo "  build   - Build Cython extensions in place"
	@echo "  clean   - Clean build and dist"
	@echo "  install - Install package editable"
	@echo "  test    - Run pytest"

install:
	@$(PIP) install -e . --no-build-isolation

build:
	@$(PYTHON) setup.py build_ext --inplace

clean:
	@rm -rf build/
	@rm -rf dist/
	@rm -rf *.egg-info/
	@find . -type f -name "*.so" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +

test:
	@$(PYTHON) -m pytest $(TEST_DIR)/ -v
