use DataWarehouseAnalytics;
GO
-- Sales Performance over time
select
Year(order_date) as sales_by_year,
month(order_date) as sales_by_month,
sum(quantity) as quantity,
count(distinct customer_key) as customers_count,
sum(sales_amount) as total_sales 
from gold.fact_sales
where order_date is not null
group by Year(order_date) , month(order_date)
order by Year(order_date) , month(order_date);

GO
-- Calculate the total sales and the runnig total over time
select total_sales,order_date_month,sum(total_sales) over(order by order_date_month) as runnig_total
from 
(select 
sum(sales_amount) as total_sales,
MONTH(order_date) as order_date_month
from gold.fact_sales
where order_date is not null
group by MONTH(order_date)
)t;
GO
-- Calculate the total sales and the runnig total and runnig average over time
select
order_date,
total_sales,
Average_line_sales,
SUM(total_sales) over(order by order_date ) AS Runnig_totals_year,
AVG(Average_line_sales) over(order by order_date ) AS Moving_Average_year
from
(select 
YEAR(order_date) as order_date,
AVG(sales_amount) as Average_line_sales,
SUM(sales_amount) as total_sales
from gold.fact_sales
where order_date is not null
group by YEAR(order_date))f;
GO
select  order_year,product_name ,current_sales ,
avg(current_sales) over(partition by product_name ) as average_sales,
current_sales - avg(current_sales) over(partition by product_name ) as diff_average,
CASE WHEN current_sales - avg(current_sales) over(partition by product_name)> 0 then 'Above Average'
	WHEN current_sales - avg(current_sales) over(partition by product_name) < 0 then 'Below Average'
	ELSE 'Average' END AS performance
from
(select YEAR(f.order_date) as order_year ,p.product_name, sum(f.sales_amount) as current_sales

from gold.fact_sales f
left join gold.dim_products p
on p.product_key = f.product_key

where order_date is not null
group by p.product_name , YEAR(f.order_date)
) x;

GO
/* Analyze the yearly performance of products by comparing their sales
to both the average sales performance of the product and the previous year's sales */

with sales AS(
select YEAR(f.order_date) as order_year , p.product_name , sum(f.sales_amount) as current_sales
from gold.fact_sales f
left join gold.dim_products p
on p.product_key = f.product_key
where order_date is not null
group by p.product_name ,YEAR(f.order_date))
,
ranking AS(
select order_year , product_name , current_sales ,
AVG(current_sales) over(partition by product_name) as average_sales
from sales)

select order_year , product_name , current_sales , average_sales,
current_sales - average_sales as diff_average ,
-- YOY Change
LAG(current_sales) over(partition by product_name order by order_year) as previous_year,
current_sales - LAG(current_sales) over(partition by product_name order by order_year) as diff_last_year
,
CASE WHEN current_sales - average_sales > 0 then 'Above Average'
	WHEN current_sales - average_sales < 0 then 'Below Average'	
	ELSE 'Average' END AS Performance,
CASE WHEN current_sales - LAG(current_sales) over(partition by product_name order by order_year) > 0 then 'Increasing'
	WHEN current_sales - LAG(current_sales) over(partition by product_name order by order_year) < 0 then 'Decreasing'	
	ELSE 'No Change' END AS Performance_year
from ranking
order by product_name , order_year;
GO
--- which category contributes the most of sales overall

select  category , total_sales ,
sum(total_sales) over() as overall_sales,
CONCAT(ROUND(CAST(total_sales AS FLOAT) / sum(total_sales) over() * 100,2),'%') AS percent_of_total

from(

select p.category , sum(f.sales_amount) as total_sales
from gold.fact_sales f
left join gold.dim_products p
on p.product_key = f.product_key
group by p.category

)
t
order by total_sales DESC;

GO
-- Segement products into cost ranges and count how many products fall into each segemnt
WITH products_segement AS (
select product_key
, product_name 
, cost,
CASE WHEN cost < 100 THEN 'Below 100'
	WHEN cost 	BETWEEN 100 AND 500 THEN '100-500'
	WHEN cost 	BETWEEN 500 AND 1000 THEN '500-1000'
	WHEN cost 	BETWEEN 1000 AND 1500 THEN '1000-1500'
	ELSE 'Above 1500' 
END cost_range
from gold.dim_products)

select cost_range , count(product_name) AS total_products 
from products_segement
group by cost_range
order by total_products DESC;

