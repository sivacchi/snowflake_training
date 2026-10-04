show warehouses;

show tables;

SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN ACCOUNT;

create or replace table USER$SIVACCHI.PUBLIC.TEST_TABLE (
  id INT
  ,name string
);

CREATE DATABASE IF NOT EXISTS SANDBOX;

CREATE TABLE SANDBOX.PUBLIC.TEST_TABLE (
    id INT,
    name STRING
);

INSERT INTO SANDBOX.PUBLIC.TEST_TABLE VALUES
    (1, 'apple'),
    (2, 'banana');


select
id
,name
from sandbox.public.test_table;

alter table sandbox.public.test_table
set DATA_RETENTION_TIME_IN_DAYS = 90;

show tables

SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE(), CURRENT_ROLE();