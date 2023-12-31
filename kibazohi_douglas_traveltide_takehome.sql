
-- The following analysis was done using TravelTide Travel Data
-- TravelTide Data source:  postgresql://Test:bQNxVzJL4g6u@ep-noisy-flower-846766.us-east-2.aws.neon.tech/TravelTide?sslmode=require
-- Findings are listed after each query section and Recommendations are listed at the end.

-- 1a

select 
gender,
extract(year from current_date) - extract(year from birthdate) as age,
count(flight_booked) as no_of_flights
from users u
left join sessions s using (user_id)
group by 1,2
having extract(year from current_date) - extract(year from birthdate) >= 18
order by 3 desc
limit 1

-- 1b

select 
married,
has_children,
count(flight_booked) as no_of_flights,
round(avg(extract(year from current_date) - extract(year from birthdate))) as avg_age

from users u
left join sessions s using (user_id) 
where married = has_children
group by 1,2
order by 3 desc

-- 1b (part two)

select 
gender,
extract(year from current_date) - extract(year from birthdate) as age,
count(flight_booked) as no_of_flights
from users u
left join sessions s using (user_id)
group by 1,2
having extract(year from current_date) - extract(year from birthdate) IN (36, 45)
order by 3 desc


/* Findings:
In query 1a I discover that 39-year old Men travel the most.
1b tells us that users who are single and childless greatly outnumber users who are married and with children when it comes to who flies more. The ratio is 2.9 to 1 for total number of flights. */

/* Further Observations:
I also noticed that the average age was different. 36 for single and childless users VS 45 for  those married and with children. However, age is not a factor since the number of flights per age is about the same, as proven in the code at 1b (part two).

*/


-- 2a

with  abandoned as (
select session_id 
  from sessions 
where flight_booked is false 
     and hotel_booked is false)


select 
count(s.session_id) as total_sessions,
count(aba.session_id) as abandoned_sessions,
round(count(aba.session_id)/count(s.session_id)::numeric, 3) as percent_abandoned
from sessions s
left join abandoned aba using (session_id)

-- 2b part 1 (By Gender)

with  abandoned as (
select session_id 
  from sessions 
where flight_booked is false 
     and hotel_booked is false)


select gender,
count(s.session_id) as total_sessions,
count(aba.session_id) as abandoned_sessions,
round(count(aba.session_id)/count(s.session_id)::numeric, 3) as percent_abandoned
from sessions s
left join abandoned aba using (session_id)
left join users u using (user_id)
group by 1


-- 2b part 2 (By marriage/children status)

with  abandoned as (
select session_id 
  from sessions 
where flight_booked is false 
     and hotel_booked is false)


select 
married,
has_children,
count(s.session_id) as total_sessions,
count(aba.session_id) as abandoned_sessions,
round(count(aba.session_id)/count(s.session_id)::numeric, 3) as percent_abandoned
from sessions s
left join abandoned aba using (session_id)
left join users u using (user_id)
where married = has_children
group by 1,2


-- 2b part 3 (by age buckets)

with  abandoned as (
select session_id 
  from sessions 
where flight_booked is false 
     and hotel_booked is false),

byage as (
select 
extract(year from current_date) - extract(year from birthdate) as age,
count(s.session_id) as total_sessions,
count(aba.session_id) as abandoned_sessions,
round(count(aba.session_id)/count(s.session_id)::numeric, 3) as percent_abandoned
from sessions s
left join abandoned aba using (session_id)
left join users u using (user_id)
group by 1
order by 4 desc)


select 
case when age between 18 and 24 then '18-24'
		when age between 25 and 30 then '25-30'
    when age between 31 and 40 then '31-40'
    when age between 41 and 50 then '41-50'
    when age between 51 and 64 then '51-64'
    when age >= 65 then '65+'
    end as age_buckets,
 
 sum(total_sessions) as total_sessions, 
 sum(abandoned_sessions) as abandoned_sessions,
 avg(percent_abandoned) as percent_abandoned 
 
 from byage
 where age > 17
 group by 1
 order by 4 desc

/* Findings:
Query at 2a gives us the number of users who abandoned their session without booking either a flight or a hotel. The ratio is provided for comparison between abandoned sessions and total sessions (approx 57% or 0.568).

The next task was to figure out which segment or demographic of our user base abandon their sessions the most. Our results are visible in Query 2b part 3, where the abandoned session rate is filtered according to age-buckets. I found that users aged 18-24 and 65+ have a disproportionately high rate at 0.74, whereas other age buckets vary much closer to the mean of 0.57.
*/

/* Further Observations:
Other queries were used to compare the abandoned sessions rate by gender and marital/children status and results showed those segments were very close to the mean with deviation of less than 2%. Therefore, those demographics do not influence this metric.
*/

-- 3a

