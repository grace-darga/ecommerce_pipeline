-- models/marts/dim_products.sql
-- Dimension produits enrichie avec performance commerciale

with products as (
    select * from {{ ref('stg_products') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
    where status != 'cancelled'
),

-- Performance par produit
product_sales as (
    select
        product_id,
        count(order_id)                         as total_orders,
        sum(quantity)                           as total_units_sold,
        sum(net_amount)                         as total_revenue,
        sum(gross_amount)                       as total_gross_revenue,
        sum(discount_amount)                    as total_discount_given,
        avg(discount_pct)                       as avg_discount_pct,
        count(distinct customer_id)             as unique_customers
    from orders
    group by product_id
),

final as (
    select
        -- Clés
        p.product_id,

        -- Attributs produit
        p.product_name,
        p.category,
        p.supplier,
        p.unit_price,
        p.cost_price,
        p.gross_margin,
        p.margin_pct,
        p.is_active,

        -- Performance commerciale
        coalesce(s.total_orders, 0)             as total_orders,
        coalesce(s.total_units_sold, 0)         as total_units_sold,
        coalesce(s.total_revenue, 0)            as total_revenue,
        coalesce(s.total_gross_revenue, 0)      as total_gross_revenue,
        coalesce(s.total_discount_given, 0)     as total_discount_given,
        coalesce(s.avg_discount_pct, 0)         as avg_discount_pct,
        coalesce(s.unique_customers, 0)         as unique_customers,

        -- Revenu total * marge = profit estimé
        round(
            coalesce(s.total_units_sold, 0) * p.gross_margin,
            2
        )                                       as estimated_profit,

        -- Classement popularité
        case
            when coalesce(s.total_units_sold, 0) >= 5 then 'Bestseller'
            when coalesce(s.total_units_sold, 0) >= 2 then 'Normal'
            when coalesce(s.total_units_sold, 0) = 0  then 'No Sales'
            else 'Slow Mover'
        end                                     as popularity_tier

    from products p
    left join product_sales s on p.product_id = s.product_id
)

select * from final
