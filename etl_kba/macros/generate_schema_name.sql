{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ 'kba_' ~ target.schema }}
    {%- else -%}
        {{ 'kba_' ~ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}