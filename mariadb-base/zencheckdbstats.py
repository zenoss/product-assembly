##############################################################################
#
# Copyright (C) Zenoss, Inc. 2020, all rights reserved.
#
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
#
##############################################################################

from __future__ import print_function

import argparse
import datetime
import logging
import math
import os
import pymysql
import re
import socket
import string
import sys
import time

from collections import OrderedDict
from logging.handlers import RotatingFileHandler

scriptVersion = "2.0.0"
scriptSummary = " - gathers performance information about your DB - "
documentationURL = "https://support.zenoss.com/hc/en-us/articles/208050803"

TIME_FORMAT = "%Y-%m-%d %H:%M:%S"


def configure_logging(name, version, tmpdir):
    """Returns a python logging object for zenoss.toolbox tool usage"""

    # Confirm %tmpdir, $ZENHOME and check for $ZENHOME/log/toolbox
    if not os.path.exists(tmpdir):
        print("%s doesn't exist - aborting" % (tmpdir))
        sys.exit(1)
    zenhome_path = os.getenv("ZENHOME")
    if not zenhome_path:
        print("$ZENHOME undefined - are you running as the zenoss user?")
        sys.exit(1)
    log_file_path = os.path.join(zenhome_path, "log", "toolbox")
    if not os.path.exists(log_file_path):
        os.makedirs(log_file_path)

    # Setup "trash" toolbox log file (needed for ZenScriptBase log overriding)
    logging.basicConfig(
        filename=os.path.join(tmpdir, "toolbox.log.tmp"),
        filemode="w",
        level=logging.INFO,
    )

    # Create full path filename string for logfile, create RotatingFileHandler
    toolbox_log = logging.getLogger("%s" % (name))
    toolbox_log.setLevel(logging.INFO)
    log_file_name = os.path.join(
        zenhome_path, "log", "toolbox", "%s.log" % (name)
    )
    handler = RotatingFileHandler(
        log_file_name, maxBytes=8192 * 1024, backupCount=5
    )

    # Set logging.Formatter for format and datefmt, attach handler
    formatter = logging.Formatter(
        "%(asctime)s,%(msecs)03d %(levelname)s %(name)s: %(message)s",
        "%Y-%m-%d %H:%M:%S",
    )
    handler.setFormatter(formatter)
    handler.setLevel(logging.DEBUG)
    toolbox_log.addHandler(handler)

    # Print initialization string to console, log status to logfile
    toolbox_log.info(
        "############################################################"
    )
    toolbox_log.info("Initializing %s (version %s)", name, version)

    return toolbox_log, log_file_name


def get_lock(lock_name, log):
    """Global lock function to keep multiple tools from running at once"""
    global lock_socket
    lock_socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    try:
        lock_socket.bind("\0" + lock_name)
        log.debug("Acquired '%s' execution lock", lock_name)
    except socket.error:
        print(
            "[%s] Aborting - unable to acquire %s socket lock "
            "- are other tools running?\n"
            % (time.strftime("%Y-%m-%d %H:%M:%S"), lock_name)
        )
        log.error(
            "'%s' lock already exists - unable to acquire - exiting", lock_name
        )
        log.info(
            "############################################################"
        )
        return False
    return True


def inline_print(message):
    """Print and flush message on a single line to stdout."""
    sys.stdout.write("\r%s" % (message))
    sys.stdout.flush()


def parse_global_conf(filename, log):
    """Get connection info from $ZENHOME/etc/global.conf."""
    COMMENT_DELIMETER = "#"
    OPTION_DELIMETER = " "
    parsed_options = {}
    log.info(
        "Parsing $ZENHOME/etc/global.conf for database connection information"
    )
    global_conf_file = open(filename)
    for line in global_conf_file:
        if COMMENT_DELIMETER in line:
            line, comment = line.split(COMMENT_DELIMETER, 1)
        if OPTION_DELIMETER in line:
            option, value = line.split(OPTION_DELIMETER, 1)
            option = option.strip()
            value = value.strip()
            parsed_options[option] = value
            log.debug("(%s %s)", option, parsed_options[option])
    global_conf_file.close()
    log.debug("Parsing of $ZENHOME/etc/global.conf complete")
    return parsed_options


