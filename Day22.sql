-- ============================================
-- Day22 学習用: バイトスピル / 非効率なプルーニング 再現クエリ
-- SnowPro Core (COF-C03) 学習プラン Week4
-- ============================================
 
-- 1. 検証用のウェアハウス（小さめサイズにしてスピルを起こしやすくする）
CREATE OR REPLACE WAREHOUSE LEARN_WH WITH WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
USE WAREHOUSE LEARN_WH;
 
-- 2. 検証用データベース/スキーマ
CREATE OR REPLACE DATABASE LEARN_DB;
CREATE OR REPLACE SCHEMA LEARN_DB.PUBLIC;
USE SCHEMA LEARN_DB.PUBLIC;
 
-- ============================================
-- 3. ダミーデータ生成
-- ============================================
 
-- 大きめのファクトテーブル（約2,000万行）
-- notes列で1行のサイズを太らせ、メモリ消費量を増やしている
CREATE OR REPLACE TABLE SALES_FACT AS
SELECT
    SEQ4()                                                   AS sale_id,
    UNIFORM(1, 100000, RANDOM())                             AS customer_id,
    UNIFORM(1, 500, RANDOM())                                AS product_id,
    UNIFORM(1, 1000, RANDOM())                                AS store_id,
    DATEADD(day, UNIFORM(0, 1460, RANDOM()), '2022-01-01')   AS sale_date,
    UNIFORM(1, 20, RANDOM())                                 AS quantity,
    ROUND(UNIFORM(100, 100000, RANDOM()) / 100.0, 2)         AS amount,
    RANDSTR(50, RANDOM())                                    AS notes
FROM TABLE(GENERATOR(ROWCOUNT => 20000000));
 
-- 比較的小さいディメンションテーブル（顧客マスタ、10万行）
CREATE OR REPLACE TABLE CUSTOMER_DIM AS
SELECT
    SEQ4()                        AS customer_id,
    'Customer_' || SEQ4()         AS customer_name,
    UNIFORM(1, 47, RANDOM())      AS prefecture_id,
    RANDSTR(30, RANDOM())         AS address
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

-- ============================================
-- クエリA: 「爆発的な結合」+ ORDER BY でバイトスピルを狙う
-- ============================================
-- JOINで大量行を突き合わせた後、ORDER BYでソートをかけることで
-- ウェアハウスのメモリに乗り切らずディスクへスピルしやすくなる。
SELECT
    s.sale_id,
    s.amount,
    s.notes,
    c.customer_name,
    c.address
FROM SALES_FACT s
JOIN CUSTOMER_DIM c
    ON s.customer_id = c.customer_id
    -- ↑ このJOIN条件を一時的にコメントアウトすると直積(CROSS JOIN)相当になり、
    --    「爆発的な結合」をさらに強く再現できます（実行時間に注意）
ORDER BY s.amount DESC, c.customer_name;


SELECT query_id, warehouse_name, bytes_spilled_to_local_storage, bytes_spilled_to_remote_storage
FROM snowflake.account_usage.query_history
WHERE bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0
ORDER BY bytes_spilled_to_remote_storage DESC
LIMIT 10;


SELECT COUNT(*)
FROM SALES_FACT
WHERE sale_date BETWEEN '2023-06-01' AND '2023-06-30';

SELECT COUNT(*)
FROM SALES_FACT
WHERE TO_CHAR(sale_date, 'YYYY-MM') = '2023-06';


DROP DATABASE LEARN_DB;
DROP WAREHOUSE LEARN_WH;