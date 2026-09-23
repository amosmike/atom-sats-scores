select
    question_id,
    atom_id,
    subtopic_id,
    topic_id,
    subject_id,
    subject_name
from {{ source('de_raw', 'course_hierarchy') }}
