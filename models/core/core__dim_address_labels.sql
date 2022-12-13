{{ config(
    materialized = 'view',
    secure = true
) }}

WITH labels AS (

    SELECT
        blockchain,
        address,
        creator,
        l1_label AS label_type,
        l2_label AS label_subtype,
        address_name AS label,
        project_name
    FROM
        {{ source(
            'labels',
            'address_labels'
        ) }}
    WHERE
        blockchain = 'terra'
),
tokens AS (
    SELECT
        blockchain,
        'token_deployment' AS creator,
        tx_id,
        label,
        symbol,
        address,
        decimals
    FROM
        {{ ref('silver__token_labels') }}
),
FINAL AS (
    SELECT
        COALESCE(
            t.blockchain,
            l.blockchain
        ) AS blockchain,
        COALESCE(
            t.address,
            l.address
        ) AS address,
        COALESCE(
            t.creator,
            l.creator
        ) AS creator,
        IFF(
            l.label_type is not null,
            l.label_type,
            'token') AS label_type,
        IFF(
            l.label_subtype is not null,
        l.label_subtype,
        'token_contract'
        ) as label_subtype
        ,
        COALESCE(
            t.symbol,
            l.label
        ) AS label,
        COALESCE(
            t.label,
            l.project_name
        ) AS project_name,
        t.decimals,
        t.tx_id AS deployment_tx_id
    FROM
        labels l full
        JOIN tokens t USING (
            blockchain,
            address
        )
)
SELECT
    *
FROM
    FINAL
