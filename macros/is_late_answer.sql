{#
    True if a response's timestamp lands after its sitting finished, beyond the small tolerance
    for the rounding bug we found (answers stamped up to 1 second after finished_at — see README
    "Known bugs" and "Data quality issues"). Used to set a flag column, not to drop rows: a late
    answer still counts, it's just marked for follow-up.
#}
{% macro is_late_answer(answered_at_column, finished_at_column) %}
    {{ finished_at_column }} is not null
    and {{ answered_at_column }} > timestamp_add(
        {{ finished_at_column }}, interval {{ var('late_answer_tolerance_seconds') }} second
    )
{% endmacro %}
