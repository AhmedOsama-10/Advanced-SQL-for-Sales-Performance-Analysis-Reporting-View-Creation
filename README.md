# Advanced SQL for Sales Performance Analysis & Reporting View Creation

---

## 🎯 Project Objective

This project demonstrates the use of **advanced T-SQL** techniques to analyze a sales database, perform complex calculations, and create optimized data views. The primary goal was to move beyond basic reporting to uncover deeper performance trends (like YOY growth) and to segment customers and products.

The final output consists of two clean, pre-aggregated, and analysis-ready **SQL Views** (`gold.customer_report` and `gold.product_report`), designed to be directly consumed by a BI tool like Power BI for efficient visualization.

---

## 🛠️ Key SQL Techniques & Workflow

This script (`Seceond_Project.sql`) performs a sophisticated, multi-step analysis:

### 1. Time-Series Analysis with Window Functions
* **Running Totals:** `SUM(total_sales) OVER (ORDER BY order_date_month)` was used to calculate the cumulative sales growth month-over-month.
* **Moving Averages:** `AVG(Average_line_sales) OVER (ORDER BY order_date)` was used to smooth out daily sales fluctuations and identify clearer trends.
* **Year-over-Year (YOY) Comparison:** The `LAG()` function (e.g., `LAG(total_sales, 12) OVER (ORDER BY sales_date)`) was used to fetch sales data from the same month in the previous year, enabling the calculation of YOY growth percentages.

### 2. Code Structuring with CTEs (Common Table Expressions)
* The script is heavily structured using the `WITH ... AS (...)` syntax.
* **`base_query` CTE:** A foundational CTE was created to join the `fact_sales` table with dimension tables (`dim_products`, `dim_customers`) and select all necessary columns for the analysis.
* **Chained CTEs:** Subsequent CTEs build upon the `base_query` to apply segmentation logic or intermediate calculations before the final aggregation, making the complex logic readable and modular.

### 3. Advanced Segmentation Logic
* **Customer Segmentation:** `CASE WHEN` statements were used to categorize customers into segments like **'VIP'**, **'Regular'**, and **'New'**. This logic was based on metrics calculated per customer, such as total `sales_amount` and customer tenure (lifespan).
* **Product Segmentation:** Similar `CASE WHEN` logic was applied to classify products based on their `cost` into tiers like **'High-Performance'**, **'Mid Range'**, and **'Low-Performance'**.

### 4. Data Aggregation & View Creation
* The final step involved aggregating all metrics using `GROUP BY` clauses for each customer and product.
* Calculated metrics included:
    * `COUNT(DISTINCT order_number)` as total_orders
    * `SUM(sales_amount)` as total_sales
    * `DATEDIFF(month, MIN(order_date), MAX(order_date))` as customer/product lifespan
    * `MAX(order_date)` as last_activity_date
    * `AVG(sales_amount / NULLIF(quantity, 0))` as avg_selling_price
* **Final Output:** This entire logic was encapsulated and saved into two **`CREATE VIEW`** statements:
    1.  `gold.customer_report`
    2.  `gold.product_report`

---

## 💡 Outcome

This project demonstrates proficiency in advanced SQL for data analysis. By creating optimized views, all the heavy computational work (joins, aggregations, window functions) is performed by the database server *before* the data is loaded into a BI tool. This ensures the Power BI dashboard is fast, responsive, and built on a clean, pre-structured "gold layer" of data.

---

## 🔧 Technologies Used
* **SQL (T-SQL / SQL Server)**
* **Advanced SQL Techniques:**
    * Window Functions (`SUM() OVER`, `AVG() OVER`, `LAG()`)
    * Common Table Expressions (CTEs)
    * `CREATE VIEW`
    * `CASE WHEN` (for segmentation)
    * Advanced Joins (`LEFT JOIN`)
    * Aggregate Functions (`SUM`, `COUNT`, `AVG`, `MIN`, `MAX`, `DATEDIFF`)
