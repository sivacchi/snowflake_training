CREATE WAREHOUSE wh_bi  WITH WAREHOUSE_SIZE='XSMALL' AUTO_SUSPEND=60 AUTO_RESUME=TRUE;
USE WAREHOUSE wh_bi;

-- ① 結果キャッシュ: 同じクエリを2回
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
SELECT l_returnflag, l_linestatus, SUM(l_quantity) AS qty, COUNT(*) AS cnt
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
GROUP BY l_returnflag, l_linestatus;
-- もう一度まったく同じSQLを実行 → クエリプロファイルで結果の再利用を確認

-- 初回：1.4s
-- 2回： 96ms


-- 大文字小文字だけ変えて実行 → 再利用されず再実行されるか確認
select l_returnflag, l_linestatus, sum(l_quantity) as qty, count(*) as cnt
from SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
group by l_returnflag, l_linestatus;

-- 636ms

-- ② 実行ごとに結果が変わる関数を含める → 再利用されないか確認
SELECT RANDOM() AS r, COUNT(*) FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;
-- 449ms
-- 69ms
-- 242ms

ALTER SESSION SET USE_CACHED_RESULT = FALSE;
ALTER WAREHOUSE wh_bi SUSPEND;
ALTER WAREHOUSE wh_bi RESUME;

SELECT l_shipmode, SUM(l_extendedprice) AS total
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
GROUP BY l_shipmode;                 -- 停止直後(コールド)

656ms

SELECT l_shipmode, AVG(l_extendedprice) AS avg_price
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
GROUP BY l_shipmode;                 -- 同じデータを読む別クエリ(ウォーム)

175ms
ALTER WAREHOUSE wh_bi SUSPEND;
ALTER WAREHOUSE wh_bi RESUME;
SELECT l_shipmode, AVG(l_extendedprice) AS avg_price
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
GROUP BY l_shipmode;                 -- 再開後(キャッシュが破棄されている)
-- 423ms

-- ④ 比較: 経過時間とキャッシュからの読み込み割合
SELECT query_text, total_elapsed_time, bytes_scanned,percentage_scanned_from_cache
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 20))
ORDER BY start_time DESC;


SELECT *
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
ORDER BY start_time;

-- ⑤ メタデータ: 統計だけで答えられるクエリ
SELECT COUNT(*), MIN(l_shipdate), MAX(l_shipdate)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;   -- プロファイルでデータを読んでいないか確認

-- 127ms

ALTER SESSION SET USE_CACHED_RESULT = TRUE;
ALTER WAREHOUSE wh_bi SUSPEND;