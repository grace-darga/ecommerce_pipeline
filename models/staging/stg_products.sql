-- models/staging/stg_products.sql
-- Nettoyage et enrichissement des produits

with source as (
    select * from {{ ref('products') }}
),

renamed as (
    select
        -- Clés
        cast(product_id as integer)             as product_id,

        -- Attributs nettoyés
        trim(product_name)                      as product_name,
        trim(category)                          as category,
        trim(supplier)                          as supplier,

        -- Prix castés
        cast(unit_price as decimal(10,2))       as unit_price,
        cast(cost_price as decimal(10,2))       as cost_price,

        -- Marge brute calculée en staging
        round(
            cast(unit_price as decimal(10,2)) - cast(cost_price as decimal(10,2)),
            2
        )                                       as gross_margin,

        round(
            (cast(unit_price as decimal(10,2)) - cast(cost_price as decimal(10,2)))
            / cast(unit_price as decimal(10,2)) * 100,
            2
        )                                       as margin_pct,

        -- Booléen normalisé
        cast(is_active as boolean)              as is_active,

        -- Métadonnées pipeline
        current_timestamp                       as _loaded_at

    from source
)

select * from renamed
