{#
    Point-in-time filter: true if a sitting had finished by the as_at_date cutoff.

    With no as_at_date set (the default), every finished sitting counts — a normal "current
    score" run. Passing --vars '{"as_at_date": "2026-03-01"}' recomputes what a pupil's score
    stood at on that date, using only sittings that had finished by then. This is the mechanism
    behind README "Scores as at a date": the mart doesn't need a table per date, just this filter.

    finished_at_column: the column holding a sitting's finish timestamp.
#}
{% macro sitting_finished_by(finished_at_column) %}
    {%- set as_at_date = var('as_at_date', none) -%}
    {{ finished_at_column }} is not null
    {%- if as_at_date %}
    and {{ finished_at_column }} <= timestamp('{{ as_at_date }}')
    {%- endif %}
{% endmacro %}
