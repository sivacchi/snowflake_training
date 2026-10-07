USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS sec_db;
CREATE SCHEMA IF NOT EXISTS sec_db.net;
USE SCHEMA sec_db.net

-- ① ネットワークルールを作る(許可用とブロック用)。公式の例と同じ形
CREATE OR REPLACE NETWORK RULE allow_office
  MODE = INGRESS
  TYPE = IPV4
  VALUE_LIST = ('192.168.1.0/24')
  COMMENT = 'Day30 test: allow a range';
CREATE OR REPLACE NETWORK RULE block_one
  MODE = INGRESS
  TYPE = IPV4
  VALUE_LIST = ('192.168.1.99')
  COMMENT = 'Day30 test: block one address';
SHOW NETWORK RULES IN SCHEMA sec_db.net;
-- ルールは「スキーマ内のオブジェクト」。この時点では、許可か拒否かは決まっていない


-- ② ネットワークポリシーを作る。ルールを許可リストとブロックリストに入れる
CREATE OR REPLACE NETWORK POLICY day30_policy
  ALLOWED_NETWORK_RULE_LIST = ('allow_office')
  BLOCKED_NETWORK_RULE_LIST = ('block_one');
SHOW NETWORK POLICIES;
DESC NETWORK POLICY day30_policy;
-- 「192.168.1.0/24 を許可し、192.168.1.99 だけブロック」の意味になる  

-- ③ テスト用ユーザーを作り、ポリシーをユーザー単位で有効化する(自分には影響しない)
CREATE USER IF NOT EXISTS day30_test_user TYPE = SERVICE;
ALTER USER day30_test_user SET NETWORK_POLICY = day30_policy;
SHOW PARAMETERS LIKE 'network_policy' IN USER day30_test_user;
-- ここで、ポリシーは「作っただけ」から「有効化」に変わった(このユーザーにだけ)

-- ④ アカウントには何が付いているか、見るだけ(変更はしない)
SHOW PARAMETERS LIKE 'network_policy' IN ACCOUNT;
-- 空なら、アカウントにはネットワークポリシーが付いていない

-- ⑤ MFA: 自分のMFA方法を確認する(見るだけ)。<自分のユーザー名> は SELECT CURRENT_USER(); の結果
SHOW MFA METHODS FOR USER <自分のユーザー名>;
-- passkey / TOTP / Duo のどれを登録しているか。何も出なければ、MFAを登録していない


-- ⑥キーペア認証
-- 公開鍵ファイルの中身から、-----BEGIN/END----- の行を除いた本文だけを貼る
USE ROLE ACCOUNTADMIN;
ALTER USER day30_test_user SET RSA_PUBLIC_KEY = '<rsa_key1.pub の本文>';
DESC USER day30_test_user;   -- RSA_PUBLIC_KEY_FP(フィンガープリント)が出る(記憶ベース)

-- ローテーション: 使っていない方のスロットに2本目を入れる
ALTER USER day30_test_user SET RSA_PUBLIC_KEY_2 = '<rsa_key2.pub の本文>';
DESC USER day30_test_user;   -- 2本分のフィンガープリントが出る(記憶ベース)

-- 古い方を外す
ALTER USER day30_test_user UNSET RSA_PUBLIC_KEY;
DESC USER day30_test_user;

-- ⑦認証ポリシーをテスト用ユーザーに付ける
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE AUTHENTICATION POLICY sec_db.net.day30_auth_policy
  AUTHENTICATION_METHODS = ('KEYPAIR');
ALTER USER day30_test_user SET AUTHENTICATION POLICY sec_db.net.day30_auth_policy;
SHOW AUTHENTICATION POLICIES;

-- ⑧片付け
USE ROLE ACCOUNTADMIN;
ALTER USER day30_test_user UNSET NETWORK_POLICY;
ALTER USER day30_test_user UNSET AUTHENTICATION POLICY;
DROP USER IF EXISTS day30_test_user;
DROP NETWORK POLICY IF EXISTS day30_policy;
DROP DATABASE IF EXISTS sec_db;

