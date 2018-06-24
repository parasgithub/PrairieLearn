-- testing effectiveness method 2 (generate exams)
COPY (
    WITH num_exams AS (
        SELECT :num_exams AS num_exams
    ),
    relevant_assessments AS ( -- only one assessment - our custom quiz
        SELECT
            a.*
        FROM
            assessments AS a
        WHERE
            a.tid='custom_quiz'
    ),
    quintile_stats AS (
        SELECT
            *
        FROM
            get_quintile_stats() AS quintile_stats
            JOIN relevant_assessments ON (quintile_stats.assessment_id = relevant_assessments.id)
    ),
    generated_assessments AS (
        SELECT
            row_number() OVER () AS assessment_id,
            generated_assessment_question_ids,
            filter_generated_assessment(generated_assessment_question_ids, quintile_stats.means, quintile_stats.sds, 'Exams', :num_sds, :disqualification_threshold) AS keep
        FROM
            relevant_assessments AS a
            CROSS JOIN num_exams
            CROSS JOIN quintile_stats
            CROSS JOIN get_randomly_generated_assessment_question_ids_multiple_reps_new(a.id, num_exams.num_exams)
                AS generated_assessment_question_ids
    ),
    generated_assessments_flattened AS (
        SELECT
            ga.assessment_id,
            ga.keep,
            unnest(ga.generated_assessment_question_ids) AS generated_assessment_question_id
        FROM
            generated_assessments AS ga
    ),
    to_export AS (
        SELECT
            ga.assessment_id AS "Assessment ID",
            ga.generated_assessment_question_id AS "Assessment Question ID",
            ga.keep AS "Keep",
            aq.alternative_group_id AS "Alternative Group ID"
        FROM
            generated_assessments_flattened AS ga
            JOIN assessment_questions AS aq ON (aq.id=ga.generated_assessment_question_id)
            CROSS JOIN num_exams
    ) SELECT * FROM to_export
) TO :output_filename CSV HEADER;
