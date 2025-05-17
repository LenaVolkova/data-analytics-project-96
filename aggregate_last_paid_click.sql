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
	left join leads l on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
	where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
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
purchases as (
	select
		to_char(visit_date, 'YYYY-MM-DD') as visit_date,
		utm_source,
		utm_medium,
		utm_campaign,
		count(lead_id) as purchases_count,
		sum(amount) as revenue
	from last_paid_clicks
	where status_id = '142' or closing_reason = 'Успешная продажа'
	group by to_char(visit_date, 'YYYY-MM-DD'), utm_source, utm_medium, utm_campaign
),
costs as (
	select 
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
	union all
	select * from ya_ads
),
costs_by_day as (
	select 
		to_char(campaign_date, 'YYYY-MM-DD') as visit_date,
		sum(daily_spent) as total_cost,
		utm_source,
		utm_medium,
		utm_campaign
	from costs
	group by to_char(campaign_date, 'YYYY-MM-DD'), utm_source, utm_medium, utm_campaign
)
select
	to_char(lpc.visit_date, 'YYYY-MM-DD') as visit_date,
	count(distinct lpc.visitor_id) as visitors_count,
	lpc.utm_source,
	lpc.utm_medium,
	lpc.utm_campaign,
	c.total_cost,
	count(distinct lpc.lead_id) as leads_count,
	p.purchases_count,
	p.revenue
from last_paid_clicks lpc
left join purchases p on to_char(lpc.visit_date, 'YYYY-MM-DD') = p.visit_date
	and lpc.utm_source = p.utm_source
	and lpc.utm_medium = p.utm_medium
	and lpc.utm_campaign = p.utm_campaign
left join costs_by_day c 
	on to_char(lpc.visit_date, 'YYYY-MM-DD') = c.visit_date
	and lpc.utm_source = c.utm_source
	and lpc.utm_medium = c.utm_medium
	and lpc.utm_campaign = c.utm_campaign
group by to_char(lpc.visit_date, 'YYYY-MM-DD'), lpc.utm_source, lpc.utm_medium,
	lpc.utm_campaign,	p.purchases_count, c.total_cost,
	p.revenue
order by revenue desc nulls last, to_char(lpc.visit_date, 'YYYY-MM-DD'),
	count(lpc.visitor_id) desc, lpc.utm_source,
	lpc.utm_medium,
	lpc.utm_campaign;