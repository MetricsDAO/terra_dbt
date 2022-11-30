{{
    config(
        materialized="incremental",
        unique_key="SWAP_ID",
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
            message_index as msg_index,
            message_value:msg:swap:offer_asset:amount::integer as from_amount,
            coalesce(
                attributes:coin_received:currency_0::string,
                attributes:coin_received:currency::string
            ) as from_currency,
            6::integer as from_decimal,
            coalesce(
                attributes:coin_received:amount_1::integer,
                attributes:wasm:return_amount::integer
            ) as to_amount,
            attributes:wasm:ask_asset::string as to_currency,
            6::integer as to_decimal,
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
            message_index as msg_index,
            coalesce(
                attributes:wasm:amount_0::integer,
                attributes:coin_received:amount_1::integer,
                attributes:coin_received:amount_2::integer
            ) as from_amount,
            coalesce(
                attributes:coin_received:currency_0::string,
                attributes:wasm:ask_asset_0::string
            ) as from_currency,
            6::integer as from_decimal,
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
            6::integer as to_decimal,
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
            msg_index,
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
            msg_index,
            from_amount,
            from_currency,
            from_decimal,
            to_amount,
            to_currency,
            to_decimal,
            contract_address
        from execute_swap_operations

    ),
    final_table as (

        select distinct
            concat(s.tx_id, '-', msg_index, '-', s.contract_address, '-') as swap_id,

            s.block_id,
            s.block_timestamp,
            s._inserted_timestamp,
            s.blockchain,
            s.chain_id,
            s.tx_id,
            s.tx_succeeded,
            t.tx_sender as trader,
            from_amount,
            from_currency,
            from_decimal,
            to_amount,
            to_currency,
            to_decimal,
            label as pool_id
        from union_swaps s
        left outer join terra_dev.silver.transactions t on s.tx_id = t.tx_id
        left outer join
            terra_dev.core.dim_address_labels l on l.address = s.contract_address


    )

select *
from final_table