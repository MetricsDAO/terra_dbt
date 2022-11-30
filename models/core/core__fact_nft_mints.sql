{{ config(
    materialized = 'view',
    secure = true
) }}

WITH nft_mints AS (

    SELECT
        *
    FROM
        {{ ref('silver__nft_mints') }}
)

select
    block_id,
    block_timestamp,
    blockchain,
    chain_id,
    tx_id,
    tx_succeeded,
    contract_address,
    mint_price,
    minter,
    token_id,
    currency,
    decimals,
    mint_id
from nft_mints