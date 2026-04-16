use joins;
/*
===========================
TIME WINDOW LOGIC (IMPORTANT)
===========================

INSIDE vs OUTSIDE PERIOD

"Inside period"  → use >=
"Outside period" → use <

--------------------------------------------------

TIMELINE UNDERSTANDING

OLD --------------------|-------------------- RECENT (CURRENT_DATE = 12 April 2026)
                        ^
                    Cutoff Date

Example:
Cutoff (30 days) = 13 March 2026

Left side (before cutoff)      → OLD data
Right side (on/after cutoff)   → RECENT data

--------------------------------------------------

USAGE

"In last 30 days"      → date >= cutoff_date
"Older than 30 days"   → date < cutoff_date

--------------------------------------------------

JOIN LOGIC

Need customers WITH activity     → INNER JOIN
Need customers WITHOUT activity  → LEFT JOIN (churned)

Use < cutoff   → churned / inactive customers
Use >= cutoff  → active / recent customers

==================================================
TIME SERIES FILTERING (IMPORTANT)
==================================================

DO NOT USE:

MONTH(date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH)

Why this is WRONG:

MONTH(date)
→ returns only month number (1–12)
→ Example: MONTH('2026-04-12') = 4

DATE_SUB(...)
→ returns full date
→ Example: '2026-01-12'

So comparison becomes:
number (4) vs full date ('2026-01-12') → INVALID LOGIC

--------------------------------------------------

Even this is WRONG:

MONTH(date) >= MONTH(DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH))

Example:
Last 3 months from April 2026 = Jan, Feb, Mar

Condition:
MONTH >= 1 returns:
Jan, Feb, Mar, Apr, May... ❌

Problems:
- Includes unwanted months
- Ignores year (breaks across years)

--------------------------------------------------

CORRECT WAY

Always compare FULL DATES:

WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH)

Reason:
Both sides are full dates → correct comparison

--------------------------------------------------

RULE

MONTH(date) → partial value (unsafe for filtering)
DATE_SUB(...) → full date

Never compare partial date with full date

==================================================
ROLLING vs CALENDAR WINDOWS
==================================================

1) ROLLING WINDOWS (dynamic)

Use >= only

Examples:
"last 7 days"
"last 30 days"
"last 6 weeks"

Logic:
date >= DATE_SUB(CURRENT_DATE(), INTERVAL X DAY)

Example:
If today = 12 April 2026
Cutoff = 13 March 2026

Timeline:

OLD ---------|-------------------- RECENT
             13 Mar             12 Apr

Use case:
Recent activity, new users, trends

--------------------------------------------------

2) CALENDAR PERIODS (fixed)

Use >= AND <

Examples:
"last month"
"previous week"
"specific date range"

Logic:
date >= start_of_period
AND date < start_of_next_period

Example:
If today = 12 April 2026

Last month = March 2026
Start = 1 March 2026
End  = 31 March 2026

Timeline:

OLD ---------|==== LAST MONTH ====|--------- CURRENT
             1 Mar              31 March

Use case:
Monthly reports, weekly reports, exact analysis

==================================================
FINAL KEY RULE
==================================================

Rolling window   → use >=
Calendar period  → use >= AND <

==================================================
IMPORTANT REMINDER
==================================================

Never use:
MONTH(date), YEAR(date), DAY(date) for filtering

Always use:
FULL DATE comparison

This avoids:
- wrong results
- year mismatch issues
- incorrect filtering
*/

# 1) find customers who have not placed any order since last 3 months 
# or  find customer who last placed their order 3 months ago
-- Churned Customers (inactive)
-- Customers with NO orders ever
select * from customers;
select * from orders;
select c.customer_id, max(o.order_date) as last_order
from customers c left join orders o
on c.customer_id = o.customer_id
group by c.customer_id
having max(o.order_date) < date_sub(current_date(), interval 3 month)
or max(o.order_date) is null; 
-- Note for the above task
-- If CURRENT_DATE() is 12 April 2026,
-- then DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH) = 12 Jan 2026
-- We are selecting customers whose last order is BEFORE 12 Jan 2026
-- meaning they have NOT placed any order in the last 3 months (Jan 12 to Apr 12)

