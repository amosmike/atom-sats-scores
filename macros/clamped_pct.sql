{#
    Rounds a percentage to a whole number and clamps it to 0-100, so it always finds a row in
    sats_scale_lookup (whole-percentage-point keys). Centralised here so the mart and any future
    consumer of the scale round and clamp the same way. See README "How the scale is built".
#}
{% macro clamped_pct(pct_expr) %}
    least(100, greatest(0, cast(round({{ pct_expr }}) as int64)))
{% endmacro %}
