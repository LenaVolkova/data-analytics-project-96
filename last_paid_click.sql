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
)
select 
	distinct visitor_id,
	last_value(visit_date) over (
			partition by visitor_id
			order by visit_date
			) as visit_date,
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
	lead_id,
	created_at,
	amount,
	closing_reason,
	status_id
from paid_clicks
order by amount desc nulls last, visit_date, utm_source, utm_medium, utm_campaign;

