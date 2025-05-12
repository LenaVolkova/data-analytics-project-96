SELECT
  visit_date,
  created_at,
  extract( day from (created_at - visit_date)) as lead_days,
  closing_reason,
  lead_id,
  NTILE(10) OVER ( --here I use ntile to calculate how much days needs to close 90% of leads
    order by 
      (extract( day from (created_at - visit_date)))
      ) as ntile_days
from last_paid_clicks;

--to analyse if there is any impact on organic visits from ad-campaigns I use following SQL:
with organic_visits as ( -- counts organic visits per day
	select
		date_trunc('day', visit_date) as visit_date,
		count(visitor_id) as clicks
	from sessions
	where source = 'organic'
	group by date_trunc('day', visit_date)
	order by date_trunc('day', visit_date)
),
campaigns as ( -- counts distinct campaigns per day
	select 
		date_trunc('day', visit_date) as visit_date,
		count (distinct campaign) as campaign_counts
	from sessions
	group by date_trunc('day', visit_date)
	order by date_trunc('day', visit_date)
)
select -- here we can see for each date quantity of organic visits and quantity of active campaigns
	organic_visits.visit_date,
	organic_visits.clicks,
	campaigns.campaign_counts
from organic_visits
join campaigns on organic_visits.visit_date = campaigns.visit_date
order by organic_visits.visit_date;
-- for the chart I multiply campaign counts by 100 in order to see more preciesly the form of curve
-- and be able to compare form of lines