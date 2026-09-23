select
    pupil_id,
    is_deleted
from {{ source('de_raw', 'pupils') }}
