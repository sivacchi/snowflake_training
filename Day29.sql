-- 準備: 自分のユーザー名を確認
SELECT CURRENT_USER();

USE ROLE SYSADMIN;
CREATE OR REPLACE DATABASE rbac_db;
CREATE OR REPLACE SCHEMA rbac_db.sales;
CREATE OR REPLACE TABLE rbac_db.sales.orders (id NUMBER, amount NUMBER);
INSERT INTO rbac_db.sales.orders VALUES (1, 100), (2, 200);

-- ① 所有者を確認する(DAC): OWNERSHIP を持つのは SYSADMIN
SHOW GRANTS ON TABLE rbac_db.sales.orders;

-- ロールを作り、自分に付与する
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS analyst_r;
CREATE ROLE IF NOT EXISTS sales_admin_r;
GRANT ROLE analyst_r TO USER sivacchi;
GRANT ROLE sales_admin_r TO USER sivacchi;
GRANT USAGE ON WAREHOUSE wh_bi TO ROLE analyst_r;
GRANT SELECT ON TABLE rbac_db.sales.orders TO ROLE analyst_r;

-- セカンダリロールを無効にする
SELECT CURRENT_SECONDARY_ROLES();
USE SECONDARY ROLES NONE;

-- ② USAGE がないと読めない
USE ROLE analyst_r;
USE WAREHOUSE wh_bi;
SELECT * FROM rbac_db.sales.orders;
-- エラーになる想定: テーブルの SELECT はあるが、データベースとスキーマの USAGE がない

USE ROLE SECURITYADMIN;
GRANT USAGE ON DATABASE rbac_db TO ROLE analyst_r;
GRANT USAGE ON SCHEMA rbac_db.sales TO ROLE analyst_r;

USE ROLE analyst_r;
SELECT * FROM rbac_db.sales.orders;   -- 成功する
INSERT INTO rbac_db.sales.orders VALUES (3, 300);   -- エラーになる想定: INSERT 権限がない

-- ③ DAC: 所有者でないロールは GRANT できない
USE ROLE analyst_r;
GRANT SELECT ON TABLE rbac_db.sales.orders TO ROLE sales_admin_r;
-- エラーになる想定: analyst_r は SELECT を持つだけで、所有者ではない

-- ④ ロール階層: 下のロールの権限を上のロールが継承する
USE ROLE SECURITYADMIN;
GRANT ROLE analyst_r TO ROLE sales_admin_r;
GRANT ROLE sales_admin_r TO ROLE SYSADMIN;

USE ROLE sales_admin_r;
SELECT * FROM rbac_db.sales.orders;   -- 成功する(analyst_r の権限を継承)
SHOW GRANTS TO ROLE sales_admin_r;    -- 直接付いているのは analyst_r というロールだけ

-- ⑤ 将来のグラント: 新しく作るテーブルにも自動で権限が付く
USE ROLE SECURITYADMIN;
GRANT SELECT ON FUTURE TABLES IN SCHEMA rbac_db.sales TO ROLE analyst_r;
SHOW FUTURE GRANTS IN SCHEMA rbac_db.sales;

USE ROLE SYSADMIN;
CREATE TABLE rbac_db.sales.customers (id NUMBER);
SHOW GRANTS ON TABLE rbac_db.sales.customers;   -- analyst_r に SELECT が付いている


-- ⑥ (余裕があれば) 所有権の移転
USE ROLE SYSADMIN;
GRANT OWNERSHIP ON TABLE rbac_db.sales.orders TO ROLE sales_admin_r;
-- エラーになる想定(記憶ベース): 既に付与済みの権限(analyst_r の SELECT)があるため
GRANT OWNERSHIP ON TABLE rbac_db.sales.orders TO ROLE sales_admin_r COPY CURRENT GRANTS;
SHOW GRANTS ON TABLE rbac_db.sales.orders;   -- OWNERSHIP が sales_admin_r に移っている

-- 後片付け
USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS rbac_db;
USE ROLE SECURITYADMIN;
DROP ROLE IF EXISTS sales_admin_r;
DROP ROLE IF EXISTS analyst_r;