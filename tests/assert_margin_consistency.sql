-- tests/assert_margin_consistency.sql
-- Vérifie que la marge brute est cohérente avec unit_price - cost_price
-- Tolérance : 0.01€ pour les arrondis DECIMAL

select
    product_id,
    gross_margin,
    round(unit_price - cost_price, 2) as expected_margin,
    abs(gross_margin - round(unit_price - cost_price, 2)) as delta
from {{ ref('dim_products') }}
where abs(gross_margin - round(unit_price - cost_price, 2)) > 0.01