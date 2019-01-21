CREATE FUNCTION get_generated_aq_ids_multiple_reps_as_rows(
    assessment_id_var BIGINT,
    num_reps INTEGER
) RETURNS SETOF BIGINT[]
AS $$
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS generated_assessment_questions (aq_id BIGINT, assessment_number BIGINT);

    CREATE INDEX IF NOT EXISTS generated_assessment_questions_aq_idx ON generated_assessment_questions (aq_id);
    CREATE INDEX IF NOT EXISTS generated_assessment_questions_an_idx ON generated_assessment_questions (assessment_number);

    WITH generated_assessment_questions_subquery AS (
        SELECT
            generated_aq.assessment_question_id AS aq_id,
            assessment_number
        FROM
            generate_series(1, num_reps) AS assessment_number
            JOIN LATERAL select_assessment_questions_wrapper(assessment_id_var, assessment_number) AS generated_aq ON TRUE
    )
    INSERT INTO generated_assessment_questions (SELECT * FROM generated_assessment_questions_subquery);

    RETURN QUERY SELECT
        array_agg(aq.id ORDER BY aq.alternative_group_id)
    FROM
        generated_assessment_questions AS generated_aq
        JOIN assessment_questions AS aq ON (aq.id=generated_aq.aq_id)
    GROUP BY
        generated_aq.assessment_number;

    DELETE FROM generated_assessment_questions;

END;
$$ LANGUAGE plpgsql VOLATILE;
