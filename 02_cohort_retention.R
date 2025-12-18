# -----------------------------------------
# Project 2 - Cohort Retention (DuckDB + SQL)
# -----------------------------------------

library(DBI)
library(duckdb)
library(tidyverse)
library(lubridate)

# 1) Connect to the DuckDB database file in this project folder
con <- dbConnect(duckdb::duckdb(), dbdir = "project2.duckdb", read_only = FALSE)

# 2) Connection check: make sure tables exist
dbGetQuery(con, "SELECT 1 AS ok;")
dbListTables(con)

# 3) Build cohort retention table in SQL
cohort_retention <- dbGetQuery(con, "
WITH customer_first_order AS (
  SELECT
    customer_id,
    MIN(order_date) AS first_order_date
  FROM orders
  GROUP BY customer_id
),
orders_with_cohort AS (
  SELECT
    o.customer_id,
    DATE_TRUNC('month', cfo.first_order_date) AS cohort_month,
    DATE_TRUNC('month', o.order_date)        AS order_month
  FROM orders o
  JOIN customer_first_order cfo
    ON o.customer_id = cfo.customer_id
),
cohort_activity AS (
  SELECT
    cohort_month,
    DATE_DIFF('month', cohort_month, order_month) AS month_number,
    COUNT(DISTINCT customer_id) AS active_customers
  FROM orders_with_cohort
  GROUP BY cohort_month, month_number
),
cohort_sizes AS (
  SELECT
    cohort_month,
    active_customers AS cohort_size
  FROM cohort_activity
  WHERE month_number = 0
)
SELECT
  ca.cohort_month,
  ca.month_number,
  cs.cohort_size,
  ca.active_customers,
  ROUND((ca.active_customers * 1.0) / cs.cohort_size, 4) AS retention_rate
FROM cohort_activity ca
JOIN cohort_sizes cs
  ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month, ca.month_number;
")

# 4) Quick sanity checks
print(head(cohort_retention, 20))

cohort_retention %>%
  group_by(month_number) %>%
  summarise(avg_retention = mean(retention_rate), .groups = "drop") %>%
  arrange(month_number) %>%
  print()

# A) Prepare data for a heatmap
# - Format cohort_month nicely (YYYY-MM)
# - Keep month_number as an integer
# - Keep retention as numeric
heatmap_df <- cohort_retention %>%
  mutate(
    cohort_month = as.Date(cohort_month),
    cohort_label = format(cohort_month, "%Y-%m"),
    month_number = as.integer(month_number),
    retention_rate = as.numeric(retention_rate)
  )

# Optional: limit to first 12 months for a cleaner first chart
heatmap_df_12 <- heatmap_df %>%
  filter(month_number <= 12)

# B) Heatmap (tiles)
retention_heatmap <- ggplot(heatmap_df_12, aes(x = month_number, y = cohort_label, fill = retention_rate)) +
  geom_tile() +
  labs(
    title = "Cohort Retention Heatmap",
    subtitle = "Retention rate by cohort month and months since first purchase",
    x = "Months since first purchase (month_number)",
    y = "Cohort month",
    fill = "Retention"
  ) +
  theme_minimal()

print(retention_heatmap)

# A) Revenue by cohort and month_number (SQL does the heavy lifting)
cohort_revenue <- dbGetQuery(con, "
WITH customer_first_order AS (
  SELECT
    customer_id,
    MIN(order_date) AS first_order_date
  FROM orders
  GROUP BY customer_id
),
orders_with_cohort AS (
  SELECT
    o.customer_id,
    DATE_TRUNC('month', cfo.first_order_date) AS cohort_month,
    DATE_TRUNC('month', o.order_date)        AS order_month,
    o.net_revenue
  FROM orders o
  JOIN customer_first_order cfo
    ON o.customer_id = cfo.customer_id
)
SELECT
  cohort_month,
  DATE_DIFF('month', cohort_month, order_month) AS month_number,
  SUM(net_revenue) AS total_revenue
FROM orders_with_cohort
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;
")

# B) Inspect the result
head(cohort_revenue, 10)

# C) Plot revenue curves (LTV-style)
library(scales)
cohort_revenue_plot <- cohort_revenue %>%
  mutate(
    cohort_label = format(as.Date(cohort_month), "%Y-%m")
  )

y_max <- quantile(cohort_revenue_plot$total_revenue, 0.99, na.rm = TRUE)

ggplot(cohort_revenue_plot, aes(x = month_number, y = total_revenue, color = cohort_label)) +
  geom_line() +
  scale_y_continuous(labels = scales::dollar_format()) +
  coord_cartesian(ylim = c(0, y_max)) +
  labs(
    title = "Revenue by Cohort Over Time",
    subtitle = "Monthly revenue contribution by customer cohort (zoomed to 99th percentile)",
    x = "Months since first purchase",
    y = "Total revenue",
    color = "Cohort"
  ) +
  theme_minimal()

# -------------------------
# Step: RFM Segmentation
# -------------------------

library(DBI)
library(duckdb)
library(tidyverse)
library(lubridate)

con <- dbConnect(duckdb::duckdb(), dbdir = "project2.duckdb", read_only = FALSE)

rfm_raw <- dbGetQuery(con, "
SELECT
  customer_id,

  -- Recency: days since last purchase
  DATE_DIFF('day', MAX(order_date), CURRENT_DATE) AS recency_days,

  -- Frequency: total number of orders
  COUNT(order_id) AS frequency,

  -- Monetary: total spend
  SUM(net_revenue) AS monetary

FROM orders
GROUP BY customer_id;
")

summary(rfm_raw)
head(rfm_raw)

rfm_scores <- rfm_raw %>%
  mutate(
    R = ntile(-recency_days, 5),  # smaller recency = better
    F = ntile(frequency, 5),
    M = ntile(monetary, 5)
  ) %>%
  mutate(
    RFM_Score = paste0(R, F, M)
  )

rfm_segments %>%
  count(segment) %>%
  arrange(desc(n))

rfm_segments <- rfm_scores %>%
  mutate(
    segment = case_when(
      R >= 4 & F >= 4 & M >= 4 ~ "Champions",
      R >= 3 & F >= 3 & M >= 3 ~ "Loyal Customers",
      R <= 2 & F >= 3 ~ "At Risk",
      R <= 2 & F <= 2 ~ "Hibernating",
      TRUE ~ "Potential"
    )
  )

ggplot(rfm_segments, aes(x = segment)) +
  geom_bar(fill = "steelblue") +
  labs(
    title = "Customer Distribution by RFM Segment",
    x = "Customer Segment",
    y = "Number of Customers"
  ) +
  theme_minimal()

# Close connection when done
# dbDisconnect(con, shutdown = TRUE)
