-- tests/assert_positive_net_amount.sql
-- Vérifie qu'aucune commande non-annulée n'a un montant négatif

select
    order_id,
    net_amount,
    status
from {{ ref('fct_orders') }}
where status != 'cancelled'
  and net_amount < 0
