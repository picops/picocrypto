UV := uv
PYTHON := python
TEST_DIR := tests
.DEFAULT_GOAL := help

.PHONY: help build clean install test sync install-uv lock dist upload check docs

help:
	@echo "picocrypto Makefile"
	@echo "  build      - Build Cython extensions in place"
	@echo "  clean      - Clean build and dist"
	@echo "  install    - Install package editable (no-build-isolation)"
	@echo "  test       - Run unit tests"
	@echo "  check      - isort, black, flake8, mypy"
	@echo "  sync       - uv: create venv and install deps (incl. dev)"
	@echo "  install-uv - uv: sync, build, then editable install"
	@echo "  lock       - uv: update uv.lock from pyproject.toml"
	@echo "  dist       - sync + build sdist and wheel into dist/"
	@echo "  upload     - upload dist/* to PyPI (requires: make dist, twine, credentials)"
	@echo "  docs       - Build Sphinx HTML docs in docs/_build/html"

dist: sync
	@$(UV) run $(PYTHON) -m build --outdir dist

upload:
	@$(UV) run twine upload dist/*

install: sync
	@$(UV) pip install -e . --no-build-isolation

build:
	@$(UV) run $(PYTHON) setup.py build_ext --inplace

clean:
	@rm -rf build/
	@rm -rf dist/
	@rm -rf *.egg-info/
	@find . -type f -name "*.so" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

test:
	@$(UV) run $(PYTHON) -m pytest $(TEST_DIR)/ -v

check:
	@$(UV) run $(PYTHON) -m isort src --profile black
	@$(UV) run $(PYTHON) -m black src
	@$(UV) run $(PYTHON) -m flake8 src
	@$(UV) run $(PYTHON) -m black --check src
	@$(UV) run $(PYTHON) -m mypy src

sync:
	@$(UV) sync --extra dev

install-uv: sync
	@$(MAKE) build
	@$(UV) pip install -e . --no-build-isolation

lock:
	@$(UV) lock

docs:
	@mkdir -p docs
	@if [ ! -f docs/conf.py ]; then \
		echo 'project = "picocrypto"'; \
		echo 'copyright = "picocrypto authors"'; \
		echo 'release = "0.0.0"'; \
		echo 'extensions = []'; \
		echo 'templates_path = ["_templates"]'; \
		echo 'exclude_patterns = []'; \
		echo 'html_theme = "alabaster"'; \
		echo 'html_static_path = ["_static"]'; \
		echo 'root_doc = "index"' > docs/conf.py; \
	fi
	@if [ ! -f docs/index.rst ]; then \
		echo 'picocrypto'; \
		echo '=========='; \
		echo ''; \
		echo 'Picocrypto cryptography utilities.'; \
		echo ''; \
		echo '.. toctree::'; \
		echo '   :maxdepth: 2' > docs/index.rst; \
	fi
	@$(UV) sync --extra dev
	@$(UV) run $(PYTHON) -m sphinx -b html docs docs/_build/html
