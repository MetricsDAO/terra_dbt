{{ config(
    materialized = "incremental",
    cluster_by = ["_inserted_timestamp"],
    unique_key = "unique_id",
) }}

WITH msg AS (

    SELECT
        block_id,
        block_timestamp,
        'terra' AS blockchain,
        chain_id,
        tx_id,
        tx_succeeded,
        6 AS decimals,
        attributes :wasm :recipient :: STRING AS purchaser,
        attributes :wasm :seller :: STRING AS seller,
        attributes :wasm :amount :: NUMBER AS sales_amount,
        attributes :wasm :denom :: STRING AS currency,
        attributes :wasm :_contract_address_0 :: STRING AS marketplace,
        attributes :wasm :nft_contract :: STRING AS contract_address,
        attributes :wasm :token_id_0 :: STRING AS token_id,
        _ingested_at,
        _inserted_timestamp
    FROM
        {{ ref("silver__messages") }}
    WHERE
        message_type = '/cosmwasm.wasm.v1.MsgExecuteContract'
        AND attributes :wasm :action_0 = 'settle'
        AND attributes :wasm :action_1 = 'transfer_nft'
        AND attributes :wasm :action_2 = 'settle_hook'
        AND {{ incremental_load_filter("_inserted_timestamp") }}
),
FINAL AS (
    SELECT
        block_id,
        block_timestamp,
        blockchain,
        chain_id,
        tx_id,
        tx_succeeded,
        decimals,
        purchaser,
        seller,
        sales_amount,
        currency,
        marketplace,
        contract_address,
        token_id,
        CONCAT(
            tx_id,
            '-',
            token_id
        ) AS unique_id,
        _ingested_at,
        _inserted_timestamp
    FROM
        msg
)
SELECT
    *
FROM
    FINAL
