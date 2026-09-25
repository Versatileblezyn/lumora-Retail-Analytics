-- LUMORA RETAIL ANALYTICS | SQL PORTFOLIO ANALYSIS
-- PostgreSQL / pgAdmin | Synthetic 2025 dataset

-- 1. DATA QUALITY CHECKS
SELECT COUNT(*) AS total_rows,
       COUNT(*) - COUNT(store_id) AS missing_store,
       COUNT(*) - COUNT(product_id) AS missing_product,
       COUNT(*) - COUNT(customer_id) AS missing_customer,
       COUNT(*) - COUNT(quantity) AS missing_quantity,
       COUNT(*) - COUNT(unit_price) AS missing_unit_price,
       COUNT(*) - COUNT(payment_method) AS missing_payment_method
FROM sales;

SELECT COUNT(*) FILTER (WHERE quantity <= 0) AS invalid_quantity,
       COUNT(*) FILTER (WHERE unit_price <= 0) AS invalid_unit_price,
       COUNT(*) FILTER (WHERE discount_pct IS NOT NULL AND (discount_pct < 0 OR discount_pct > 100)) AS invalid_discount
FROM sales;

-- 2. OVERALL BUSINESS PERFORMANCE
SELECT COUNT(*) AS total_transactions,
       SUM(quantity) AS total_units_sold,
       ROUND(SUM(quantity * unit_price * (1 - COALESCE(discount_pct,0)/100)),2) AS total_revenue,
       ROUND(SUM(quantity * unit_price * (1 - COALESCE(discount_pct,0)/100))/COUNT(*),2) AS average_transaction_value,
       ROUND(SUM(quantity * (unit_price * (1 - COALESCE(discount_pct,0)/100) - p.cost_price)),2) AS gross_profit,
       ROUND(100 * SUM(quantity * (unit_price * (1 - COALESCE(discount_pct,0)/100) - p.cost_price)) /
             NULLIF(SUM(quantity * unit_price * (1 - COALESCE(discount_pct,0)/100)),0),2) AS gross_profit_margin
FROM sales s JOIN products p ON s.product_id=p.product_id;

-- 3. PRODUCT PERFORMANCE
SELECT p.product_name,
       SUM(s.quantity) AS units_sold,
       ROUND(SUM(s.quantity*s.unit_price*(1-COALESCE(s.discount_pct,0)/100)),2) AS revenue,
       ROUND(SUM(s.quantity*(s.unit_price*(1-COALESCE(s.discount_pct,0)/100)-p.cost_price)),2) AS gross_profit
FROM sales s JOIN products p ON s.product_id=p.product_id
GROUP BY p.product_id,p.product_name ORDER BY gross_profit DESC;

-- 4. STORE PERFORMANCE
SELECT st.store_name, COUNT(*) AS transactions, SUM(s.quantity) AS units_sold,
       ROUND(SUM(s.quantity*s.unit_price*(1-COALESCE(s.discount_pct,0)/100)),2) AS revenue,
       ROUND(SUM(s.quantity*(s.unit_price*(1-COALESCE(s.discount_pct,0)/100)-p.cost_price)),2) AS gross_profit
FROM sales s JOIN stores st ON s.store_id=st.store_id JOIN products p ON s.product_id=p.product_id
GROUP BY st.store_id,st.store_name ORDER BY revenue DESC;

-- 5. CATEGORY PERFORMANCE
SELECT p.category, SUM(s.quantity) AS units_sold,
       ROUND(SUM(s.quantity*s.unit_price*(1-COALESCE(s.discount_pct,0)/100)),2) AS revenue,
       ROUND(SUM(s.quantity*(s.unit_price*(1-COALESCE(s.discount_pct,0)/100)-p.cost_price)),2) AS gross_profit
FROM sales s JOIN products p ON s.product_id=p.product_id
GROUP BY p.category ORDER BY revenue DESC;

