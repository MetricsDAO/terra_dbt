{{ config(
    materialized = 'view',
    secure = true
) }}

WITH msg_attributes AS (

    SELECT
        *
    FROM
        {{ ref('silver__msg_attributes') }}
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
  attribute_key,
  attribute_value,
  attribute_index
FROM
  msg_attributes