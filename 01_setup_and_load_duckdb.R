# -------------------------------
# Project 2 - Step 1: Setup + Load DuckDB
# -------------------------------

# Install packages if needed (run once)
pkgs <- c("DBI", "duckdb", "tidyverse", "lubridate", "janitor", "glue")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)

library(DBI)
library(duckdb)
library(tidyverse)
library(lubridate)
library(janitor)
library(glue)

# Make sure we're in the project folder
getwd()

# Connect to DuckDB database file (will be created in your folder)
con <- dbConnect(duckdb::duckdb(), dbdir = "project2.duckdb", read_only = FALSE)

# Load CSVs into DuckDB tables (overwrite if rerun)
dbExecute(con, "DROP TABLE IF EXISTS customers;")
dbExecute(con, "DROP TABLE IF EXISTS orders;")
dbExecute(con, "DROP TABLE IF EXISTS order_items;")

dbExecute(con, "CREATE TABLE customers AS SELECT * FROM read_csv_auto('customers.csv');")
dbExecute(con, "CREATE TABLE orders AS SELECT * FROM read_csv_auto('orders.csv');")
dbExecute(con, "CREATE TABLE order_items AS SELECT * FROM read_csv_auto('order_items.csv');")

# Quick checks: row counts
counts <- dbGetQuery(con, "
  SELECT 'customers' AS table_name, COUNT(*) AS n FROM customers
  UNION ALL
  SELECT 'orders' AS table_name, COUNT(*) AS n FROM orders
  UNION ALL
  SELECT 'order_items' AS table_name, COUNT(*) AS n FROM order_items;
")
print(counts)

# Peek at schemas
schema_customers <- dbGetQuery(con, "DESCRIBE customers;")
schema_orders <- dbGetQuery(con, "DESCRIBE orders;")
schema_items <- dbGetQuery(con, "DESCRIBE order_items;")

print(schema_customers)
print(schema_orders)
print(schema_items)



