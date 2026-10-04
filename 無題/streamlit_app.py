import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()
st.title("注文ステータス別件数")

df = (session.table("SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS")
      .group_by("O_ORDERSTATUS").count().to_pandas())

st.bar_chart(df, x="O_ORDERSTATUS", y="COUNT")