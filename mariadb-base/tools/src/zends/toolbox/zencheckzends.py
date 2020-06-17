##############################################################################
#
# Copyright (C) Zenoss, Inc. 2014, all rights reserved.
#
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
#
##############################################################################

from __future__ import print_function, absolute_import

import argparse
import atexit
import logging
import os
import re
import subprocess
import sys

from logging.handlers import RotatingFileHandler
from subprocess import Popen, PIPE

from .config import parse_global_conf

here = os.path.dirname(__file__)

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("zen.zencheckzends")
LOG.addHandler(
    RotatingFileHandler(
        "/opt/zenoss/log/zencheckzends.log",
        maxBytes=10 * 1024 * 1024,
        backupCount=3,
    )
)


class SQL(object):

    has_connection_info = os.path.join(here, "sql", "has_connection_info.sql")

    create_connection_info = os.path.join(
        here, "sql", "create_connection_info.sql",
    )

    has_killtx = os.path.join(here, "sql", "has_killtx.sql")

    create_killtx = os.path.join(here, "sql", "create_killtx.sql")


class ZenCheckZenDS(object):

    def __init__(self, options):
        self.options = options
        self._config = None

    def install(self, silent=False):
        database = self._zodb_database()

        stdout, stderr = self._exec_sql(database, SQL.has_connection_info)
        try:
            if int(stdout) > 0:
                if not silent:
                    LOG.info(
                        "Database already has %s.connection_info table. "
                        "No action required.", database,
                    )
            else:
                stdout, stderr = self._exec_sql(
                    database, SQL.create_connection_info,
                )
                if not silent:
                    LOG.warn(
                        "Created %s.connection_info table in database. "
                        "PLEASE RESTART ALL DEPENDENT SERVICES.",
                        database,
                    )
        except ValueError:
            if not silent:
                LOG.error(
                    "Unable to determine if %s.connection_info table "
                    "exists in database!", database,
                )
            sys.exit(1)

        stdout, stderr = self._exec_sql("mysql", SQL.has_killtx)
        try:
            if int(stdout) > 0:
                if not silent:
                    LOG.info(
                        "Database already has mysql.KillTransactions "
                        "stored procedure. No action required."
                    )
            else:
                stdout, stderr = self._exec_sql("mysql", SQL.create_killtx)
                if not silent:
                    LOG.info(
                        "Created mysql.KillTransactions stored procedure."
                    )
        except ValueError:
            if not silent:
                LOG.error(
                    "Unable to determine if mysql.KillTransactions "
                    "stored procedure exists in database!"
                )
            sys.exit(1)

    def check(self):
        sql = "CALL mysql.KillTransactions(%d,'DRYRUN');" % (
            self.options.minutes * 60,
        )
        stdout, stderr = self._zendb("mysql", sql)
        stdout = stdout.strip()
        if stdout != "None":
            lines = re.split("\\\\n", stdout)
            for line in lines:
                LOG.info("FOUND: %s", line)

    def truncate(self):
        database = self._zodb_database()
        sql = "TRUNCATE {0}.{1}".format(database, "connection_info")
        stdout, stderr = self._zendb(database, sql)

    def kill(self):
        sql = "CALL mysql.KillTransactions(%d,'KILL');" % (
            self.options.minutes * 60,
        )
        stdout, stderr = self._zendb("mysql", sql)
        stdout = stdout.strip()
        if stdout != "None":
            lines = re.split("\\\\n", stdout)
            for line in lines:
                LOG.warn("KILLED: %s", line)

    def _globalConfSettings(self):
        if self._config is None:
            self._config = parse_global_conf(
                os.environ["ZENHOME"] + "/etc/global.conf", LOG,
            )
        return self._config

    def _zodb_database(self):
        settings = self._globalConfSettings()
        return settings.get("zodb-db", "zodb")

    def _exec_sql(self, db_name, filename):
        with open(filename, "r") as f:
            sql = f.read()
        return self._zendb(db_name, sql)

    def _zendb(self, db_name, sql):
        settings = self._globalConfSettings()
        db_type = settings.get("zodb-db-type", "mysql")
        if not db_type == "mysql":
            LOG.error("%s is not a valid database type.", db_type)
            sys.exit(1)
        db_user = (
            self.options.username
            or settings.get("zodb-admin-user", None)
            or "root"
        )
        env = os.environ.copy()
        db_pass = (
            env.get("MYSQL_PWD", None)
            or settings.get("zodb-admin-password", None)
            or ""
        )
        # Pass the password via environment variable instead of the CLI.
        env["MYSQL_PWD"] = db_pass
        cmd = [
            "mysql",
            "--batch",
            "--skip-column-names",
            "--user=%s" % db_user,
            "--database=%s" % db_name,
        ]
        s = Popen(cmd, env=env, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        try:
            stdout, stderr = s.communicate(sql)
            rc = s.wait()
            if rc:
                LOG.error("Error executing mysql: %s %s\n", stdout, stderr)
                sys.exit(1)
            else:
                return (stdout, stderr)
        except KeyboardInterrupt:
            subprocess.call("stty sane", shell=True)
            s.kill()


def _get_lock(process_name):
    # Should we find a better place for lock?
    lock_name = "%s.lock" % process_name
    lock_path = os.path.join("/tmp", lock_name)

    if os.path.isfile(lock_path):
        LOG.error("'%s' lock already exists - exiting" % (process_name))
        return False
    else:
        file(lock_path, "w+").close()
        atexit.register(os.remove, lock_path)
        LOG.debug("Acquired '%s' execution lock" % (process_name))
        return True


def get_arguments():
    epilog = "Checks for (or kills) long-running database transactions."
    parser = argparse.ArgumentParser(epilog=epilog)
    parser.add_argument(
        "action",
        type=str,
        choices=["install", "install-silent", "check", "kill", "truncate"],
        help="user action to operate with long-running database transactions.",
    )
    parser.add_argument(
        "-m",
        "--minutes",
        dest="minutes",
        default=360,
        type=int,
        help='minutes before a transaction is considered "long-running"',
    )
    parser.add_argument(
        "-u",
        "--username",
        dest="username",
        default=None,
        help='username of admin user for database server (probably "root")',
    )
    return parser.parse_args()


def main():
    if not _get_lock("zencheckzends"):
        sys.exit(1)

    args = get_arguments()
    action = args.action
    if action == "install":
        ZenCheckZenDS(options=args).install()
    elif action == "install-silent":
        ZenCheckZenDS(options=args).install(silent=True)
    elif action == "check":
        ZenCheckZenDS(options=args).check()
    elif action == "kill":
        ZenCheckZenDS(options=args).kill()
    elif action == "truncate":
        ZenCheckZenDS(options=args).truncate()


if __name__ == "__main__":
    main()
