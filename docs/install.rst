Install
=======

From PyPI:

.. code-block:: bash

   pip install picocrypto

With uv:

.. code-block:: bash

   uv add picocrypto

Requirements: Python >= 3.13.

Build from source (Cython extensions):

.. code-block:: bash

   make sync        # uv sync --extra dev
   make install-uv  # sync + build + editable install
