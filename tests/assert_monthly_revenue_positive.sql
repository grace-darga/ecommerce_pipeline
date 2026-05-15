-- tests/assert_monthly_revenue_positive.sql
-- Vérifie que le revenu net mensuel est toujours positif

select
    month_label,
    net_revenue
from {{ ref('monthly_revenue') }}
where net_revenue < 0