/* IMP 
There are two types of date subtraction:

Using DAYS
DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)

→ subtracts exact number of days

Example:
If today = 12 April 2026
12 April - 30 days = 13 March 2026

Reason:
It counts actual days backward (not months)

Using MONTHS
DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH)

→ subtracts calendar months

Example:
12 April → 12 March → 12 February → 12 January

Result = 12 January 2026

KEY DIFFERENCE

INTERVAL 30 DAY
→ exact day calculation
→ date may shift (13 March)

INTERVAL 3 MONTH
→ calendar-based
→ same date number (12 Jan)

RULE

Use DAY when you need exact number of days
Use MONTH when you need same date in previous months
*/

# 2) Find customers who placed an order in the last 7 days 
select distinct c.customer_id, o.order_id -- one row per unique customer+order combination
from customers c join orders o -- inner join: only customers who have orders
on c.customer_id = o.customer_id 
where o.order_date >= date_sub(current_date(), interval 7 day);  
-- DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

-- This returns the date 7 days before today.

-- CURRENT_DATE() gives today’s date.
-- DATE_SUB subtracts 7 days from it.

-- Example:
-- If today is 12 April 2026,
-- then DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) = 5 April 2026

-- Timeline:
-- OLD --------------------|-------------------- RECENT (Today: 12 April)
--                         ^
--                     Cutoff Date (5 April)

-- Left side (< 5 April)        = older data
-- Right side (>= 5 April)      = last 7 days data

-- So this condition:
-- WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)

-- Returns:
-- 5 April → 12 April (includes today)
-- Total = 8 days


# 3) Find customers who placed their first-ever order in the last 30 days.
select c.customer_id, min(o.order_date) as fist_order  -- get each customer's earliest order date
from customers c join orders o
on c.customer_id = o.customer_id
group by c.customer_id
having min(o.order_date) >= date_sub(current_date(), interval 30 day); -- keep only new customers

-- FIND CUSTOMERS WHO PLACED THEIR FIRST-EVER ORDER IN LAST 30 DAYS

-- MIN(order_date) gives the first (earliest) order date per customer

-- DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
-- returns the date 30 days before today

-- Example:
-- If today = 12 April 2026
-- Cutoff = 13 March 2026

-- Timeline:
-- OLD --------------------|-------------------- RECENT (Today: 12 April)
--                         ^
--                     Cutoff Date (13 March)

-- Logic:
-- MIN(order_date) >= cutoff_date

-- Meaning:
-- Customer’s first order happened in the recent period (last 30 days)

-- Selected:
-- 13 March → 12 April (new customers)

-- Not selected:
-- Before 13 March (old customers)

-- Final understanding:
-- This query finds NEW customers whose first-ever order is within last 30 days


# 4) Find customers who placed their last order in the last month
select c.customer_id, max(o.order_date) as last_order_date
from customers c join orders o
on c.customer_id = o.customer_id
group by c.customer_id
having max(o.order_date) >= date_format(date_sub(current_date(), interval 1 month), '%Y-%m-%01')
and max(o.order_date) < date_format(current_date(), '%Y-%m-%01');
/*
FIND CUSTOMERS WHO PLACED THEIR LAST ORDER IN THE LAST MONTH

MAX(order_date) gives the latest (most recent) order per customer

We are filtering customers whose LAST order falls inside last month

Cutoff logic (calendar month):

DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), '%Y-%m-01') → start of last month
DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01') → start of current month

Example:
If today = 12 April 2026

Start of last month = 1 March 2026
Start of current month = 1 April 2026

Timeline:

OLD ---------|======= LAST MONTH =======|--------- CURRENT
             1 Mar                    1 Apr

Logic:

MAX(order_date) >= '2026-03-01'
AND MAX(order_date) <  '2026-04-01'

Meaning:

Selected:
1 March → 31 March (customers whose last order was in March)

Not selected:
Before 1 March → old customers
On/after 1 April → current month customers

Final understanding:

This finds customers whose LAST activity happened in the previous calendar month

Key rule:

Calendar period (month) → use >= start AND < next period start
Rolling period (days) → use >= only
*/

