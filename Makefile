PYTHON := python
PIP := pip
UV := uv
TEST_DIR := tests
.DEFAULT_GOAL := help

.PHONY: build clean install test sync install-uv lock dist upload

help:
	@echo "picocrypto Makefile"
	@echo "  build      - Build Cython extensions in place"
	@echo "  clean      - Clean build and dist"
	@echo "  install    - Install package editable (pip)"
	@echo "  test       - Run pytest"
	@echo "  sync       - uv: create venv and install deps from lockfile"
	@echo "  install-uv - uv: sync, build, then editable install (no-build-isolation)"
	@echo "  lock       - uv: update uv.lock from pyproject.toml"
	@echo "  dist       - sync + build sdist + wheel for PyPI"
	@echo "  upload     - upload dist/* to PyPI (requires: make dist, twine/uv, credentials)"

dist: sync
	@$(UV) run python -m build

upload:
	@$(UV) run twine upload dist/*

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

sync:
	@$(UV) sync --extra dev

install-uv: sync
	@$(MAKE) build
	@$(UV) pip install -e . --no-build-isolation

lock:
	@$(UV) lock
