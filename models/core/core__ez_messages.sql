{{ config(
    materialized = 'view',
    secure = true
) }}

WITH messages AS (

    SELECT
        *
    FROM
        {{ ref('silver__messages') }}
)
SELECT
    message_id,
    block_timestamp,
    block_id,
    tx_id,
    tx_succeeded,
    chain_id,
    message_index,
    message_type,
    message_value,
    attributes
FROM
    messages
