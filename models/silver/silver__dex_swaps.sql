{{
    config(
        materialized="incremental",
        unique_key="tx_id",
        incremental_strategy="delete+insert",
        cluster_by=["block_timestamp::DATE", "_inserted_timestamp::DATE"],
    )
}}




with
    swap as (
        select
            block_id,
            block_timestamp,
            _inserted_timestamp,
            'Terra' as blockchain,
            chain_id,
            tx_id,
            tx_succeeded,
            message_value:sender::string as trader,
            message_value:msg:swap:offer_asset:amount::integer as from_amount,
            coalesce(
                attributes:coin_received:currency_0::string,
                attributes:coin_received:currency::string
            ) as from_currency,
            6 AS decimals,
            coalesce(
                attributes:coin_received:amount_1::integer,
                attributes:wasm:return_amount::integer
            ) as to_amount,
            attributes:wasm:ask_asset::string as to_currency,
            round(to_amount / pow(10, 6)) as to_decimal,
            message_value:contract::string as contract_address

        from {{ ref("silver__messages") }}
        where
            message_type ilike '%msgexecutecontract%'
            and message_value:msg:swap is not null
            and {{ incremental_load_filter("_inserted_timestamp") }}
    ),
    execute_swap_operations as (
        select
            block_id,
            block_timestamp,
            _inserted_timestamp,
            'Terra' as blockchain,
            chain_id,
            tx_id,
            tx_succeeded,
            message_value:sender::string as trader,
            coalesce(
                attributes:wasm:amount_0::integer,
                attributes:coin_received:amount_1::integer,
                attributes:coin_received:amount_2::integer
            ) as from_amount,
            coalesce(
                attributes:coin_received:currency_0::string,
                attributes:wasm:ask_asset_0::string
            ) as from_currency,
            round(from_amount / pow(10, 6)) as from_decimal,
            coalesce(
                attributes:wasm:return_amount_1::integer,
                attributes:wasm:return_amount::integer,
                attributes:coin_received:amount_5::integer,
                attributes:coin_received:amount_2::integer
            ) as to_amount,
            coalesce(
                attributes:coin_received:currency_2::string,
                attributes:coin_received:currency_1::string
            ) as to_currency,
            6 AS decimals,
            message_value:contract::string as contract_address,


            message_value,
            attributes
        from {{ ref("silver__messages") }}
        where
            message_type ilike '%msgexecutecontract%'
            and message_value:msg:execute_swap_operations is not null
            and {{ incremental_load_filter("_inserted_timestamp") }}
    ),
    union_swaps as (

        select
            block_id,
            block_timestamp,
            _inserted_timestamp,
            blockchain,
            chain_id,
            tx_id,
            tx_succeeded,
            from_amount,
            from_currency,
            from_decimal,
            to_amount,
            to_currency,
            to_decimal,
            contract_address
        from swap
        union all
        select
            block_id,
            block_timestamp,
            _inserted_timestamp,
            blockchain,
            chain_id,
            tx_id,
            tx_succeeded,
            from_amount,
            from_currency,
            from_decimal,
            to_amount,
            to_currency,
            to_decimal,
            contract_address
        from execute_swap_operations

    ),
    signer_address as (

        select u.*, t.tx_sender as trader
        from union_swaps u
        left join transactions t on u.tx_id = t.tx_id

    ),
    final as (
        select s.*, l.label as pool_id
        from signer_address s
        left outer join
            terra.core.dim_address_labels l on s.contract_address = l.address

    )

select
    block_id,
    block_timestamp,
    _inserted_timestamp,
    blockchain,
    chain_id,
    tx_id,
    tx_succeeded,
    trader,
    from_amount,
    from_currency,
    from_decimal,
    to_amount,
    to_currency,
    to_decimal,
    pool_id
from final
