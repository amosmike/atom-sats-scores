{#
    Keeps every version of a sitting, not just the latest.

    assessment_sittings rows change over their life: is_complete flips, finished_at gets filled
    in, is_deleted could flip. Filtering downstream by finished_at is only trustworthy if the row
    we're filtering can't be silently rewritten or removed between runs — this snapshot is what
    makes that safe. See README "How the scale is built" -> "Remaining limit".

    No source table has its own updated_at, so we use `check` rather than `timestamp` strategy,
    comparing the columns that actually change over a sitting's lifecycle.
#}
{% snapshot snap_assessment_sittings %}

{{
    config(
      target_schema=target.schema,
      unique_key='session_id',
      strategy='check',
      check_cols=['is_complete', 'finished_at', 'is_deleted'],
    )
}}

select
    session_id,
    pupil_id,
    assessment_id,
    session_type,
    style,
    year_group_at_sitting,
    total_questions,
    is_complete,
    is_deleted,
    started_at,
    finished_at
from {{ source('de_raw', 'assessment_sittings') }}

{% endsnapshot %}