def parse_options(scriptVersion, description_string):
    """Defines command-line options for script """
    parser = argparse.ArgumentParser(
        version=scriptVersion, description=description_string
    )

    calculatedTmpDir = next(
        (os.getenv(n) for n in ("TMP", "TEMP", "TMPDIR") if n in os.environ),
        None,
    )
    if not calculatedTmpDir:
        calculatedTmpDir = "/tmp"

    parser.add_argument(
        "-v10",
        "--debug",
        action="store_true",
        default=False,
        help="verbose log output (debug logging)",
    )
    parser.add_argument(
        "--tmpdir",
        action="store",
        default=calculatedTmpDir,
        help="override the TMPDIR setting",
    )
    parser.add_argument(
        "-n",
        "-t",
        "--times",
        action="store",
        default=1,
        type=int,
        help="number of times to gather data",
    )
    parser.add_argument(
        "-g",
        "--gap",
        action="store",
        default=60,
        type=int,
        help="gap between gathering subsequent datapoints",
    )
    parser.add_argument(
        "-l3",
        "--level3",
        action="store_true",
        default=False,
        help="Data gathering for L3 (standardized parameters)",
    )
    return parser


def connect_to_mysql(database_dict, log):
    log.info(
        "Opening connection to MySQL for database %s at %s",
        database_dict["prettyName"],
        database_dict["host"],
    )
    try:
        if (
            database_dict["host"] == "localhost"
            and "zodb-socket" in database_dict
        ):
            mysql_connection = pymysql.connect(
                unix_socket=database_dict["socket"],
                user=database_dict["user"],
                passwd=database_dict["password"],
                db=database_dict["database"],
            )
        else:
            mysql_connection = pymysql.connect(
                host=database_dict["host"],
                port=int(database_dict["port"]),
                user=database_dict["user"],
                passwd=database_dict["password"],
                db=database_dict["database"],
            )
    except pymysql.Error as e:
        print("Error %d: %s" % (e.args[0], e.args[1]))
        log.exception("Failure: %s", e)
        sys.exit(1)
    except Exception as e:
        print("Exception encountered: ", e)
        log.exception("Failure: %s", e)
        sys.exit(1)

    return mysql_connection


def parse_innodb_status(status, log):
    # INNODB: Grab data for "History list length"
    result = {}
    text = "History list length "
    offset = string.find(status, text)
    if offset != -1:
        index = offset + len("History list length ")
        value = int(string.split(status[index:], "\n")[0])
        result["history_list_length"] = value
    else:
        log.error("Unable to find 'History List Length' in INNODB output")
        print("Unable to find 'History List Length' in INNODB output")
        sys.exit(1)

    # INNODB: Grab data for "TRANSACTION.*ACTIVE"
    active_transactions = re.findall("---TRANSACTION.*ACTIVE", status)
    result["number_active_transactions"] = len(active_transactions)

    # INNODB: Grab data for "TRANSACTION.*ACTIVE" > 100 secs
    active_transactions_over = re.findall(
        "---TRANSACTION.*ACTIVE [0-9]{3,} sec", status
    )
    result["number_active_transactions_over"] = len(
        active_transactions_over
    )
    return result


_BufferPoolSQL = """
SELECT FORMAT((a.DataPages * 100.0) / b.TotalPages, 2)
FROM (
    SELECT variable_value DataPages
    FROM information_schema.global_status
    WHERE variable_name = 'Innodb_buffer_pool_pages_data'
) AS a, (
    SELECT variable_value TotalPages
    FROM information_schema.global_status
    WHERE variable_name = 'Innodb_buffer_pool_pages_total'
) AS b
"""


