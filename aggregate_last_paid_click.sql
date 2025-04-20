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
--	where sessions.visit_date <= leads.created_at
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
purchases as (
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
)
select 
	date_trunc('day',sessions.visit_date) as visit_date,
	source as utm_source,
	medium as utm_medium, 
	campaign as utm_campaign,
	count(sessions.visitor_id) as visitors_count,
	coalesce(vk_ads.daily_spent, 0) + coalesce(ya_ads.daily_spent, 0) as total_cost,
	count(lead_id) as leads_count,
	coalesce(purchases_count, 0) as purchases_count,
	coalesce(revenue, 0) as revenue
from sessions
join leads on sessions.visitor_id = leads.visitor_id
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
where date_trunc('day', sessions.visit_date) = date_trunc('day',leads.created_at)
group by date_trunc('day', sessions.visit_date), source, medium, campaign, total_cost, purchases_count, revenue
order by revenue desc, visit_date, visitors_count desc, utm_source, utm_medium, utm_campaign;

