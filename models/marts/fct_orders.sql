-- models/marts/fct_orders.sql
-- Table de faits centrale : toutes les commandes enrichies

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select
        customer_id,
        full_name,
        email,
        country,
        segment,
        value_tier
    from {{ ref('dim_customers') }}
),

products as (
    select
        product_id,
        product_name,
        category,
        supplier,
        cost_price,
        margin_pct,
        popularity_tier
    from {{ ref('dim_products') }}
),

final as (
    select
        -- Clés
        o.order_id,
        o.customer_id,
        o.product_id,

        -- Dates
        o.order_date,
        o.order_year,
        o.order_month,
        o.order_quarter,

        -- Infos client dénormalisées
        c.full_name                             as customer_name,
        c.country                               as customer_country,
        c.segment                               as customer_segment,
        c.value_tier                            as customer_value_tier,

        -- Infos produit dénormalisées
        p.product_name,
        p.category                              as product_category,
        p.supplier,
        p.popularity_tier                       as product_popularity,

        -- Métriques financières
        o.quantity,
        o.unit_price,
        o.discount_pct,
        o.gross_amount,
        o.discount_amount,
        o.net_amount,

        -- Profit estimé (net - coût)
        round(o.quantity * (o.unit_price - p.cost_price) * (1 - o.discount_pct / 100), 2) as estimated_profit,

        -- Statut & paiement
        o.status,
        o.payment_method,

        -- Flag annulation
        case when o.status = 'cancelled' then true else false end as is_cancelled

    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join products p  on o.product_id  = p.product_id
)

select * from final
