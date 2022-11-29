{{ config(materialized="view", secure=true) }}

with staking as (select * from {{ ref("silver__staking") }})

select 
   staking.blockchain,
   block_id,
   block_timestamp,
   tx_id,
   tx_succeeded,
   chain_id,
   msg_index AS message_index,
   action,
   delegator_address,
   amount,
   validator_address,
   validator_src_address,
   validator_label.label AS validator_label,
   validator_src_label.label AS validator_src_label

from staking 
Left outer JOIN {{ ref('core__dim_address_labels') }} validator_label
ON validator_label.address = staking.validator_address
LEFT OUTER JOIN {{ ref('core__dim_address_labels') }} validator_src_label
ON validator_src_label.address = staking.validator_src_address