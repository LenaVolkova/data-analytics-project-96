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
)
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
left join last_paid_sessions
	on sessions.visitor_id = last_paid_sessions.visitor_id
order by leads.amount desc nulls last,
	last_paid_sessions.visit_date,
	last_paid_sessions.utm_source, 
	last_paid_sessions.utm_medium,
	last_paid_sessions.utm_campaign;
