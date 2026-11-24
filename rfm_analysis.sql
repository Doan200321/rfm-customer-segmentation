/* ============================================================
   RFM Customer Segmentation (v2)
   Data: https://www.kaggle.com/datasets/mmohaiminulislam/ecommerce-data-analysis
   Output: view vw_rfm_customer – 1 row per customer
   ============================================================ */
use Final_Project
go
--1a. Check the definition of F
--Each row in fact_table is a line iteam, not a purchase
--Result: number of purchases < number of rows
-- --> a purchase may contain multiple rows -> F = COUNT(DISTINCT time_key)
SELECT COUNT(*) AS so_dong,
       COUNT(DISTINCT CONCAT(coustomer_key, '-', time_key)) AS so_cap_khach_thoigian
FROM fact_table;
Go
-- 1b. Compare the max date in time_dim with the latest transaction date.
-- Use the latest transaction date as the reference date (not GETDATE),
-- so the result only changes when the data changes. Both dates = 2021-01-23.
SELECT MAX([date]) FROM time_dim;
SELECT MAX(T.[date]) FROM fact_table F JOIN time_dim T ON F.time_key = T.time_key;
go

-- =====================================================
-- 2. RFM VIEW
-- =====================================================
alter view vw_rfm_customer as
    with RFM as(
    -- R = number of days since the last purchase to the reference date
    -- F = number of purchases; M = total spending
    SELECT coustomer_key,
        DATEDIFF(DAY,max([date]),(SELECT MAX(TD.[date]) FROM fact_table FT JOIN time_dim TD ON FT.time_key = TD.time_key)) as R,
        COUNT(DISTINCT F.time_key) AS F,
        sum([total_price]) as M
    from [dbo].[fact_table] as F join [dbo].[time_dim] as T_D on F.time_key=T_D.time_key
    group by coustomer_key
    ),
    RFM_Score as(
    -- R is sorted in descending order because a small R = recent purchase = high score.
    -- coustomer_key is used as a tie-breaker: customers with the same R (ties)
    -- would otherwise be split into groups randomly, so the result would not be reproducible.
        select *,
            NTILE(5) over(order by R desc, [coustomer_key]) as R_score,
            NTILE(5) over(order by F ,[coustomer_key]) as F_score,
            NTILE(5) over(order by M, [coustomer_key]) as M_score
        from RFM
    ),
    FM as (
    -- FM_score is the average of F_score (number of purchases) and M_score (total spending).
    -- We use the average because it is on the same 1-5 scale as R_score,
    -- which makes it easy for readers to compare and understand.
    select *,((F_score+M_score)*1.0)/2 as FM_score
    from RFM_Score
    ),
    Type_Cus as(
    -- Segment customers on two dimensions: R and FM.
    -- A score (R_score or FM_score) >= 3 is considered "high".
    select *,
        case
            when R_score>=3 and FM_score>=3 then 'Champions'
            when R_score<3 and FM_score>=3 then 'At Risk'
            when R_score>=3 and FM_score<3 then 'New'
            when R_score<3 and FM_score<3 then 'Lost'
        end as Type_Customers
    from FM
    )
    SELECT coustomer_key,Type_Customers,R,F,M, R_score,FM_score
    from Type_Cus

go

-- =====================================================
-- 3. OUTPUT CHECKS
-- =====================================================
SELECT TOP 10 * FROM vw_rfm_customer;
SELECT Type_Customers, COUNT(*) as num_cus FROM vw_rfm_customer GROUP BY Type_Customers;
go

select Type_Customers, 
    count(*) as num_customers, count(*)*1.0/sum(count(*)) over() as pct_customers, 
    sum(M) as revenue, sum(M)*1.0/sum(sum(M)) over() as pct_revenue
from vw_rfm_customer
group by [Type_Customers]
order by revenue desc 
