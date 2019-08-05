To build the zodb.sql.gz file, the following command:
```
product-assembly/devimg$ DEV_ENV=$(zendev env) ZENDEV_ROOT=$(zendev root) ZENWIPE_ARGS=--xml make dumpdb 
```