/*Group customers into three segments based on their spending behavior:
- VIP: Customers with at least 12 months of history and spending more than €5,000.
- Regular: Customers with at least 12 months of history but spending €5,000 or less.
- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/
GO
WITH customer_segments AS(
select c.customer_key,
		sum(f.sales_amount) as total_spend,
		datediff(MONTH,MIN(f.order_date),MAX(f.order_date) )as lifespan 
		

from gold.fact_sales f
left join gold.dim_customers c
on f.customer_key = c.customer_key
where f.order_date is not null
group by c.customer_key)

select count(customer_key) as total_customers , customer_segment 
from
(
select customer_key , total_spend , lifespan,
case when total_spend >  5000 and lifespan >= 12 then 'VIP'
	when total_spend < = 5000 and lifespan >=12 then 'Regular'
	ELSE 'New' 
	END AS customer_segment
from customer_segments)s
group by customer_segment
order by total_customers DESC;

GO

/*

Customer Report
Purpose:
	- This report consolidates key customer metrics and behaviors
Highlights:
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend

*/
GO
CREATE VIEW gold.customer_report AS

WITH BASE_TABLE AS(
-- Base Query retrevies core columns from tables
select
	
	f.order_date,
	f.order_number,
	f.sales_amount,
	f.quantity,
	f.product_key,
	c.customer_key,
	c.customer_number,
	CONCAT(c.first_name,' ',c.last_name) AS Customer_name,
	DATEDIFF(year,c.birthdate,GETDATE()) AS Age

from
	gold.fact_sales f
left join
	gold.dim_customers c
on f.customer_key = c.customer_key
where 
	order_date is not null
	),

customer_segment AS (
select 

	customer_key,
	customer_name,
	customer_number,
	age,
	count(DISTINCT(order_number)) as total_orders,
	sum(sales_amount) as total_sales,
	sum(quantity) as total_qnatity,
	count(DISTINCT(product_key)) as total_products,
	MAX(order_date) as last_order_date,
	datediff(MONTH,MIN(order_date),MAX(order_date) )as lifespan

from
	BASE_TABLE
group by
	customer_key,
	customer_name,
	customer_number,
	age
)

select 
customer_key,
customer_name,
customer_number,
age,
case when age < 20 then 'Under 20'
	when age between 20 and 29 then '20-29'
	when age between 30 and 39 then '30-39' 
	when age between 40 and 49 then '40-49'
	else 'Above 50' END AS age_group,
case when total_sales >  5000 and lifespan >= 12 then 'VIP'
	when total_sales < = 5000 and lifespan >=12 then 'Regular'
	ELSE 'New' 
	END AS customer_segment,
DATEDIFF(month,last_order_date,getdate()) as recency,
total_orders,
total_sales,
total_qnatity,
total_products,
last_order_date,
lifespan,
CASE when total_sales = 0 then 0
	else total_sales / total_orders
	end as Average_order_value,
CASE when lifespan  = 0 then total_sales
	else total_sales / lifespan
	end as Average_monthly_sprnding

from customer_segment ;

select * from gold.customer_report;


/*
Product Report
======================================================================
Purpose:
- This report consolidates key product metrics and behaviors.

Highlights:
1. Gathers essential fields such as product name, category, subcategory, and cost.
2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
3. Aggregates product-level metrics:
   - total orders
   - total sales
   - total quantity sold
   - total customers (unique)
   - lifespan (in months)
4. Calculates valuable KPIs:
   - recency (months since last sale)
   - average order revenue (AOR)
   - average monthly revenue
*/


-- Base Query retrevies core columns from tables
GO
CREATE VIEW gold.product_report AS

WITH base_query as (
select
	
	f.order_date,
	f.order_number,
	f.sales_amount,
	f.quantity,
	f.customer_key,
	p.product_key,
	p.product_name,
	p.subcategory,
	p.category,
	p.cost
	

from
	gold.fact_sales f
left join
	gold.dim_products p
on f.product_key = p.product_key
where 
	order_date is not null
	),
second_query AS(
select
product_key,
product_name,
subcategory,
category,
cost,
COUNT(distinct(customer_key)) as total_customers,
count(distinct(order_number)) as total_orders,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity,
DATEDIFF(month,min(order_date),max(order_date)) as lifespan,
MAX(order_date) as last_sale_date,
ROUND(AVG(CAST(sales_amount AS float) / nullif(quantity,0)),2) as avg_selling_price
from base_query
group by
product_key,
product_name,
subcategory,
category,
cost
)
select
product_key,
product_name,
subcategory,
category,
cost,

CASE WHEN total_sales > 50000 THEN 'High-Performance'
	WHEN total_sales >=10000 THEN 'Mid Range'
	ELSE 'LOW-Performance' END AS product_segment,
total_sales,
total_orders,
lifespan,
total_quantity,
total_customers,
avg_selling_price,
CASE when total_sales = 0 then 0
	else total_sales / total_orders
	end as Average_order_revenue,
CASE when lifespan  = 0 then total_sales
	else total_sales / lifespan
	end as Average_monthly_revenue
from second_query
;