# 5) find customers previous month's/ last month order and if not placed order then show null
select c.customer_id, o.order_id, o.order_date
from customers c left join orders o
on c.customer_id = o.customer_id
-- filter only previous month orders (placed inside ON to preserve NULLs)
and o.order_date >= date_format(date_sub(current_date(), interval 1 month), '%Y-%m-01') 
and o.order_date < date_format(current_date(), '%Y-%m-01');
/*
FIND CUSTOMERS WITH PREVIOUS MONTH ORDERS (SHOW NULL IF NO ORDER)

LEFT JOIN is used to keep all customers
If a customer has no order in previous month then order fields will be NULL

Previous month = full calendar month

Cutoff dates:
Start = 1st day of previous month
End = 1st day of current month (exclusive)

Example:
If today = 12 April 2026
Start = 01 March 2026
End = 01 April 2026

Timeline:
OLD ---------| MARCH (SELECTED) |--------- APRIL (EXCLUDED)
1 Mar 1 Apr

Logic (placed inside JOIN to preserve NULLs):
o.order_date >= 01 March
AND o.order_date < 01 April

Meaning:
Customers with orders in March → show order details
Customers without orders in March → show NULL

Final understanding:
This gives all customers with their previous month activity (if any)

Key point:
Date filter must be inside ON clause
Otherwise LEFT JOIN becomes INNER JOIN
*/

-- 6) find customers who purchased more than 1 time in the last month
select c.customer_id
from customers c join orders o
on c.customer_id = o.customer_id
where o.order_date >= date_format(date_sub(current_date(), interval 1 month), '%Y-%m-01')
and o.order_date < date_format(current_date(), '%Y-%m-01')																								
group by c.customer_id
having count(*) > 1;

/* 7 Determine customers who have consistently placed orders over a specific period 
(e.g., at least two payment every week for the last 6 weeks). */
with weekly_data as
(select customer_id, yearweek(order_date) as weekly, count(order_id) as order_count
from orders
where order_date >= date_sub(current_date(), interval 6 week)
group by customer_id, yearweek(order_date))
select customer_id
from weekly_data
where order_count>= 2
group by customer_id
having count(distinct weekly) = 
(select count(distinct yearweek(order_date)) from orders
where order_date >= date_sub(current_date(), interval 6 week));
/*
having count(distinct weekly) = 
(select count(distinct yearweek(order_date)) from orders
where order_date >= date_sub(current_date(), interval 6 week));
what this does?
Ensures customer is active in every week with no missing week  
Uses dynamic count instead of fixed 6 for accuracy
*/

-- 8 Calculate 7-day retention (customers who return within 7 days after first order)
select * from orders;
with firstorder as
(select customer_id, min(order_date) as first_order
from orders
group by customer_id
order by customer_id),
retained as
(select o.customer_id, o.order_date, f.first_order
from orders o join firstorder f
on o.customer_id = f.customer_id 
where datediff(o.order_date, f.first_order) between 1 and 7)
select (count(distinct r.customer_id) * 100) / count(distinct f.customer_id)
from firstorder f left join retained r
on r.customer_id = f.customer_id;

-- 9 Find customers who placed another order within 2 months of their previous order
select * from orders;
with previ as
(select customer_id, order_date as month_date,
lag(order_date, 1) over(partition by customer_id order by order_date) as previ_month
from orders)
select count(distinct customer_id) from
(select customer_id, month_date, previ_month,
timestampdiff(month, previ_month, month_date) as diff
from previ) as Raj
where diff between 1 and 2;

