DROP PROCEDURE IF EXISTS mysql.KillTransactions;
DELIMITER $$
CREATE PROCEDURE mysql.KillTransactions(
  IN num_seconds int(10) unsigned, IN action varchar(10)
)
BEGIN
  DECLARE _ts INT;
  DECLARE _q_db LONGTEXT;
  DECLARE _q_pid LONGTEXT;
  DECLARE _q_info LONGTEXT;
  DECLARE _q_outer_joins LONGTEXT;
  DECLARE done BOOL DEFAULT FALSE;
  DECLARE v_db VARCHAR(64);
  DECLARE _txns_count INT DEFAULT 0;
  DECLARE _txns_killed TEXT DEFAULT "'HOST','DB','COMMAND','STATE','INFO','PID','LINE1','LINE2','TRX_ID','TRX_QUERY','TRX_STARTED','TRX_MYSQL_THREAD_ID'";
  DECLARE v_host VARCHAR(54);
  DECLARE v_command VARCHAR(16);
  DECLARE v_state VARCHAR(64);
  DECLARE v_info LONGTEXT;
  DECLARE v_pid BIGINT(21) UNSIGNED;
  DECLARE v_line1 VARCHAR(1000);
  DECLARE v_line2 VARCHAR(1000);
  DECLARE v_trx_id VARCHAR(20);
  DECLARE v_trx_query VARCHAR(1024);
  DECLARE v_started VARCHAR(20);
  DECLARE v_thread_id BIGINT(21) UNSIGNED;
  DECLARE c_db CURSOR FOR
    SELECT DISTINCT p.db
    FROM information_schema.innodb_trx trx
    INNER JOIN information_schema.processlist p
      ON p.id = trx.trx_mysql_thread_id
    WHERE (_ts - UNIX_TIMESTAMP(trx.trx_started)) > num_seconds;
  DECLARE c_thread_id CURSOR FOR
    SELECT *
    FROM long_transactions
    WHERE (_ts - UNIX_TIMESTAMP(trx_started)) > num_seconds;

  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = TRUE;

  SET done = FALSE;
  SET _ts = UNIX_TIMESTAMP();
  OPEN c_db;
  REPEAT
    FETCH c_db INTO v_db;
    IF NOT done AND EXISTS(
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = v_db AND UPPER(table_name) = 'CONNECTION_INFO'
    )
    THEN
      SET _q_db = CONCAT('`',REPLACE(v_db,'`','``'),'`');
      SET _q_pid = CONCAT_WS(
        ', ', _q_pid, CONCAT(_q_db, '.connection_info.pid')
      );
      SET _q_info = CONCAT_WS(
        ', ', _q_info, CONCAT(_q_db, '.connection_info.info')
      );
      SET _q_outer_joins = CONCAT_WS(
        ' ',
        _q_outer_joins,
        CONCAT(
          'LEFT OUTER JOIN ',
          _q_db,
          '.connection_info on p.id = ',
          _q_db,
          '.connection_info.connection_id and p.db = ',
          QUOTE(v_db)
        )
      );
    END IF;
  UNTIL done END REPEAT;

  SET @query = CONCAT(
    'CREATE OR REPLACE VIEW long_transactions
    AS SELECT
      p.host,
      p.db,
      p.command,
      p.state,
      p.info,
      COALESCE(', COALESCE(_q_pid,'NULL'), ') AS pid,
      SUBSTRING_INDEX(COALESCE(', COALESCE(_q_info,'NULL'), '),''\n'',1) AS line1,
      SUBSTRING_INDEX(SUBSTRING_INDEX(COALESCE(', COALESCE(_q_info,'NULL'), '),''\n'',2),''\n'',-1) AS line2,
      trx.trx_id,
      trx.trx_query,
      trx.trx_started,
      trx.trx_mysql_thread_id
    FROM information_schema.innodb_trx trx
    INNER JOIN information_schema.processlist p
      ON p.id = trx.trx_mysql_thread_id ',
    COALESCE(_q_outer_joins,'')
  );
  PREPARE stmt FROM @query;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  SET done = FALSE;
  OPEN c_thread_id;
  REPEAT
    FETCH c_thread_id
    INTO
        v_host,
        v_db,
        v_command,
        v_state,
        v_info,
        v_pid,
        v_line1,
        v_line2,
        v_trx_id,
        v_trx_query,
        v_started,
        v_thread_id;
    IF NOT done THEN
      SET _txns_killed = CONCAT_WS(
        '\n',
        _txns_killed,
        CONCAT_WS(
          ',',
          QUOTE(v_host),
          QUOTE(COALESCE(v_db,'')),
          QUOTE(v_command),
          QUOTE(COALESCE(v_state,'')),
          QUOTE(COALESCE(v_info,'')),
          QUOTE(COALESCE(v_pid,'')),
          QUOTE(COALESCE(v_line1,'')),
          QUOTE(COALESCE(v_line2,'')),
          QUOTE(v_trx_id),
          QUOTE(COALESCE(v_trx_query,'')),
          QUOTE(v_started),
          QUOTE(v_thread_id)
        )
      );
      IF 'KILL' = upper(action) THEN
        KILL v_thread_id;
      END IF;
      SET _txns_count = _txns_count + 1;
    END IF;
  UNTIL done END REPEAT;
  IF _txns_count < 1 THEN
    SET _txns_killed = 'None';
  END IF;
  SELECT _txns_killed;
END
$$
DELIMITER ;
DROP EVENT IF EXISTS kill_long_running_txns;
