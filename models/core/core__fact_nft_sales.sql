{{ config(
    materialized = 'view',
    secure = true
) }}

WITH nft_sales AS (

    SELECT
        *
    FROM
        {{ ref('silver__nft_sales') }}
)
SELECT
    block_id,
    block_timestamp,
    blockchain,
    chain_id,
    tx_id,
    tx_succeeded,
    decimals,
    purchaser,
    seller,
    sales_amount,
    currency,
    marketplace,
    contract_address,
    token_id
FROM
    nft_sales