def gather_MySQL_statistics(mysql_connection, log):
    # Execute point in time queries and parse results;
    # return results in results_dict
    results_dict = {}
    try:
        mysql_cursor = mysql_connection.cursor()

        # INNODB: Gather results of "SHOW ENGINE INNODB STATUS"
        log.info("  Gathering results for 'SHOW ENGINE INNODB STATUS'")
        mysql_cursor.execute("SHOW ENGINE INNODB STATUS")
        innodb_results = mysql_cursor.fetchall()
        status_data = innodb_results[0][2]
        log.debug("    InnoDB Status:\n%s", status_data)
        results_dict.update(parse_innodb_status(status_data, log))

        # Gather results and grab data for "Buffer Pool Percentage Used"
        mysql_cursor.execute(_BufferPoolSQL)
        results_dict["buffer_pool_used_percentage"] = float(
            mysql_cursor.fetchone()[0]
        )
    except Exception as e:
        print("Exception encountered: ", e)
        log.exception("Failure: %s", e)
        exit(1)

    log.info("  Results: %s", results_dict)

    return results_dict


def log_MySQL_variables(mysql_connection, log):
    """Log the results of the 'SHOW VARIABLES' statement."""
    try:
        mysql_cursor = mysql_connection.cursor()
        log.info("  Gathering results for 'SHOW VARIABLES'")
        mysql_cursor.execute("SHOW VARIABLES")
        mysql_results = mysql_cursor.fetchall()
        for item in mysql_results:
            log.info(item)
    except Exception as e:
        print("Exception encountered: ", e)
        log.exception("Failure: %s", e)
        exit(1)