-- find cx who placed an order within 2  months after thgeir first order
with firsts as
(select customer_id, min(order_date) first_month_date
from orders
group by customer_id),
retained as
(select o.customer_id, o.order_date, f.first_month_date,
timestampdiff(month, f.first_month_date, o.order_date)
from orders o join firsts f
on o.customer_id = f.customer_id
where timestampdiff(month, f.first_month_date, o.order_date) between 1 and 2)
select (count(distinct r.customer_id) * 100)/ count(distinct f.customer_id)
from firsts f left join retained r
on f.customer_id = r.customer_id;

# find customers who havent placed any order since last two quaters
select * from customers;
select * from orders;
select c.customer_id, max(o.order_date) as last_order
from customers c left join orders o
on c.customer_id = o.customer_id
group by c.customer_id
having max(o.order_date) < date_sub(current_date(), interval 2 quarter)
or max(o.order_date) is null; 

# find customers placed an order in the last two quaters and if not placed show null
select c.customer_id, o.order_id
from customers c left join orders o
on c.customer_id = o.customer_id
and o.order_date >= date_sub(current_date(), interval 2 quarter)
and o.order_date < current_date();

# find retention rate of last quarter
with retained_users as
(select distinct customer_id from orders
where year(order_date) = (select max(year(order_date)) from orders)
and quarter(order_date) = (select max(quarter(order_date)) from orders where year(order_date) =
(select max(year(order_date)) from orders))),
previous_users as
(select distinct customer_id from orders
where year(order_date) = (select max(year(order_date)) from orders)
and quarter(order_date) = (select max(quarter(order_date)) -1 from orders where year(order_date) =
(select max(year(order_date)) from orders)))
select (count(distinct r.customer_id) * 100) / count(distinct p.customer_id)
from previous_users p
left join retained_users r
on p.customer_id = r.customer_id;	


# Find cx who has place atleast 2 order every month for the last 6 quarter
with monthly_orders as
(select customer_id, date_format(order_date, '%Y-%m') as active_months, -- extract year-month (e.g., 2024-01)
count(order_id) as count_order -- number of orders in that month
from orders
where order_date >= date_sub(current_date(), interval 6 quarter) -- Filter last 6 quarters (18 months)
group by customer_id, date_format(order_date, '%Y-%m'))
select customer_id
from monthly_orders
where count_order >=2 -- keep only months with ≥2 orders
group by customer_id
-- Step 6: Keep only customers who:
-- (a) have orders in all 18 months
-- (b) have at least 2 order in each month
having count(distinct active_months) = 
(select count(distinct date_format(order_date, '%Y-%m')) from orders
where order_date >= date_sub(current_date(), interval 6 quarter));

# Find cx who has place atleast 2 order every week for the last 6 quarter(loyal customers)
with weekly_orders as
(select customer_id, yearweek(order_date) as active_week,
count(order_id) as count_order -- number of orders in that week
from orders
where order_date >= date_sub(current_date(), interval 6 quarter) -- Filter last 6 quarters (78 weeks)
group by customer_id, yearweek(order_date))
select customer_id
from weekly_orders
where count_order >=2 
group by customer_id
having count(distinct active_week) = 
(select count(distinct yearweek(order_date)) from orders 
where order_date >= date_sub(current_date(), interval 6 quarter));

-- Question: Can you share total revenue for last week by weekday?
select dayname(order_date) as active_week, sum(amount)
from orders
where order_date >= 
date_sub((select max(order_date) from orders), -- get latest date in dataset
interval(select 7 + weekday(max(order_date)) from orders) day)  -- go back to last Monday
and order_date <= 
date_sub((select max(order_date) from orders), -- latest date again
interval(select 1 + weekday(max(order_date)) from orders) day) -- reach current week Sunday
group by dayname(order_date)
order by field(active_week, 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'); -- sort in proper week order



