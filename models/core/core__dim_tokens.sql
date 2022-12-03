{{
    config(
        materialized="incremental",
        cluster_by=["_inserted_timestamp::DATE"],
        unique_key = "contract_address",
    )
}}

with
    token_labels as (
        select
            block_timestamp,
            tx_id,
            message_value:msg:name::string as label,
            message_value:msg:symbol::string as symbol,
            iff(
                attributes:instantiate:_contract_address is not null,
                attributes:instantiate:_contract_address,
                attributes:reply:_contract_address
            )::string as contract_address,
            message_value:msg:decimals::int as decimals
        from {{ ref("silver__messages") }}
        where message_value:msg:decimals is not null
    ),
    address_labels as (select * from {{ ref('core__dim_address_labels')}})


select
    'terra' as blockchain,
    token_labels.*,
    address_labels.creator,
    address_labels.label_type,
    address_labels.label_subtype,
    address_labels.project_name
from token_labels
left join
    address_labels on token_labels.contract_address = address_labels.address
