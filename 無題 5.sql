create view sandbox.public.test_view
as select * from sandbox.public.test_table
;


create secure view sandbox.public.test_secure_view
as select * from sandbox.public.test_table
;

show views;

use database sandbox;
-- ============================================
-- 0. サンプルデータの準備
-- ============================================
CREATE OR REPLACE TABLE customers (
    customer_id   INT,
    customer_name STRING,
    region        STRING
);

INSERT INTO customers VALUES
    (1, '田中太郎', '関東'),
    (2, '佐藤花子', '関西'),
    (3, '鈴木一郎', '九州');

CREATE OR REPLACE TABLE orders (
    order_id    INT,
    customer_id INT,
    status      STRING,
    amount      NUMBER(10,2)
);

INSERT INTO orders VALUES
    (101, 1, 'COMPLETE', 1500),
    (102, 1, 'COMPLETE', 2300),
    (103, 2, 'PENDING',  980),
    (104, 3, 'COMPLETE', 4200),
    (105, 2, 'CANCELLED', 500);


-- ============================================
-- 1. 標準ビュー
-- ============================================
CREATE OR REPLACE VIEW v_orders_summary AS
SELECT status, SUM(amount) AS total_amount, COUNT(*) AS order_count
FROM orders
GROUP BY status;

SELECT * FROM v_orders_summary;


-- ============================================
-- 2. セキュアビュー（定義の見え方を比較）
-- ============================================
CREATE OR REPLACE SECURE VIEW v_orders_summary_secure AS
SELECT status, SUM(amount) AS total_amount, COUNT(*) AS order_count
FROM orders
GROUP BY status;

-- 定義の一覧を確認（IS_SECURE列の違いを見る）
SHOW VIEWS LIKE 'v_orders_summary%';

-- 定義（DDL）を直接取得して比較
SELECT GET_DDL('VIEW', 'v_orders_summary')
union all
SELECT GET_DDL('VIEW', 'v_orders_summary_secure');


-- ============================================
-- 3-a. マテリアライズドビュー：単一テーブル集計 → 成功するはず
-- ============================================
CREATE OR REPLACE MATERIALIZED VIEW mv_orders_by_status AS
SELECT status, SUM(amount) AS total_amount, COUNT(*) AS order_count
FROM orders
GROUP BY status;

SELECT * FROM mv_orders_by_status;


-- ============================================
-- 3-b. マテリアライズドビュー：JOINを含む定義 → エラーになるはず
-- ============================================
CREATE OR REPLACE MATERIALIZED VIEW mv_orders_with_customer AS
SELECT o.order_id, o.amount, c.customer_name, c.region
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;

-- ここでエラーメッセージが出れば成功（狙い通り）
-- Enterprise Edition未満のトライアルだと、JOINの前に
-- 「Unsupported feature 'MATERIALIZED VIEW'.」のような
-- エディション不足のエラーが先に出ることもあります。
-- どちらのエラーが出たか、メッセージをそのままDay17ノートに
-- 気づき・疑問として控えておくと後で見返しやすいです。


-- ============================================
-- 後片付け（不要になったら実行）
-- ============================================
-- DROP MATERIALIZED VIEW IF EXISTS mv_orders_by_status;
-- DROP MATERIALIZED VIEW IF EXISTS mv_orders_with_customer;
-- DROP VIEW IF EXISTS v_orders_summary;
-- DROP VIEW IF EXISTS v_orders_summary_secure;
-- DROP TABLE IF EXISTS orders;
-- DROP TABLE IF EXISTS customers;