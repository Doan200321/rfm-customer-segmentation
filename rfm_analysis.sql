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
create view vw_rfm_customer as
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
    Type_Cus as(
    -- Group customers by their R/F/M scores (1-5).
    -- Only recent customers (R_score >= 4) are assigned to the 4 main segments; the rest are 'Other'.
    select*,
        case
            when R_score>=4 and F_score>=4 and M_score>=4 then 'Best Customer'
            when R_score>=4 and (F_Score>=2 and F_score<=3) 
                and (M_score>=2 and M_score<=3) then 'Loyal Customer'
            when R_score>=4 and (F_score>=4) 
                and (M_score>=2 and M_score<=3) then 'Potential Loyal Customer'
            when R_score>=4 and (F_score<=2) 
                and M_score>=4 then 'Prospective VIP Customer'
            else 'Other'
        end as Type_Customers
    from RFM_Score
    )
    SELECT coustomer_key,Type_Customers,R,F,M, R_score,F_score,M_score
    from Type_Cus

go

-- =====================================================
-- 3. OUTPUT CHECKS
-- =====================================================
SELECT TOP 10 * FROM vw_rfm_customer;
SELECT Type_Customers, COUNT(*) FROM vw_rfm_customer GROUP BY Type_Customers;
