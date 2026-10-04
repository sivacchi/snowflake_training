
-- 0) 練習用にテーブルをコピー(約150万行)
CREATE DATABASE IF NOT EXISTS study_db;
CREATE OR REPLACE TABLE study_db.public.orders_copy AS
  SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;

select
o_orderdate
, count(*)
from study_db.public.orders_copy
group by o_orderdate;

--662ms

-- 1) クラスタリングキー
ALTER TABLE study_db.public.orders_copy CLUSTER BY (o_orderdate);
SELECT SYSTEM$CLUSTERING_INFORMATION('study_db.public.orders_copy', '(o_orderdate)');

select
o_orderdate
, count(*)
from study_db.public.orders_copy
group by o_orderdate;

--532ms

-- キャッシュ利用しない
SHOW PARAMETERS LIKE '%USE_CACHED_RESULT%'

use role accountadmin;
ALTER ACCOUNT SET USE_CACHED_RESULT = false;


select
o_custkey
,count(*)
from study_db.public.orders_copy
group by o_custkey
;
-- 237ms

select
*
from study_db.public.orders_copy
where o_custkey = 102757
-- 256ms

-- 2) 検索最適化サービス
ALTER TABLE study_db.public.orders_copy ADD SEARCH OPTIMIZATION ON EQUALITY(o_custkey);
DESCRIBE SEARCH OPTIMIZATION ON study_db.public.orders_copy;

select
o_custkey
,count(*)
from study_db.public.orders_copy
group by o_custkey
;
-- 312ms

select
*
from study_db.public.orders_copy
where o_custkey = 102757
-- 162ms

-- 3) マテリアライズドビュー
CREATE MATERIALIZED VIEW study_db.public.mv_orders_daily AS
  SELECT o_orderdate, COUNT(*) AS cnt, SUM(o_totalprice) AS total
  FROM study_db.public.orders_copy
  GROUP BY o_orderdate;
SHOW MATERIALIZED VIEWS IN SCHEMA study_db.public;

DROP DATABASE study_db;
