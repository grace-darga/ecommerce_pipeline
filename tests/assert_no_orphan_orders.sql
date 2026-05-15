-- tests/assert_no_orphan_orders.sql
-- Vérifie qu'aucune commande n'est orpheline (sans client valide)

select
    o.order_id,
    o.customer_id
from {{ ref('stg_orders') }} o
left join {{ ref('stg_customers') }} c
    on o.customer_id = c.customer_id
where c.customer_id is null
