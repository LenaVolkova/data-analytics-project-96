with paid_clicks as (
	select 
		s.visitor_id,
		s.visit_date,
		s.source as utm_source,
		s.medium as utm_medium,
		s.campaign as utm_campaign,
		l.lead_id,
		l.created_at,
		l.amount,
		l.closing_reason,
		l.status_id
	from sessions s
	left join leads l on s.visitor_id = l.visitor_id
	where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
		and ((s.visit_date <= l.created_at) or (l.created_at is null))
),
last_date as (
	select
		visitor_id,
		max(visit_date) as last_visit_date
	from paid_clicks 
	group by visitor_id
), 
last_paid_clicks as (
	select 
		last_date.visitor_id,
		last_date.last_visit_date as visit_date,
		paid_clicks.utm_source,
		paid_clicks.utm_medium,
		paid_clicks.utm_campaign,
		paid_clicks.lead_id,
		paid_clicks.created_at,
		paid_clicks.amount,
		paid_clicks.closing_reason,
		paid_clicks.status_id
	from paid_clicks
	join last_date on paid_clicks.visitor_id = last_date.visitor_id
	where paid_clicks.visit_date = last_date.last_visit_date
	order by amount desc nulls last, visit_date, utm_source, utm_medium, utm_campaign
),
costs as (
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
	select * from ya_ads
),
purchases as (
	select
		date_trunc('day', visit_date) as visit_date,
		utm_source,
		utm_medium,
		utm_campaign,
		count(lead_id) as purchases_count,
		sum(amount) as revenue
	from last_paid_clicks
	where last_paid_clicks.status_id = '142'
	group by date_trunc('day', visit_date), utm_source, utm_medium, utm_campaign
), 
visitors as (
	select
		date_trunc('day', visit_date) as visit_date,
		source as utm_source,
		medium as utm_medium,
		campaign as utm_campaign,
		count(visitor_id) as visitors_count
	from sessions
	group by date_trunc('day', visit_date), utm_source, utm_medium, utm_campaign
)
select 
	date_trunc('day', lpc.visit_date) as visit_date,
	lpc.utm_source,
	lpc.utm_medium,
	lpc.utm_campaign,
	v.visitors_count,
	sum(c.daily_spent) as total_cost,
	count(lpc.lead_id) as leads_count,
	p.purchases_count,
	p.revenue
from last_paid_clicks lpc
left join costs c on date_trunc('day', lpc.visit_date) = c.campaign_date and 
	lpc.utm_source = c.utm_source and 
	lpc.utm_medium = c.utm_medium and 
	lpc.utm_campaign = c.utm_campaign
left join purchases p on date_trunc('day', lpc.visit_date) = p.visit_date  and 
	lpc.utm_source = p.utm_source and 
	lpc.utm_medium = p.utm_medium and 
	lpc.utm_campaign = p.utm_campaign
left join visitors v on date_trunc('day', lpc.visit_date) = v.visit_date and 
	lpc.utm_source = v.utm_source and 
	lpc.utm_medium = v.utm_medium and 
	lpc.utm_campaign = v.utm_campaign
group by date_trunc('day', lpc.visit_date), lpc.utm_source, lpc.utm_medium, lpc.utm_campaign, v.visitors_count, p.purchases_count, p.revenue
order by p.revenue desc nulls last, date_trunc('day', lpc.visit_date), visitors_count desc, utm_source, utm_medium, utm_campaign;

