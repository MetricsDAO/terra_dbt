{% macro run_sp_create_prod_clone() %}
    {% set clone_query %}
    call terra._internal.create_prod_clone(
        'terra',
        'terra_dev',
        'dbt_cloud'
    );
{% endset %}
    {% do run_query(clone_query) %}
{% endmacro %}
