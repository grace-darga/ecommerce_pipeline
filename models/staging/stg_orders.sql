-- models/staging/stg_orders.sql
-- Nettoyage des commandes avec calculs financiers de base

with source as (
    select * from {{ ref('orders') }}
),

renamed as (
    select
        -- Clés
        cast(order_id as integer)               as order_id,
        cast(customer_id as integer)            as customer_id,
        cast(product_id as integer)             as product_id,

        -- Quantité et prix
        cast(quantity as integer)               as quantity,
        cast(unit_price as decimal(10,2))       as unit_price,
        cast(discount_pct as decimal(5,2))      as discount_pct,

        -- Montants calculés
        round(
            cast(quantity as integer)
            * cast(unit_price as decimal(10,2))
            * (1 - cast(discount_pct as decimal(5,2)) / 100),
            2
        )                                       as net_amount,

        round(
            cast(quantity as integer)
            * cast(unit_price as decimal(10,2)),
            2
        )                                       as gross_amount,

        round(
            cast(quantity as integer)
            * cast(unit_price as decimal(10,2))
            * cast(discount_pct as decimal(5,2)) / 100,
            2
        )                                       as discount_amount,

        -- Statut normalisé
        lower(trim(status))                     as status,

        -- Paiement normalisé
        lower(trim(payment_method))             as payment_method,

        -- Dates
        cast(order_date as date)                as order_date,
        date_part('year', cast(order_date as date))   as order_year,
        date_part('month', cast(order_date as date))  as order_month,
        date_part('quarter', cast(order_date as date)) as order_quarter,

        -- Métadonnées pipeline
        current_timestamp                       as _loaded_at

    from source
)

select * from renamed
