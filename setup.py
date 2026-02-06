from picobuild import Extension, cythonize, find_packages, get_cython_build_dir, setup

cythonized_extensions = cythonize(
    [
        Extension(
            "picocrypto.curves.*",
            ["src/picocrypto/curves/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
        Extension(
            "picocrypto.hashes.*",
            ["src/picocrypto/hashes/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
        Extension(
            "picocrypto.serde.*",
            ["src/picocrypto/serde/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            language="c",
        ),
        Extension(
            "picocrypto.signing.*",
            ["src/picocrypto/signing/*.pyx"],
            extra_compile_args=[
                "-O3",
                "-march=native",
                "-Wno-unused-function",
                "-Wno-unused-variable",
            ],
            libraries=["crypto"],
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
        name="picocrypto",
        description="Picocrypto cryptography utilities",
        packages=find_packages(where="src"),
        package_dir={"": "src"},
        package_data={"picocrypto": ["**/*.pxd", "**/*.pxi", "**/*.pyx"]},
        ext_modules=cythonized_extensions,
    )
