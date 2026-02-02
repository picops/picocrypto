from Cython.Build import cythonize
from picobuild import get_cython_build_dir
from setuptools import Extension, find_packages, setup

cythonized_extensions = cythonize(
    [
        Extension(
            "cycrypto.curves.*",
            ["src/cycrypto/curves/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
    ],
    compiler_directives={
        "language_level": 3,
        "boundscheck": False,
        "wraparound": False,
        "cdivision": True,
        "infer_types": True,
        "nonecheck": False,
        "initializedcheck": False,
    },
    build_dir=get_cython_build_dir(),
)

if __name__ == "__main__":
    setup(
        name="cycrypto",
        description="Cycrypto cryptography utilities",
        packages=find_packages(where="src"),
        package_dir={"": "src"},
        package_data={"cycrypto": ["**/*.pxd", "**/*.pxi"]},
        ext_modules=cythonized_extensions,
    )
