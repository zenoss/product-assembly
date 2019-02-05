#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Python 3rd-party dependencies comparison utility.
"""

import os
import sys
import json
import logging
import argparse


__author__ = "Zenoss Inc."
__email__ = "otm7402@zenoss.com"
__copyright__ = "Copyright 2019, Zenoss Inc."
__license__ = "Apache Version 2.0"
__version__ = "1.0.0"
__maintainer__ = "Zenoss Inc."
__date__ = "4 February 2019"
__status__ = "Development"


def parse_packages(filename):
    """
    Load and parse file with Python 3rd-party dependencies
    :param filename: path to file with dependencies
    :type filename: str
    :return: list of dependencies
    :rtype: dict
    """

    # Try to load and parse file with dependencies
    logging.debug('Loading dependencies from file "%s"...', filename)

    try:
        return dict(
            {
                package["name"]: package["version"]
                for package in json.load(open(filename, "r"))
            }
        )
    except IOError:
        logging.critical('Cannot open file "%s"!', filename)
        sys.exit(1)
    except KeyError:
        logging.critical('Incorrect format of file "%s"!', filename)
        sys.exit(1)


def compare_packages(previous_deps, current_deps):
    """
    Compare dependencies lists
    :param previous_deps: previous dependencies list
    :param current_deps: current dependencies list
    :type previous_deps: dict
    :type current_deps: dict
    :return: dependencies lists difference
    :rtype: dict
    """

    logging.debug("Compare dependencies lists...")

    return list([
        {
            "package": package,
            "previous": previous_deps.get(package, None),
            "current": current_deps.get(package, None),
        }
        for package in set(previous_deps.keys() + current_deps.keys())
        if previous_deps.get(package, None) != current_deps.get(package, None)
    ])


def report_format(packages_difference):
    """
    Build plain report based on difference of 3rd-party dependencies
    :param packages_difference: dependencies difference
    :type packages_difference: dict
    :return: formatted differences report
    :rtype: str
    """

    logging.debug("Building report...")

    # Initialize output buffer and format
    output = ""
    line_format = "{package:<30} {previous:^10} {current:^10}" + os.linesep

    # Add packages data to output
    for package in packages_difference:
        # Add headers
        if not output:
            output += line_format.format(
                **dict({field: field.upper() for field in package.keys()})
            )
            output += "-" * (len(output) - 1) + os.linesep

        # Add formatted record to the output
        output += line_format.format(**package)

    # Return output
    return output


def main():
    """
    Utility main function
    """

    # Define program options
    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument(
        "previous",
        type=str,
        metavar="PREVIOUS_DEPS",
        help="previous dependencies list file",
    )
    parser.add_argument(
        "current",
        type=str,
        metavar="CURRENT_DEPS",
        help="current dependencies list file",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        dest="out_file",
        metavar="FILENAME",
        help="output to file",
    )
    parser.add_argument(
        "-l",
        "--level",
        type=str,
        dest="log_level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        default="ERROR",
        metavar="LOG_LEVEL",
        help="utility logging level",
    )
    parser.add_argument(
        "-v",
        "--version",
        action="version",
        version="%(prog)s " + __version__
    )

    # Parse passed arguments
    options = parser.parse_args()

    # Configure logging settings
    logging.basicConfig(
        level=getattr(logging, options.log_level, "ERROR"),
        format="[%(asctime)s][%(levelname)s]: %(message)s",
        datefmt="%d-%m-%Y %H:%M:%S",
    )

    # Load dependencies lists
    previous_deps = parse_packages(options.previous)
    current_deps = parse_packages(options.current)

    # Compare dependencies lists
    packages_difference = compare_packages(previous_deps, current_deps)

    # Generate difference report
    difference_report = report_format(packages_difference)

    # Send report to output
    try:
        # Check if output file passed
        if options.out_file:
            # Send to file
            logging.debug('Writing report to "%s"...', options.out_file)

            report_file = open(options.out_file, "w")
            report_file.write(difference_report)
            report_file.close()

    except IOError:
        logging.error('Cannot write report to file "%s"!', options.out_file)

    finally:
        # Send to console output
        sys.stdout.write(difference_report)

    # Done and exit
    logging.debug("Done.")
    sys.exit(0)


if __name__ == "__main__":
    main()

