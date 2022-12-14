{{ config(
    materialized = 'incremental',
    cluster_by = ['_inserted_timestamp::DATE'],
    unique_key = 'tx_id'
) }}

WITH bronze_txs AS (

    SELECT
        *
    FROM
        {{ ref('bronze__transactions') }}

{% if is_incremental() %}
WHERE
    _inserted_timestamp >= (
        SELECT
            MAX(_inserted_timestamp)
        FROM
            {{ this }}
    )
{% endif %}

qualify ROW_NUMBER() over (
    PARTITION BY tx_id
    ORDER BY
        _ingested_at DESC
) = 1
),
silver_txs AS (
    SELECT
        tx_id,
        block_id,
        block_timestamp,
        chain_id AS blockchain,
        object_keys(
            tx :auth_info :signer_infos [0] :mode_info
        ) [0] :: STRING AS auth_type,
        COALESCE(
            tx :auth_info :signer_infos [0] :public_key :key :: ARRAY,
            tx :auth_info :signer_infos [0] :public_key :public_keys :: ARRAY
        ) AS authorizer_public_key,
        TRY_BASE64_DECODE_STRING(
            tx :tx_result :events [0] :attributes [0] :key
        ) AS msg0_key,
        TRY_BASE64_DECODE_STRING(
            tx :tx_result :events [0] :attributes [0] :value
        ) AS msg0_value,
        tx :body :messages [0] :grantee :: STRING AS tx_grantee,
        tx :auth_info :fee :granter :: STRING AS tx_granter,
        tx :auth_info :fee :payer :: STRING AS tx_payer,
        TRY_BASE64_DECODE_STRING(
            tx :tx_result :events [1] :attributes [0] :value
        ) AS acc_seq,
        CASE
            WHEN msg0_key = 'spender' THEN msg0_value
            WHEN msg0_key = 'granter' THEN tx_payer
            WHEN msg0_key = 'fee' THEN COALESCE(tx_grantee, SPLIT(acc_seq, '/') [0] :: STRING)
        END AS tx_sender,
        tx :auth_info :fee :gas_limit :: NUMBER AS gas_limit,
        tx :tx_result :gasUsed :: NUMBER AS gas_used,
        tx :auth_info :fee :amount [0] :amount :: NUMBER AS fee_raw,
        tx :auth_info :fee :amount [0] :denom :: STRING AS fee_denom,
        tx :body :memo :: STRING AS memo,
        tx :tx_result :code :: NUMBER AS tx_code,
        IFF(
            tx_code = 0,
            TRUE,
            FALSE
        ) AS tx_succeeded,
        tx :tx_result :codespace :: STRING AS codespace,
        tx,
        _ingested_at,
        _inserted_timestamp
    FROM
        bronze_txs
)
SELECT
    tx_id,
    block_id,
    block_timestamp,
    auth_type,
    authorizer_public_key,
    tx_sender,
    gas_limit,
    gas_used,
    fee_raw,
    fee_denom,
    memo,
    codespace,
    tx_code,
    tx_succeeded,
    tx,
    _ingested_at,
    _inserted_timestamp
FROM
    silver_txs
