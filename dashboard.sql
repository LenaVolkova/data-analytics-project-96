-- as the basic I use datamart from previous steps of the project - aggregate_las_paid_click
-- using this data I calculate parameters and metrics for the dashboard
with paid_sessions as ( 
	select 
		sessions.visitor_id,
		sessions.source as utm_source,
		sessions.medium as utm_medium,
		sessions.campaign as utm_campaign,
		sessions.visit_date
	from sessions
	left join leads on sessions.visitor_id = leads.visitor_id
	where sessions.medium != 'organic' and sessions.visit_date <= leads.created_at
),
last_paid_sessions as ( -- here I define last paid click for each lead
	select 
		distinct visitor_id,
		last_value(utm_source) over (
			partition by visitor_id
			order by visit_date
			) as utm_source,
		last_value(utm_medium) over (
			partition by visitor_id
			order by visit_date
			) as utm_medium,
		last_value(utm_campaign) over (
			partition by visitor_id
			order by visit_date
			) as utm_campaign,
		last_value(visit_date) over (
			partition by visitor_id
			order by visit_date
			) as visit_date
	from paid_sessions
),
purchases as ( -- here I find last paid click and amount for purchases and count them
	select
		date_trunc('day', visit_date) as visit_date,
		utm_source,
		utm_medium, 
		utm_campaign,
		count(lead_id) as purchases_count,
		sum(amount) as revenue
	from last_paid_sessions 
	join leads on last_paid_sessions.visitor_id = leads.visitor_id
	where (closing_reason = 'Успешно реализовано' or status_id = '142') 
	and date_trunc('day', visit_date) = date_trunc('day', leads.created_at)
	group by date_trunc('day', visit_date), utm_source, utm_medium, utm_campaign
),
leads_counts as ( 
	select
		date_trunc('day', visit_date) as visit_date,
		utm_source,
		utm_medium, 
		utm_campaign,
		count(lead_id) as leads_count
	from last_paid_sessions 
	join leads on last_paid_sessions.visitor_id = leads.visitor_id
	and date_trunc('day', visit_date) = date_trunc('day', leads.created_at)
	group by date_trunc('day', visit_date), utm_source, utm_medium, utm_campaign
),
aggregated_data as ( --this is aggregated data for paid clicks, leads and purchases by date, source, medium, campaign
	select 
		date_trunc('day',sessions.visit_date) as visit_date,
		source as utm_source,
		medium as utm_medium, 
		campaign as utm_campaign,
		count(sessions.visitor_id) as visitors_count,
		coalesce(vk_ads.daily_spent, 0) + coalesce(ya_ads.daily_spent, 0) as total_cost,
		coalesce(leads_count, 0) as leads_count,
		coalesce(purchases_count, 0) as purchases_count,
		coalesce(revenue, 0) as revenue
	from sessions
	left join leads_counts on 
	date_trunc('day', sessions.visit_date) = leads_counts.visit_date and 
	sessions.source = leads_counts.utm_source and
	sessions.medium = leads_counts.utm_medium and
	sessions.campaign  = leads_counts.utm_campaign
	left join vk_ads on 
	date_trunc('day', sessions.visit_date) = vk_ads.campaign_date and 
	sessions.source = vk_ads.utm_source and
	sessions.medium = vk_ads.utm_medium and
	sessions.campaign  = vk_ads.utm_campaign and
	sessions.content = vk_ads.utm_content
	left join ya_ads on 
	date_trunc('day', sessions.visit_date) = ya_ads.campaign_date and 
	sessions.source = ya_ads.utm_source and
	sessions.medium = ya_ads.utm_medium and
	sessions.campaign  = ya_ads.utm_campaign and
	sessions.content = ya_ads.utm_content
	left join purchases on 
	date_trunc('day', sessions.visit_date) = purchases.visit_date and 
	sessions.source = purchases.utm_source and
	sessions.medium = purchases.utm_medium and
	sessions.campaign  = purchases.utm_campaign
	group by date_trunc('day', sessions.visit_date), source, medium, campaign, total_cost, leads_count, purchases_count, revenue
	order by revenue desc, visit_date, visitors_count desc, utm_source, utm_medium, utm_campaign
),
aggregated_data_ya_vk as ( --for metrics calculation I filtered yandex and vk as only they have cost data
	SELECT *
  	from aggregated_data
  	where utm_source = 'yandex' or utm_source = 'vk'
) 
select -- here I calculate cpl, cppu and roi 
	utm_source,
	round(sum(total_cost)/sum(leads_count),2) as cpl,
	round(sum(total_cost)/sum(purchases_count), 2) as cppu,
	round((sum(revenue)-sum(total_cost))*100.00/sum(total_cost),2) as roi
from aggregated_data_ya_vk
group by utm_source
order by utm_source;

--CPU I have calculated the same way as above using aggregated data
SELECT
  utm_source,
  utm_medium,
  utm_campaign,
  visit_date,
  round(sum(total_cost)/sum(visitors_count),2) as cpu
from aggregated_data_ya_vk
group by utm_source, visit_date, utm_medium, utm_campaign;

-- to analyse costs I unite two tables in one request and then use it to create dataset and a chart for dashboard
SELECT
  ad_id,
  campaign_id,
  campaign_name,
  utm_source,
  utm_medium,
  utm_campaign,
  utm_content,
  campaign_date,
  daily_spent
from vk_ads 
UNION all
select * from ya_ads;

-- I used datamart "last paid click" for calculation of lead's duration in days:
with paid_sessions as (
	select 
		sessions.visitor_id,
		sessions.source as utm_source,
		sessions.medium as utm_medium,
		sessions.campaign as utm_campaign,
		sessions.visit_date
	from sessions
	left join leads on sessions.visitor_id = leads.visitor_id
	where sessions.medium != 'organic' and sessions.visit_date <= leads.created_at
),
last_paid_sessions as (
	select 
		distinct visitor_id,
		last_value(utm_source) over (
			partition by visitor_id
			order by visit_date
			) as utm_source,
		last_value(utm_medium) over (
			partition by visitor_id
			order by visit_date
			) as utm_medium,
		last_value(utm_campaign) over (
			partition by visitor_id
			order by visit_date
			) as utm_campaign,
		last_value(visit_date) over (
			partition by visitor_id
			order by visit_date
			) as visit_date
	from paid_sessions
),
last_paid_clicks as (
	select 
		distinct sessions.visitor_id,
  		last_paid_sessions.visit_date,
		last_paid_sessions.utm_source,
		last_paid_sessions.utm_medium,
		last_paid_sessions.utm_campaign,
		leads.lead_id,
		leads.created_at,
		leads.amount,
		leads.closing_reason,
		leads.status_id
	from sessions
	left join leads on sessions.visitor_id = leads.visitor_id
	join last_paid_sessions
	on sessions.visitor_id = last_paid_sessions.visitor_id
	order by leads.amount desc nulls last,
		last_paid_sessions.visit_date,
		last_paid_sessions.utm_source, 
		last_paid_sessions.utm_medium,
		last_paid_sessions.utm_campaign
)
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

--to analyse if there is any impact on organic visits from ad-campaigns I use folloeing SQL:
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