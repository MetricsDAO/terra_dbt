{{ config(
    materialized = 'view',
    secure = true
) }}

WITH messages AS (

    SELECT
        *
    FROM
        {{ ref('silver__msgs') }}
)

SELECT
  block_id,
  block_timestamp,
  blockchain,
  chain_id,
  tx_id,
  tx_succeeded,
  msg_group,
  msg_index,
  msg_type,
  msg
FROM
  messages