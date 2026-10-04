use database sandbox;
CREATE OR REPLACE TABLE car_sales
( 
  src variant
)
AS
SELECT PARSE_JSON(column1) AS src
FROM VALUES
('{ 
    "date" : "2017-04-28", 
    "dealership" : "Valley View Auto Sales",
    "salesperson" : {
      "id": "55",
      "name": "Frank Beasley"
    },
    "customer" : [
      {"name": "Joyce Ridgely", "phone": "16504378889", "address": "San Francisco, CA"}
    ],
    "vehicle" : [
      {"make": "Honda", "model": "Civic", "year": "2017", "price": "20275", "extras":["ext warranty", "paint protection"]}
    ]
}'),
('{ 
    "date" : "2017-04-28", 
    "dealership" : "Tindel Toyota",
    "salesperson" : {
      "id": "274",
      "name": "Greg Northrup"
    },
    "customer" : [
      {"name": "Bradley Greenbloom", "phone": "12127593751", "address": "New York, NY"}
    ],
    "vehicle" : [
      {"make": "Toyota", "model": "Camry", "year": "2017", "price": "23500", "extras":["ext warranty", "rust proofing", "fabric protection"]}  
    ]
}') ;

-- かっこ表記¶
SELECT src['salesperson']['name']
    FROM car_sales
    ORDER BY 1;


-- 繰り返し要素の単一インスタンスの取得¶
SELECT src:customer[0].name, src:vehicle[0]
    FROM car_sales
    ORDER BY 1;

-- 明示的なキャスト
SELECT src:vehicle[0].price::NUMBER * 0.10 AS tax
    FROM car_sales
    ORDER BY tax;

-- キャストしたときとそうでないときの違い
SELECT src:dealership, src:dealership::VARCHAR
    FROM car_sales
    ORDER BY 2;

-- WHERE 句での FLATTEN を使用した結果のフィルター処理¶
CREATE OR REPLACE TABLE pets (v variant);

INSERT INTO pets SELECT PARSE_JSON ('{"species":"dog", "name":"Fido", "is_dog":"true"} ');
INSERT INTO pets SELECT PARSE_JSON ('{"species":"cat", "name":"Bubby", "is_dog":"false"}');
INSERT INTO pets SELECT PARSE_JSON ('{"species":"cat", "name":"dog terror", "is_dog":"false"}');

SELECT a.v, b.key, b.value FROM pets a,LATERAL FLATTEN(input => a.v) b
WHERE b.value LIKE '%dog%';

---------------------------

-- 準備: JSONを持つ一時テーブルを作る(order 3 は items が空配列)
CREATE OR REPLACE TEMPORARY TABLE orders_raw AS
SELECT PARSE_JSON('{"order_id":1,"customer":{"name":"Aiko","country":"JP"},"items":[{"sku":"A1","qty":2,"price":500},{"sku":"B2","qty":1,"price":1200}]}') AS v
UNION ALL
SELECT PARSE_JSON('{"order_id":2,"customer":{"name":"Ben","country":"US"},"items":[{"sku":"A1","qty":5,"price":500}]}')
UNION ALL
SELECT PARSE_JSON('{"order_id":3,"customer":{"name":"Chie","country":"JP"},"items":[]}');


select * from orders_raw;


-- ① コロン記法とキャスト: キャストなしの値は引用符付きのVARIANT
SELECT
  v:customer.name AS name_variant,
  TYPEOF(v:customer.name) AS name_type,
  v:customer.name::STRING AS name_str,
  v['customer']['country']::STRING AS country,
  v:order_id::NUMBER AS order_id
FROM orders_raw;


-- ② FLATTEN: items を1行1明細に展開(order 3 は消える)
SELECT
  o.v:order_id::NUMBER AS order_id,
  i.index AS item_index,
  i.value:sku::STRING AS sku,
  i.value:qty::NUMBER AS qty,
  i.value:price::NUMBER AS price
FROM orders_raw o, LATERAL FLATTEN(INPUT => o.v:items) i;

-- ②' OUTER => TRUE: 空配列の order 3 も NULL 行で残る
SELECT
  o.v:order_id::NUMBER AS order_id,
  i.value:sku::STRING AS sku
FROM orders_raw o, LATERAL FLATTEN(INPUT => o.v:items, OUTER => TRUE) i;

-- ③ RECURSIVE: キーとパスを全部出す(中身の分からないJSONを調べるとき)
SELECT f.path, f.key, TYPEOF(f.value) AS value_type
FROM orders_raw o, LATERAL FLATTEN(INPUT => o.v, RECURSIVE => TRUE) f
WHERE o.v:order_id::NUMBER = 1;


-- 以降の検証用に、明細を一時ビューにする
CREATE OR REPLACE TEMPORARY VIEW order_lines AS
SELECT
  o.v:order_id::NUMBER AS order_id,
  o.v:customer.country::STRING AS country,
  i.value:sku::STRING AS sku,
  i.value:qty::NUMBER * i.value:price::NUMBER AS amount
FROM orders_raw o, LATERAL FLATTEN(INPUT => o.v:items) i;

select * from order_lines;

-- ④ 集計関数: 国ごとに1行に畳まれる
SELECT country, SUM(amount) AS total
FROM order_lines
GROUP BY country;

-- ④' ウィンドウ関数: 行数は変わらず、各行に国別合計と累計が付く
SELECT
  order_id, country, sku, amount,
  SUM(amount) OVER (PARTITION BY country) AS country_total,
  SUM(amount) OVER (ORDER BY order_id, sku ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM order_lines
ORDER BY order_id, sku;

-- ⑤ 同点の扱い: ROW_NUMBER / RANK / DENSE_RANK を並べて比較
WITH s AS (
  SELECT * FROM VALUES ('A', 100), ('B', 90), ('C', 90), ('D', 80) AS t(name, score)
)
SELECT
  name, score,
  ROW_NUMBER() OVER (ORDER BY score DESC) AS rn,
  RANK() OVER (ORDER BY score DESC) AS rk,
  DENSE_RANK() OVER (ORDER BY score DESC) AS drk
FROM s
ORDER BY score DESC, name;

-- ⑥ LAG と QUALIFY
SELECT order_id, sku, amount,
  LAG(amount) OVER (ORDER BY order_id, sku) AS prev_amount
FROM order_lines
ORDER BY order_id, sku;

-- 国ごとに金額が最大の明細を1件だけ
SELECT country, order_id, sku, amount
FROM order_lines
QUALIFY ROW_NUMBER() OVER (PARTITION BY country ORDER BY amount DESC) = 1;


-- ⑦ 近似集計: 厳密値と近似値を比べる(サンプルデータは読み取り専用でOK)
SELECT
  COUNT(DISTINCT l_orderkey) AS exact_cnt,
  APPROX_COUNT_DISTINCT(l_orderkey) AS approx_cnt
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

-- ⑧ ディレクトリテーブルとURL
CREATE OR REPLACE STAGE doc_stage
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');