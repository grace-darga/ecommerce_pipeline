-- models/staging/stg_customers.sql
-- Nettoyage et typage des clients bruts

with source as (
    select * from {{ ref('customers') }}
),

renamed as (
    select
        -- Clés
        cast(customer_id as integer)            as customer_id,

        -- Attributs nettoyés
        trim(first_name)                        as first_name,
        trim(last_name)                         as last_name,
        lower(trim(email))                      as email,
        trim(country)                           as country,

        -- Segmentation normalisée
        upper(trim(segment))                    as segment,

        -- Dates
        cast(created_at as date)                as created_at,

        -- Métadonnées pipeline
        current_timestamp                       as _loaded_at

    from source
)

select * from renamed
