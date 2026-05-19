use Final_Project
Go

select *
from [dbo].[customer]
where [marital_status]!='Single'
go

with RFM as(    
SELECT coustomer_key,
    DATEDIFF(DAY,max([date]),getdate()) as R,
    cast(1.*count([item_key])/DATEDIFF(MONTH,min([date]),getdate()) as decimal(5,3)) as F,
    sum([total_price]) as M
from [dbo].[fact_table] as F join [dbo].[time_dim_update] as T_D on F.time_key=T_D.time_key
group by coustomer_key
),
RFM_Score as(
    select *,
        NTILE(5) over(order by R) as R_score,
        NTILE(5) over(order by F) as F_Score,
        NTILE(5) over(order by M) as M_score
    from RFM
),
Type_Cus as(
select*,
    case
        when R_score>=4 and F_Score>=4 and M_score>=4 then 'Best Customer'
        when R_score>=4 and (F_Score>=2 and F_Score<=3) 
            and (M_score>=2 and M_score<=3) then 'Royal Customer'
        when R_score>=4 and (F_Score>=4) 
            and (M_score>=2 and M_score<=3) then 'potential loyal customers'
        when R_score>=4 and (F_Score<=2) 
            and M_score>=4 then 'prospective VIP customer'
        else 'nan'
    end as Type_Customers
from RFM_Score
)
SELECT Type_Customers,item_name,count([F_B].item_key) as soluong
from  [dbo].[fact_table] as F_B  
    join [dbo].[item_dim] as I_D on F_B.item_key=I_D.item_key
    join Type_Cus as T_C on F_B.coustomer_key=T_C.coustomer_key
group by Type_Customers,item_name
