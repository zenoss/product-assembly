from __future__ import print_function

import os
import sys
from setuptools import setup, find_packages

_version = os.environ.get("VERSION")
if _version is None:
    print("VERSION environment variable not found", file=sys.stderr)
    sys.exit(1)


setup(
    name="zends.toolbox",
    version=_version,
    description="Tools for MariaDB",
    author="Zenoss, Inc.",
    url="https://www.zenoss.com",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    include_package_data=True,
    package_data={
        "zends.toolbox": ["sql/*.sql"],
    },
    zip_safe=False,
    install_requires=[],
    python_requires=">=2.7,<3",
    entry_points={
        "console_scripts": [
            "zencheckzends=zends.toolbox.zencheckzends:main",
            "zencheckdbstats=zends.toolbox.zencheckdbstats:main",
        ],
    },
)
