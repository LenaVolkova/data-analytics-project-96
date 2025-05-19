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
        l.status_id,
        row_number()
            over (
                partition by s.visitor_id
                order by s.visit_date desc
            )
        as rn
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_paid_clicks as (
    select
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    from paid_clicks
    where rn = 1
    order by
        amount desc nulls last,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

costs_by_day as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        to_char(campaign_date, 'YYYY-MM-DD') as visit_date,
        sum(daily_spent) as total_cost
    from vk_ads
    group by
        to_char(campaign_date, 'YYYY-MM-DD'),
        utm_source,
        utm_medium,
        utm_campaign
    union all
    select
        utm_source,
        utm_medium,
        utm_campaign,
        to_char(campaign_date, 'YYYY-MM-DD') as visit_date,
        sum(daily_spent) as total_cost
    from ya_ads
    group by
        to_char(campaign_date, 'YYYY-MM-DD'),
        utm_source,
        utm_medium,
        utm_campaign
)

select
    to_char(lpc.visit_date, 'YYYY-MM-DD') as visit_date,
    count(distinct lpc.visitor_id) as visitors_count,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    c.total_cost,
    count(lpc.lead_id) as leads_count,
    sum(
        case
            when
                lpc.status_id = '142'
                or lpc.closing_reason = 'Успешная проадажа'
                then 1
            else 0
        end
    ) as purchases_count,
    sum(
        case
            when
                lpc.status_id = '142'
                or lpc.closing_reason = 'Успешная проадажа'
                then lpc.amount
            else 0
        end
    ) as revenue
from last_paid_clicks as lpc
left join costs_by_day as c
    on
        to_char(lpc.visit_date, 'YYYY-MM-DD') = c.visit_date
        and lpc.utm_source = c.utm_source
        and lpc.utm_medium = c.utm_medium
        and lpc.utm_campaign = c.utm_campaign
group by
    to_char(lpc.visit_date, 'YYYY-MM-DD'),
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    c.total_cost
order by
    revenue desc nulls last,
    to_char(lpc.visit_date, 'YYYY-MM-DD') asc,
    count(lpc.visitor_id) desc,
    lpc.utm_source asc,
    lpc.utm_medium asc,
    lpc.utm_campaign asc;
