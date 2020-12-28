SELECT COUNT(*)
FROM information_schema.columns
WHERE table_schema = DATABASE()
AND UPPER(table_name) = 'CONNECTION_INFO';
