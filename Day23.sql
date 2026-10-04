WITH a AS (SELECT SEQ4() AS id FROM TABLE(GENERATOR(ROWCOUNT => 1000))),
     b AS (SELECT SEQ4() AS id FROM TABLE(GENERATOR(ROWCOUNT => 1000)))
SELECT COUNT(*)
FROM a JOIN b ON a.id % 10 = b.id % 10;


SELECT query_id, warehouse_name, total_elapsed_time,
       queued_overload_time, queued_provisioning_time, execution_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 20))
ORDER BY start_time DESC;


SELECT query_id, warehouse_name, total_elapsed_time,
       queued_overload_time, queued_provisioning_time, execution_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
ORDER BY start_time DESC
LIMIT 20;

-- 01c7638f-0204-c76f-0005-363e002560ba


