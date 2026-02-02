PYTHON := python
PIP := pip
PACKAGES := picolib
TEST_DIR := tests
.DEFAULT_GOAL := help

.PHONY: build clean install test


help:
	@echo "Welcome to the Picolib Makefile"
	@echo "Available commands:"
	@echo "  help       - Show this help message"
	@echo "  build      - Build the package"
	@echo "  clean      - Clean the build and dist directories"
	@echo "  install    - Install the package"
	@echo "  test       - Run pytest on $(TEST_DIR)/"
		
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