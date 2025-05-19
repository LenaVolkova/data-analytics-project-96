--Total quantity of visitors, session and purchases:
with totals as (
    select
        'visitors' as name,
        count(distinct visitor_id) as quantity
    from sessions
    union
    select
        'leads' as name,
        count(distinct lead_id) as quantity
    from leads
    union
    select
        'purchases' as name,
        count(distinct lead_id) as quantity
    from leads
    where closing_reason = 'Успешная продажа'
)

select
    'click to lead' as conversion,
    --conversion rate for click to lead
    round((c.quantity) / (l.quantity), 2) as rate
from totals as c, totals as l
where c.name = 'visitors' and l.name = 'leads'
union
select
    'lead to purchase' as conversion,
    -- conversion rate for lead to purchase
    round((l.quantity) / (p.quantity), 2) as rate
from totals as p, totals as l
where p.name = 'purchases' and l.name = 'leads';

-- Basic metrics calculated using aggregated_last_paid_click script (ALPC):
select
    'yandex' as source,
    round(sum(total_cost) / sum(visitors_count), 2) as cpu, --cost per user
    round(sum(total_cost) / sum(leads_count), 2) as cpl, -- cost per lead
    -- cost per paying user
    round(sum(total_cost) / sum(purchases_count), 2) as cpl,
    -- return on investment
    round((sum(revenue) - sum(total_cost)) * 100 / sum(total_cost), 2) as roi
from alpc
where utm_source = 'yandex'
union
select
    'vk' as source,
    round(sum(total_cost) / sum(visitors_count), 2) as cpu,
    round(sum(total_cost) / sum(leads_count), 2) as cpl,
    round(sum(total_cost) / sum(purchases_count), 2) as cppu,
    round((sum(revenue) - sum(total_cost)) * 100 / sum(total_cost), 2) as roi
from alpc
where utm_source = 'vk';

-- Scropt last_paid_click (LPC) is used to calculate how many days is needed to close 90% of leads:
select
    created_at::DATE as lead_date,
    visit_date::DATE as click_date,
    created_at::DATE - visit_date::DATE as lead_life,
    ntile(10) over (
        order by
            created_at::DATE - visit_date::DATE
    ) as ntile_lead
from lpc
where closing_reason in ('Успешная продажа', 'Не реализовано');

