-- BLOCK select_histograms
WITH num_attempts_histogram AS (
    SELECT
        aq.question_id,
        histogram(number_attempts, 1, 10, 10) as num_attempts_histogram,
        a.type AS assessment_type
    FROM
        instance_questions AS iq
        JOIN assessment_questions AS aq ON iq.assessment_question_id=aq.id
        JOIN assessment_instances AS ai ON (iq.assessment_instance_id = ai.id)
        JOIN assessments AS a ON aq.assessment_id=a.id
        JOIN course_instances AS ci ON (a.course_instance_id = ci.id)
        JOIN enrollments AS e ON (ai.user_id = e.user_id AND ci.id = e.course_instance_id)
    WHERE
        number_attempts != 0
        AND aq.deleted_at IS NULL
        AND e.role = 'Student'
    GROUP BY
        aq.question_id,
        a.type
),
num_attempts_gave_up_histogram AS (
    SELECT
        aq.question_id,
        histogram(number_attempts, 1, 10, 10) as num_attempts_histogram,
        a.type AS assessment_type
    FROM
        instance_questions AS iq
        JOIN assessment_questions AS aq ON iq.assessment_question_id=aq.id
        JOIN assessment_instances AS ai ON (iq.assessment_instance_id = ai.id)
        JOIN assessments AS a ON (ai.assessment_id = a.id)
        JOIN course_instances AS ci ON (a.course_instance_id = ci.id)
        JOIN enrollments AS e ON (ai.user_id = e.user_id AND ci.id = e.course_instance_id)
    WHERE
        number_attempts != 0
        AND iq.points = 0
        AND aq.deleted_at IS NULL
        AND e.role = 'Student'
    GROUP BY
        aq.question_id,
        a.type
)
SELECT
    q.id,
    num_attempts_histogram.num_attempts_histogram AS question_attempts_histogram,
    num_attempts_gave_up_histogram.num_attempts_histogram AS question_attempts_before_giving_up_histogram,
    num_attempts_histogram_hw.num_attempts_histogram AS question_attempts_histogram_hw,
    num_attempts_gave_up_histogram_hw.num_attempts_histogram AS question_attempts_before_giving_up_histogram_hw
FROM questions as q
LEFT JOIN num_attempts_histogram ON (num_attempts_histogram.question_id = q.id AND
num_attempts_histogram.assessment_type = 'Exam')
LEFT JOIN num_attempts_gave_up_histogram ON (num_attempts_gave_up_histogram.question_id = q.id AND
num_attempts_gave_up_histogram.assessment_type = 'Exam')
LEFT JOIN num_attempts_histogram AS num_attempts_histogram_hw
        ON (num_attempts_histogram_hw.question_id = q.id AND num_attempts_histogram_hw.assessment_type = 'Homework')
LEFT JOIN num_attempts_gave_up_histogram AS num_attempts_gave_up_histogram_hw
        ON (num_attempts_gave_up_histogram_hw.question_id = q.id AND
            num_attempts_gave_up_histogram_hw.assessment_type = 'Homework')
WHERE
    q.id = $question_id
    AND q.deleted_at IS NULL;

-- BLOCK assessment_question_stats
SELECT
    aset.name || ' ' || a.number || ': ' || title AS title,
    ci.short_name AS course_title,
    a.id AS assessment_id,
    aset.color,
    (aset.abbreviation || a.number) as label,
    admin_assessment_question_number(aq.id) as number,
    a.type,
    aq.*
FROM
    assessment_questions AS aq
    JOIN assessments AS a ON (a.id = aq.assessment_id)
    JOIN assessment_sets AS aset ON (aset.id = a.assessment_set_id)
    JOIN course_instances AS ci ON (ci.id = a.course_instance_id)
WHERE
    aq.question_id=$question_id
    AND aq.deleted_at IS NULL
GROUP BY
    a.id,
    aq.id,
    aset.id,
    ci.id
ORDER BY
    admin_assessment_question_number(aq.id);

-- BLOCK question_statistics
SELECT
    qs.*
FROM
    question_statistics AS qs
WHERE
    qs.question_id=$question_id;