-- 6. CUSTOMER PERFORMANCE
SELECT c.customer_id,c.customer_name,COUNT(*) AS transactions,SUM(s.quantity) AS units_sold,
       ROUND(SUM(s.quantity*s.unit_price*(1-COALESCE(s.discount_pct,0)/100)),2) AS revenue
FROM sales s JOIN customers c ON s.customer_id=c.customer_id
GROUP BY c.customer_id,c.customer_name ORDER BY revenue DESC LIMIT 10;

-- 7. DISCOUNT ANALYSIS
-- NULL discount means no discount was recorded; COALESCE is used for calculations.
SELECT COALESCE(s.discount_pct,0) AS discount_rate, COUNT(*) AS transactions, SUM(s.quantity) AS units_sold,
       ROUND(SUM(s.quantity*s.unit_price*(1-COALESCE(s.discount_pct,0)/100)),2) AS revenue,
       ROUND(SUM(s.quantity*(s.unit_price*(1-COALESCE(s.discount_pct,0)/100)-p.cost_price)),2) AS gross_profit,
       ROUND(100*SUM(s.quantity*(s.unit_price*(1-COALESCE(s.discount_pct,0)/100)-p.cost_price)) /
             NULLIF(SUM(s.quantity*s.unit_price*(1-COALESCE(s.discount_pct,0)/100)),0),1) AS gross_margin_pct
FROM sales s JOIN products p ON s.product_id=p.product_id
GROUP BY COALESCE(s.discount_pct,0) ORDER BY discount_rate;

-- 8. INVENTORY VS SALES
-- Exploratory only: inventory is a point-in-time snapshot; sales cover the full period.
SELECT p.product_name,SUM(i.stock_quantity) AS current_stock,COALESCE(x.units_sold,0) AS units_sold
FROM products p JOIN inventory i ON p.product_id=i.product_id
LEFT JOIN (SELECT product_id,SUM(quantity) AS units_sold FROM sales GROUP BY product_id) x
ON p.product_id=x.product_id
GROUP BY p.product_id,p.product_name,x.units_sold ORDER BY current_stock DESC;

-- 9. SUPPLIER ANALYSIS
SELECT sp.supplier_name,sp.lead_time_days,COUNT(DISTINCT p.product_id) AS products_supplied,
       COALESCE(SUM(i.stock_quantity),0) AS current_stock
FROM suppliers sp LEFT JOIN products p ON sp.supplier_id=p.supplier_id
LEFT JOIN inventory i ON p.product_id=i.product_id
GROUP BY sp.supplier_id,sp.supplier_name,sp.lead_time_days ORDER BY sp.lead_time_days DESC;

-- 10. MONTHLY REVENUE
SELECT DATE_TRUNC('month',sale_date)::date AS month,COUNT(*) AS transactions,SUM(quantity) AS units_sold,
       ROUND(SUM(quantity*unit_price*(1-COALESCE(discount_pct,0)/100)),2) AS revenue
FROM sales GROUP BY DATE_TRUNC('month',sale_date) ORDER BY month;

-- 11. REVENUE RECONCILIATION
WITH monthly_revenue AS (
    SELECT DATE_TRUNC('month',sale_date)::date AS month,
           SUM(quantity*unit_price*(1-COALESCE(discount_pct,0)/100)) AS revenue
    FROM sales GROUP BY DATE_TRUNC('month',sale_date)
)
SELECT ROUND(SUM(revenue),2) AS reconciled_revenue FROM monthly_revenue;

-- 12. TOP 10 PRODUCTS BY GROSS PROFIT
SELECT p.product_name,
       ROUND(SUM(s.quantity*(s.unit_price*(1-COALESCE(s.discount_pct,0)/100)-p.cost_price)),2) AS gross_profit
FROM sales s JOIN products p ON s.product_id=p.product_id
GROUP BY p.product_id,p.product_name ORDER BY gross_profit DESC LIMIT 10;
