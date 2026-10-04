-- use database sandbox;
-- 1. サンプルテーブルを作る
CREATE OR REPLACE TABLE support_tickets (
    ticket_id INT,
    customer_feedback STRING
);

INSERT INTO support_tickets VALUES
  (1, '注文した商品が届かず、サポートにも繋がらなくて本当に困っています。'),
  (2, '対応がとても丁寧で助かりました。ありがとうございます！'),
  (3, '返品したいのですが手続き方法がわかりません。教えてください。'),
  (4, '配送は早かったですが、梱包が雑で商品が少し傷んでいました。');

-- 2. AI_SENTIMENT で感情分析（トライアルアカウントでは動かなかった）
SELECT 
    ticket_id,
    customer_feedback,
    AI_SENTIMENT(customer_feedback) AS sentiment
FROM support_tickets;

-- アカウントのリージョン問題かもと思ったが違った模様
USE ROLE ACCOUNTADMIN;

ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;

-- 結局Qiitaの記事を参照して使える関数を使って見た
SELECT customer_feedback, AI_SUMMARIZE(customer_feedback) AS summary
FROM support_tickets

SELECT AI_AGG(customer_feedback, 
  '以下の問い合わせ全体の傾向を3行で要約してください') AS trend_summary
FROM support_tickets;


-- 追加でお試し
CREATE OR REPLACE TABLE day18_orders (
    order_id INT,
    customer_name STRING,
    product_category STRING,
    order_date DATE,
    amount NUMBER(10,2)
);

INSERT INTO day18_orders VALUES
  (1, '田中', '家電', '2026-09-01', 15000),
  (2, '佐藤', '衣料品', '2026-09-03', 8000),
  (3, '田中', '衣料品', '2026-09-05', 5000),
  (4, '鈴木', '家電', '2026-09-10', 32000),
  (5, '佐藤', '食品', '2026-09-12', 3000),
  (6, '鈴木', '食品', '2026-09-15', 4500),
  (7, '田中', '家電', '2026-09-18', 22000);

  CREATE OR REPLACE SEMANTIC VIEW sv_day18_orders
  TABLES (
    day18_orders PRIMARY KEY (order_id)
      WITH SYNONYMS ('注文', '売上')
      COMMENT = '注文履歴テーブル（Day18用）'
  )
  DIMENSIONS (
    day18_orders.customer_name AS customer_name
      WITH SYNONYMS ('顧客名', '購入者')
      COMMENT = '顧客名',
    day18_orders.product_category AS product_category
      WITH SYNONYMS ('カテゴリ', '商品分類')
      COMMENT = '商品カテゴリ',
    day18_orders.order_date AS order_date
      COMMENT = '注文日'
  )
  METRICS (
    day18_orders.total_amount AS SUM(day18_orders.amount)
      WITH SYNONYMS ('売上合計', '合計金額')
      COMMENT = '売上金額の合計',
    day18_orders.order_count AS COUNT(day18_orders.order_id)
      WITH SYNONYMS ('注文件数')
      COMMENT = '注文の件数'
  )
  COMMENT = '注文データのセマンティックビュー（Day18トライアル用）';


-- クエリで確認
SELECT * FROM SEMANTIC_VIEW(
  sv_day18_orders
  METRICS total_amount, order_count
  DIMENSIONS customer_name
);