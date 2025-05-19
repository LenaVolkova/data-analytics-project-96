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
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_date as (
    select
        visitor_id,
        max(visit_date) as last_visit_date
    from paid_clicks
    group by visitor_id
)

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
inner join last_date on paid_clicks.visitor_id = last_date.visitor_id
where paid_clicks.visit_date = last_date.last_visit_date
order by
    amount desc nulls last, visit_date asc, utm_source asc, utm_medium asc, utm_campaign asc;


