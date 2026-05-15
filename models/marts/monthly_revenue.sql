-- models/marts/monthly_revenue.sql
-- Rapport mensuel : revenus, commandes, clients actifs

with orders as (
    select * from {{ ref('fct_orders') }}
),

monthly as (
    select
        order_year,
        order_month,
        -- Label lisible
        cast(order_year as varchar) || '-' ||
        lpad(cast(order_month as varchar), 2, '0')          as month_label,

        -- Volume
        count(order_id)                                     as total_orders,
        count(case when not is_cancelled then 1 end)        as completed_orders,
        count(case when is_cancelled then 1 end)            as cancelled_orders,

        -- Clients
        count(distinct customer_id)                         as active_customers,

        -- Revenus
        sum(case when not is_cancelled then gross_amount else 0 end) as gross_revenue,
        sum(case when not is_cancelled then discount_amount else 0 end) as total_discounts,
        sum(case when not is_cancelled then net_amount else 0 end)   as net_revenue,
        sum(case when not is_cancelled then estimated_profit else 0 end) as estimated_profit,

        -- Panier moyen
        round(
            sum(case when not is_cancelled then net_amount else 0 end)
            / nullif(count(case when not is_cancelled then 1 end), 0),
            2
        )                                                   as avg_order_value,

        -- Taux annulation
        round(
            100.0 * count(case when is_cancelled then 1 end)
            / nullif(count(order_id), 0),
            2
        )                                                   as cancellation_rate_pct

    from orders
    group by order_year, order_month
)

select * from monthly
order by order_year, order_month
