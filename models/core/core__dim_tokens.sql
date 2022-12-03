{{ config(
    materialized = 'view',
    secure = true
) }}


WITH token_labels AS (

    SELECT
        *
    FROM
        {{ ref('silver__dim_tokens') }}
)

select
    blockchain,
    block_timestamp,
    tx_id,
    label,
    symbol,
    contract_address,
    decimals,
    creator,
    label_type,
    label_subtype,
    project_name
from token_labels