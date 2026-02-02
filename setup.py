from picobuild import find_packages, setup

if __name__ == "__main__":
    setup(
        name="picocrypto",
        version="0.1.0",
        description="Picocrypto cryptography utilities",
        packages=find_packages(where="src"),
        package_dir={"": "src"},
        package_data={"picocrypto": ["**/*.pxd", "**/*.pxi"]},
        ext_modules=[],
    )
