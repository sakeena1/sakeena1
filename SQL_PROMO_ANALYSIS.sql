-- 1. 

SELECT DISTINCT  p.product_code,
    p.product_name,
    f.base_price,
    f.promo_type
FROM 
    dim_products p
JOIN 
    fact_events f ON p.product_code = f.product_code
WHERE 
    f.base_price > 500
    AND f.promo_type = 'BOGOF';

-- 2
SELECT
    ds.city,
    COUNT(ds.store_id) AS store_count
FROM
    dim_stores ds
GROUP BY
    ds.city
ORDER BY
    store_count DESC;

-- 3
WITH campaign_rev as (
SELECT
	f.campaign_id,
	campaign_name,		
    SUM(quantity_sold_before_promo * f.base_price ) as Total_Rev_Before_Promo,
    SUM(CASE 
			WHEN f.promo_type = 'BOGOF' THEN (quantity_sold_after_promo* (f.base_price/2 ))
            WHEN f.promo_type = '500 Cashback' THEN (quantity_sold_after_promo * (base_price -500))
            WHEN f.promo_type = '50% OFF' THEN (f.quantity_sold_after_promo *(base_price - (0.5 * f.base_price)) )
		    WHEN f.promo_type = '33% OFF' THEN (f.quantity_sold_after_promo *(base_price - (0.33 * f.base_price)) )
            WHEN f.promo_type = '25% OFF' THEN (f.quantity_sold_after_promo *(base_price - (0.25 * f.base_price)))
		END) as Total_Rev_After_Promo
FROM fact_events f 
LEFT JOIN dim_campaigns c 
ON f.campaign_id = c.campaign_id 
GROUP BY f.campaign_id
)
SELECT 
	campaign_name, 
    CONCAT(ROUND((Total_Rev_Before_Promo/1000000),2)," M") as Total_Revenue_Before_Promo,
    CONCAT(ROUND((Total_Rev_After_Promo/1000000),2)," M") as Total_Revenue_After_Promo
FROM campaign_rev;


-- 4 
WITH total_qty as (
SELECT 
	quantity_sold_before_promo,
    (CASE 
		WHEN promo_type = "BOGOF" THEN quantity_sold_after_promo/2
        ELSE quantity_sold_after_promo
     END ) as total_qty_sold_after_promo
FROM fact_events
),
isu as (
SELECT
	quantity_sold_before_promo,
    (total_qty_sold_after_promo - quantity_sold_before_promo) as isu
FROM total_qty    
),
 DiwaliSales AS (
    SELECT
        p.category,
        SUM(isu) AS IncrementalSoldQuantity,
        SUM(fe.quantity_sold_before_promo) AS BaselineQuantity
    FROM
        isu,fact_events fe
    JOIN
        dim_products p ON fe.product_code = p.product_code
    JOIN
        dim_campaigns c ON fe.campaign_id = c.campaign_id
    WHERE
        c.campaign_name = 'Diwali'
    GROUP BY
        p.category
),
isu_percentage as (
SELECT
    category,
    round((SUM(IncrementalSoldQuantity) / NULLIF(SUM(BaselineQuantity), 0)),2) * 100 AS ISU_percent
FROM
    DiwaliSales
GROUP BY
    category
 )   
 
 SELECT category, isu_percent, ROW_NUMBER() OVER(ORDER BY ISU_percent desc) as rnk
 FROM isu_percentage;
 
 -- 5
 WITH campaign_rev as (
SELECT
	f.campaign_id,
	c.campaign_name,	
	f.product_code,
    p.product_name,
    p.category,
    SUM(quantity_sold_before_promo * f.base_price ) as Total_Rev_Before_Promo,
    SUM(CASE 
			WHEN f.promo_type = 'BOGOF' THEN (quantity_sold_after_promo* (f.base_price/2 ))
            WHEN f.promo_type = '500 Cashback' THEN (quantity_sold_after_promo * (base_price -500))
            WHEN f.promo_type = '50% OFF' THEN (f.quantity_sold_after_promo *(base_price - (0.5 * f.base_price)) )
		    WHEN f.promo_type = '33% OFF' THEN (f.quantity_sold_after_promo *(base_price - (0.33 * f.base_price)) )
            WHEN f.promo_type = '25% OFF' THEN (f.quantity_sold_after_promo *(base_price - (0.25 * f.base_price)))
		END) as Total_Rev_After_Promo
FROM fact_events f 
LEFT JOIN dim_campaigns c 
ON f.campaign_id = c.campaign_id 
LEFT JOIN dim_products p 
ON f.product_code = p.product_code
GROUP BY f.campaign_id, product_code
),
total_Revenues as (
SELECT 
	campaign_name, 
    product_code,
    product_name,
    category,
    CONCAT(ROUND((Total_Rev_Before_Promo/1000000),2)," M") as Total_Revenue_Before_Promo,
    CONCAT(ROUND((Total_Rev_After_Promo/1000000),2)," M") as Total_Revenue_After_Promo
FROM campaign_rev
),
ir_percentage as (
SELECT 
	 campaign_name
     ,product_name
    ,category
	,ROUND((((Total_Revenue_After_Promo - Total_Revenue_Before_Promo)/Total_Revenue_Before_Promo)*100),2) as ir_percent
    
FROM total_Revenues
order by product_code
)
SELECT ir_percentage.*, ROW_NUMBER() OVER( ORDER BY ir_percent DESC) AS rnk 
FROM ir_percentage
ORDER BY rnk 
LIMIT 5;