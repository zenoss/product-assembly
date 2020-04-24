#!/bin/env python

import ZODB.config

config_file = "file:///opt/zenoss/install_scripts/zodb.conf"
db = ZODB.config.databaseFromURL(config_file)
conn = db.open()
