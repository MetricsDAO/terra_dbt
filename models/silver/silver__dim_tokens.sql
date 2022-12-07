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
            message_value:msg:decimals::int as decimals,
            _ingested_at,
            _inserted_timestamp
        from {{ ref("silver__messages") }}
        where message_value:msg:decimals is not null
        and {{ incremental_load_filter("_inserted_timestamp") }}
    ),
    address_labels as (select * from {{ ref('core__dim_address_labels')}})


select
    'terra' as blockchain,
    token_labels.block_timestamp,
    token_labels.tx_id,
    token_labels.label,
    token_labels.symbol,
    token_labels.contract_address,
    token_labels.decimals,
    address_labels.creator,
    address_labels.label_type,
    address_labels.label_subtype,
    address_labels.project_name,
    token_labels._ingested_at,
    token_labels._inserted_timestamp
from token_labels
left join
    address_labels on token_labels.contract_address = address_labels.address