with cte as (

select 
home_city, 
count(distinct u.user_id) uniqueusers, 
count(flight_booked) flights,
round(count(flight_booked)/extract(days from max(departure_time) - min(departure_time)))
as avgflightsbookedperday,
round(count(flight_booked)::numeric/count(distinct u.user_id)::numeric, 2) 
as avgflightsperuser,
round(avg(checked_bags), 2) as avgcheckedbags,
round(avg(extract(days from return_time - departure_time))) as avgtripduration,
round(avg(extract(days from check_out_time - check_in_time))) as avghotelstay,
round(avg(base_fare_usd)) as avgcostperflight,
round(avg(hotel_per_room_usd)) as avgcosthotelroom,
round(avg(extract(days from departure_time - session_start))) as avgdaystoflight

from users u
left join sessions s on s.user_id = u.user_id
left join flights f on f.trip_id = s.trip_id 
left join hotels h on h.trip_id = s.trip_id

where flight_booked = 'true' and destination is not null

group by 1
order by 3 desc

)

select 
case when avgdaystoflight <= 30 then 'Big City'
		when avgdaystoflight > 30 then 'Small City'
    end as city_category,
*
from cte

-- 3b (Challenge question from practical interview simulation with Arad Namin, Data Scientist)
-- Question: Obtain the cumulative average of abandoned sessions, per every 3 days.



with  abandoned as (
select session_id, session_start
  from sessions 
where flight_booked is false 
     and hotel_booked is false),
     
     
abandoned_per_day as (
select 
date_trunc('day', session_start) as dates, 
count(session_id) as ab

from abandoned
group by 1
order by 1
-- to obtain number of sessions per day
)

-- query below is to obtain the cumulative avg of abandoned sessions for every 3 day

select 
dates,
avg(ab) over (order by dates asc 
							rows between 2 preceding and current row)
							as rolling_avg
    
from abandoned_per_day



/* Findings: 
Many comparisons were made in this analysis, where I tried to see the impact of home city on users’s travel preferences. 

There were noticeable trends in the average number of flights per day for each city, the trip duration including length of hotel stay, and how many days in advance users booked flights, as well as average cost of flights per city.

And here’s how it all comes together:

1. In a lot of the big cities, we of course can expect a higher foot traffic in the airports, a higher population pool, and by no surprise, our data reflected a high number of users from these areas booking flights as well. To keep it short, we can call these the ‘Big and Busy’ and since we’re at it, why not nickname their counterpart as ‘Smaller and Calmer’.  

NB: Our dataset contains 105 different home cities so this is an easier way to convey results.

2. Users in the Big and Busy enjoy cheaper flight prices, with most hovering around the $500-800 range. Prices in the Smaller and Calmer cities are higher on average, ranging from $700 to $1000+.

3. Big and Busy customers book flights within a month of their departure date whereas Small and Calmer customers usually book around 41-45 days in advance, which is one major difference in behaviours. The difference in average flight costs probably contributes to this. Or perhaps the Smaller and Calmer guys are just too calm to be in a rush.

4. Slight differences in trip durations are noticeable. Big and Busy users on average book a 5 day trip with a 3 nights hotel stay, while Smaller and Calmer are the ones to go a bit ‘bigger’ with 6 day trips and 4 nights in hotels. Can’t fault them for wanting an extra day to relax. It seems the Big and Busy have to get back to being busy ASAP. 

5. Hotel room prices remained the same across users of all cities (Avg of $177).
6. Big and Busy users flew slightly more often that the Smaller and Calmer ones. Average flights per user range from 2.44 down to 2.10 for all cities.

In case you’re wondering how you can quickly tell, from the data or query, whether a city falls into the Big and Busy or Smaller and Calmer, the simple way is to look at the jump in the average days to flights. Once it goes from 28 to 44, then you know. The average number of flights booked per day will also fall from 13 to 10 and trip duration will change from 5 to 6 days.

In summary, population size and lifestyles within cities seem to play a big role in results.

*/

/* My Final Recommendations :
4a

Part 4a is to address the question about my personal recommendations based on my analysis. And here they are:


1. Let’s try to get our customers more deals that fall under $800. Our customers respond more positively, and they are more likely to book again with us considering the average trips per user drops off once prices go beyond this mark. Whenever prices to popular travel destinations drop, we should be sending notifications.

2. Curate travel packages that appeal to demographics. For example, customers in Smaller and Calmer cities like a longer trip with a longer stay, let’s help them achieve that goal cost effectively. They spend more days in hotels. Maybe we can shave $30 off from their daily fee? We can talk to hotels to discuss an offer.

3. Create ads to encourage young people to travel and explore the world once they’re done with college/university and have secured a job. Make it clear that once they settle down into families they are 3x less likely to afford to travel!! Plus, traveling is learning too. Provide attractive travel prices to newly grads that can be claimed once or twice, within 2-3 years of graduating to encourage sales through our platform. We should be at every graduation ceremony giving out coupons when their families are there. Perfect graduation gift!

4. A big chunk of our abandoned sessions come from users aged 18-24. I think this is a great opportunity to begin priming them for their next (or first) ‘big trip’. Maybe they don’t have the funds now. But, we can offer them a coupon redeemable within 5-7 years that will ensure they convert into future customers. Give them a reason to keep our app while they upgrade their phones.

NOTE: While analyzing data, I noticed users aged 17 had overwhelmingly disproportionate stats, many which seemed unrealistic and broke natural trends. I assume that they are not all of 17 years of age and perhaps these are users who refused to disclose their age and instead, used the default minimum age just to use our app. So these figures were omitted in cases where results were skewed.
*/


















