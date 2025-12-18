# SQL & R Cohort and RFM Analysis

## Overview
This project analyzes customer behavior for an e-commerce business using SQL and R.
The goal is to understand customer retention, revenue patterns over time, and customer value segmentation.

## Tools Used
- DuckDB (SQL analytics database)
- SQL (CTEs, aggregations, cohort analysis)
- R (tidyverse, ggplot2)

## Key Analyses
- Cohort retention analysis based on first purchase month
- Revenue by cohort to evaluate lifetime value trends
- RFM segmentation to identify high-value, loyal, and at-risk customers

## Key Insights
- Customer retention declines sharply after the first month and stabilizes into a long-tail pattern
- Revenue contribution varies across cohorts, suggesting differences in acquisition quality
- A small segment of customers drives a disproportionate share of total revenue

## Files
- `01_setup_and_load_duckdb.R`: Loads data and initializes DuckDB
- `02_cohort_retention.R`: Cohort analysis, revenue analysis, and RFM segmentation
