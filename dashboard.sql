--Total quantity of visitors, session and purchases:
with totals as (
select 
  'visitors' as name,
  count (distinct visitor_id) as quantity
  from sessions
union 
select 
  'leads' as name,
  count (distinct lead_id) as quantity
  from leads
union
SELECT
  'purchases' as name,
  count (DISTINCT lead_id) as quantity
  from leads
  where closing_reason = 'Успешная продажа'
)
SELECT
  'click to lead' as conversion,
  round((c.quantity)/(l.quantity),2) as rate  --conversion rate for click to lead
  from totals c, totals l 
  where c.name = 'visitors' and l.name = 'leads'
UNION
SELECT
  'lead to purchase' as conversion,
  round((l.quantity)/(p.quantity),2) as rate -- conversion rate for lead to purchase
  from totals p, totals l 
  where p.name = 'purchases' and l.name = 'leads';

-- Basic metrics calculated using aggregated_last_paid_click script (ALPC):
select 
  'yandex' as source,
  round(sum(total_cost)/sum(visitors_count),2) as CPU, --cost per user
  round(sum(total_cost)/sum(leads_count),2) as CPL, -- cost per lead
  round(sum(total_cost)/sum(purchases_count),2) as CPL, -- cost per paying user
  round((sum(revenue)-sum(total_cost))*100/sum(total_cost),2) as ROI -- return on investment
from ALPC
where utm_source = 'yandex'
UNION
select 
  'vk' as source,
  round(sum(total_cost)/sum(visitors_count),2) as CPU,
  round(sum(total_cost)/sum(leads_count),2) as CPL,
  round(sum(total_cost)/sum(purchases_count),2) as CPPU,
  round((sum(revenue)-sum(total_cost))*100/sum(total_cost),2) as ROI
from ALPC
where utm_source = 'vk'
;

-- Scropt last_paid_click (LPC) is used to calculate how many days is needed to close 90% of leads:
select 
  created_at::DATE as lead_date,
  visit_date::DATE as click_date,
  created_at::DATE - visit_date::DATE as lead_life,
  NTILE(10) OVER (
    order by 
    created_at::DATE - visit_date::DATE
    ) as ntile_lead
from LPC
where closing_reason IN ('Успешная продажа', 'Не реализовано')
;
