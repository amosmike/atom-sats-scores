{#
    Renders the scored_subjects var as a BigQuery array literal, e.g. ['English', 'Maths'].
    One place to build this so the mart's filter and its pupil x subject scaffold can't drift
    out of sync with each other.
#}
{% macro scored_subjects_array() %}
[{% for s in var('scored_subjects') %}'{{ s }}'{% if not loop.last %}, {% endif %}{% endfor %}]
{% endmacro %}
