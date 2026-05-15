-- tests/assert_margin_consistency.sql
-- Vérifie que la marge brute = unit_price - cost_price (tolérance 0.01)

select
    product_id,
    product_name,
    unit_price,
    cost_price,
    gross_margin,
    round(unit_price - cost_price, 2) as expected_margin
from {{ ref('dim_products') }}
where abs(gross_margin - round(unit_price - cost_price, 2)) > 0.01
