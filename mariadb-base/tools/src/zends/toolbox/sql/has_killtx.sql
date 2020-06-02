SELECT COUNT(*)
FROM information_schema.routines
WHERE UPPER(routine_schema) = 'MYSQL'
AND UPPER(routine_name) = 'KILLTRANSACTIONS';
