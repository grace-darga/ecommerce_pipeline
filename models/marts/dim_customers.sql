-- models/marts/dim_customers.sql
-- Dimension clients enrichie avec métriques comportementales

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
    where status != 'cancelled'
),

-- Agrégation des métriques par client
customer_metrics as (
    select
        customer_id,
        count(order_id)                         as total_orders,
        sum(net_amount)                         as total_revenue,
        avg(net_amount)                         as avg_order_value,
        min(order_date)                         as first_order_date,
        max(order_date)                         as last_order_date,
        count(distinct product_id)              as unique_products_bought,
        sum(discount_amount)                    as total_discount_received
    from orders
    group by customer_id
),

final as (
    select
        -- Clés
        c.customer_id,

        -- Identité
        c.first_name,
        c.last_name,
        c.first_name || ' ' || c.last_name      as full_name,
        c.email,
        c.country,
        c.segment,
        c.created_at,

        -- Métriques commandes (avec coalesces pour les clients sans commande)
        coalesce(m.total_orders, 0)             as total_orders,
        coalesce(m.total_revenue, 0)            as total_revenue,
        coalesce(m.avg_order_value, 0)          as avg_order_value,
        m.first_order_date,
        m.last_order_date,
        coalesce(m.unique_products_bought, 0)   as unique_products_bought,
        coalesce(m.total_discount_received, 0)  as total_discount_received,

        -- Catégorisation RFM simplifiée
        case
            when coalesce(m.total_revenue, 0) >= 2000 then 'High Value'
            when coalesce(m.total_revenue, 0) >= 500  then 'Mid Value'
            else 'Low Value'
        end                                     as value_tier,

        -- Ancienneté en jours
        date_diff('day', c.created_at, current_date) as days_since_signup

    from customers c
    left join customer_metrics m on c.customer_id = m.customer_id
)

select * from final
