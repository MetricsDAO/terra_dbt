{{ config(
    materialized = "incremental",
    cluster_by = ["_inserted_timestamp"],
    unique_key = "mint_id",
) }}


with
    nft_mints as (
        select
            block_id,
            block_timestamp,
            'terra' as blockchain,
            chain_id,
            tx_id,
            tx_succeeded,
            case
                when attributes:wasm:_contract_address is not null
                then attributes:wasm:_contract_address::string
                when attributes:wasm:_contract_address_1 is not null
                then attributes:wasm:_contract_address_1::string
                when
                    message_value:msg:mint:mint_request:nft_contract is not null
                then message_value:msg:mint:mint_request:nft_contract::string
                else null
            end as contract_address,
            message_value:msg:mint as mint_obj,
            attributes,
            nullif(message_value:funds[0]:amount::bigint, 0) as mint_price,
            message_value:sender::string as minter,
            attributes:wasm:token_id::string as token_id,
            attributes:coin_spent:currency_0::string as currency,
            null as decimals,
            row_number() over (
                partition by tx_id order by _inserted_timestamp desc
            ) as index,
            concat(tx_id, '-', index) as mint_id,
            _ingested_at,
            _inserted_timestamp
        from  {{ ref('silver__messages') }}
        where
            (
                message_value:msg:mint:extension is not null
                or message_value:msg:mint:metadata_uri is not null
                or message_value:msg:mint:mint_request is not null
                or message_value:msg:mint:metadata is not null
            )
            and message_type != '/cosmwasm.wasm.v1.MsgInstantiateContract'
            and {{ incremental_load_filter("_inserted_timestamp") }}
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
    mint_id,
    _ingested_at,
    _inserted_timestamp
from nft_mints
