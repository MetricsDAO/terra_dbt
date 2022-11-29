with pools as (
    select
        address,
        label
    from {{ ref('core__dim_address_labels') }}
    where label_subtype = 'pool'
),

lp_txs as (
    select
        *
    from {{ ref('silver__messages') }}
    where message_value:contract in (select address from pools)
),

withdraws as (
    select
        tx_id,
        parse_json(try_base64_decode_string(message_value:msg:send:msg)) as decoded_message,
        attributes:wasm as logs
    from lp_txs
    where message_value:msg:send is not null
      and decoded_message:withdraw_liquidity is not null
),

token_burns as (
    select
        tx_id,
        logs:_contract_address_0 as currency,
        logs:withdrawn_share::number as amount,
        label
    from withdraws
    inner join pools on currency = pools.address
),

withdraw_tokens as (
    select
        tx_id,
        regexp_substr(value, $$\d+$$)::number as amount,
        regexp_substr(value, $$\d+(\D.+)$$, 1, 1, 'e', 1) as currency
    from withdraws,
    lateral split_to_table(logs:refund_assets::string, ', ')
    union all
    select
        tx_id,
        amount,
        label as currency
    from token_burns
),

provides as (
    select
        tx_id,
        attributes:wasm as logs
    from lp_txs
      where message_value:msg:provide_liquidity is not null
),

token_mints as (
    select
        tx_id,
        logs:_contract_address_0 as currency,
        logs:share::number as amount,
        label
    from provides
    inner join pools on currency = pools.address
),

provide_tokens as (
    select
        tx_id,
        regexp_substr(value, $$\d+$$)::number as amount,
        regexp_substr(value, $$\d+(\D.+)$$, 1, 1, 'e', 1) as currency
    from provides,
    lateral split_to_table(logs:assets::string, ', ')
    union all
    select
        tx_id,
        amount,
        label as currency
    from token_mints
),

combined as (
    select
        tx_id,
        amount,
        currency
    from withdraw_tokens
    union
    select
        tx_id,
        amount,
        currency
    from provide_tokens
),

actual as (
    select 
        tx_id,
        amount,
        currency
    from {{ ref('silver__lp_actions') }}
),

expected as (
    select
        *
    from combined
),

test as (
    (select
        *
    from actual
    except
    select
        *
    from expected)
    union all
    (select
        *
    from expected
    except
    select
        *
    from actual)
)

select * from test