def main():
    """Gathers metrics and statistics for ZODB and ZEP databases."""
    execution_start = time.time()
    scriptName = os.path.basename(__file__).split(".")[0]
    parser = parse_options(
        scriptVersion, scriptName + scriptSummary + documentationURL
    )
    # Add in any specific parser arguments for %scriptName
    cli_options = vars(parser.parse_args())
    log, logFileName = configure_logging(
        scriptName, scriptVersion, cli_options["tmpdir"]
    )
    log.info("Command line options: %s", cli_options)
    if cli_options["debug"]:
        log.setLevel(logging.DEBUG)

    print(
        "\n[%s] Initializing %s v%s (detailed log at %s)" % (
            time.strftime("%Y-%m-%d %H:%M:%S"),
            scriptName,
            scriptVersion,
            logFileName,
        ),
    )

    # Attempt to get the zenoss.toolbox lock before any actions performed
    if not get_lock("zenoss.toolbox.checkdbstats", log):
        sys.exit(1)

    if cli_options["level3"]:
        cli_options["times"] = 120
        cli_options["gap"] = 60
        cli_options["debug"] = True
    if cli_options["debug"]:
        log.setLevel(logging.DEBUG)

    # Load up the contents of global.conf for using with MySQL
    global_conf_dict = parse_global_conf(
        os.environ["ZENHOME"] + "/etc/global.conf", log
    )

    # ZEN-19373: zencheckdbstats needs to take into account split databases
    databases_to_examine = []
    intermediate_dict = {
        "prettyName": "'zodb' Database",
        "host": global_conf_dict["zodb-host"],
        "port": global_conf_dict["zodb-port"],
        "user": global_conf_dict["zodb-user"],
        "password": global_conf_dict["zodb-password"],
        "database": global_conf_dict["zodb-db"],
        "mysql_results_list": [],
    }
    if global_conf_dict["zodb-host"] == "localhost":
        if "zodb-socket" in global_conf_dict:
            intermediate_dict["socket"] = global_conf_dict["zodb-socket"]
    databases_to_examine.append(intermediate_dict)
    if global_conf_dict["zodb-host"] != global_conf_dict["zep-host"]:
        intermediate_dict = {
            "prettyName": "'zenoss_zep' Database",
            "host": global_conf_dict["zep-host"],
            "port": global_conf_dict["zep-port"],
            "user": global_conf_dict["zep-user"],
            "password": global_conf_dict["zep-password"],
            "database": global_conf_dict["zep-db"],
            "mysql_results_list": [],
        }
        if global_conf_dict["zep-host"] == "localhost":
            # No zep-socket param, use zodb-socket
            if "zodb-socket" in global_conf_dict:
                intermediate_dict["socket"] = global_conf_dict["zodb-socket"]
        databases_to_examine.append(intermediate_dict)

    # If running in debug, log global.conf, grab 'SHOW VARIABLES',
    # if straightforward (localhost)
    if cli_options["debug"]:
        try:
            for item in databases_to_examine:
                mysql_connection = connect_to_mysql(item, log)
                log_MySQL_variables(mysql_connection, log)
                if mysql_connection:
                    mysql_connection.close()
                    log.info(
                        "Closed connection to MySQL for database %s at %s",
                        item["prettyName"],
                        item["host"],
                    )
        except Exception as e:
            print("Exception encountered: ", e)
            log.exception("Failure: %s", e)
            exit(1)

    sample_count = 0

    while sample_count < cli_options["times"]:
        sample_count += 1
        current_time = time.time()
        inline_print(
            "[%s] Gathering MySQL metrics... (%d/%d)"
            % (time.strftime(TIME_FORMAT), sample_count, cli_options["times"])
        )
        try:
            for item in databases_to_examine:
                mysql_connection = connect_to_mysql(item, log)
                mysql_results = gather_MySQL_statistics(mysql_connection, log)
                item["mysql_results_list"].append(
                    (current_time, mysql_results)
                )
                if mysql_connection:
                    mysql_connection.close()
                    log.info(
                        "Closed connection to MySQL for database %s at %s",
                        item["prettyName"],
                        item["host"],
                    )
        except Exception as e:
            print("Exception encountered: ", e)
            log.exception("Failure: %s", e)
            exit(1)
        if sample_count < cli_options["times"]:
            time.sleep(cli_options["gap"])

    # Process and display results (calculate statistics)
    print()
    for database in databases_to_examine:
        print(
            "\n[%s] Results for %s:"
            % (time.strftime(TIME_FORMAT), database["prettyName"])
        )
        log.info(
            "[%s] Final Results for %s:",
            time.strftime(TIME_FORMAT),
            database["prettyName"],
        )
        observed_results_dict = OrderedDict([])
        observed_results_dict["History List Length"] = [
            item[1]["history_list_length"]
            for item in database["mysql_results_list"]
        ]
        observed_results_dict["Bufferpool Used (%)"] = [
            item[1]["buffer_pool_used_percentage"]
            for item in database["mysql_results_list"]
        ]
        observed_results_dict["ACTIVE TRANSACTIONS"] = [
            item[1]["number_active_transactions"]
            for item in database["mysql_results_list"]
        ]
        observed_results_dict["ACTIVE TRANS > 100s"] = [
            item[1]["number_active_transactions_over"]
            for item in database["mysql_results_list"]
        ]
        for key in observed_results_dict:
            values = observed_results_dict[key]
            if min(values) != max(values):
                output_message = (
                    "[{}]  {}: {:<10} (Average {:.2f}, Minimum {}, Maximum {})"
                ).format(
                    time.strftime(TIME_FORMAT),
                    key,
                    values[-1],
                    float(sum(values) / len(values)),
                    min(values),
                    max(values),
                )
            else:
                output_message = "[{}]  {}: {}".format(
                    time.strftime(TIME_FORMAT), key, values[-1]
                )

            print(output_message)
            log.info(output_message)

    # Print final status summary, update log file with termination block
    print(
        "\n[%s] Execution finished in %s\n" % (
            time.strftime(TIME_FORMAT),
            datetime.timedelta(
                seconds=int(math.ceil(time.time() - execution_start))
            ),
        )
    )
    print(
        "** Additional information and next steps at %s **\n"
        % documentationURL
    )
    log.info(
        "zencheckdbstats completed in %1.2f seconds",
        time.time() - execution_start,
    )
    log.info("############################################################")
    sys.exit(0)


if __name__ == "__main__":
    main()
