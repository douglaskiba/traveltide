-- for rows with abandoned sessions

with  abandoned as (
select session_id, session_start
  from sessions 
where flight_booked is false 
     and hotel_booked is false),
     
-- to obtain number of abandoned sessions per day, respective of month and year
    
abandoned_per_day as (
select 
extract (day from session_start) as days,
extract (month from session_start) as months,
extract (year from session_start) as years,
count(session_id) as no_abandoned_sessions

from abandoned
group by 1,2,3
order by 3,2,1

)

-- query below is to obtain the cummulative sum for each day

select 
concat(days, '-', months, '-', years) as new_date, 
-- to merge date, month, year into a single column 
sum(no_abandoned_sessions) over 
(order by years, months, days asc rows between unbounded preceding and current row)
from abandoned_per_day






