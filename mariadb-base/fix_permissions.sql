# Delete anonymous users
DELETE FROM mysql.user WHERE user = '';

# Remove remote access from root user
DELETE FROM mysql.user WHERE user = 'root' and host != 'localhost';

# Allow access from any host for zenoss user
DELETE FROM mysql.user WHERE user = 'zenoss' and host != '%';

# Grant privileges to zenoss user.
GRANT SELECT ON mysql.proc TO 'zenoss' IDENTIFIED BY 'zenoss';
GRANT REPLICATION SLAVE ON *.* TO 'zenoss' IDENTIFIED BY 'zenoss';
GRANT PROCESS ON *.* TO 'zenoss' IDENTIFIED BY 'zenoss';
GRANT ALL ON zodb.* TO 'zenoss' IDENTIFIED BY 'zenoss';
GRANT ALL ON zodb_session.* TO 'zenoss' IDENTIFIED BY 'zenoss';
GRANT ALL ON zenoss_zep.* TO 'zenoss' IDENTIFIED BY 'zenoss';

FLUSH PRIVILEGES;
