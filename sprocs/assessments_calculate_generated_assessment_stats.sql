CREATE OR REPLACE FUNCTION
    assessments_calculate_generated_assessment_stats (
        assessment_id_var BIGINT
    ) RETURNS VOID
AS $$
BEGIN
    -- generate 10000 exams
    -- calculate mean and sd for each quintile
    -- save to db

    WITH generated_aq_ids AS (
        SELECT
            get_randomly_generated_assessment_question_ids_multiple_reps(assessment_id_var, 1000) AS generated_assessment_question_ids
    ),
    generated_assessment_stats AS (
        SELECT
            quintile_stats.*
        FROM
            generated_aq_ids
            JOIN calculate_quintile_stats(get_domain(assessment_id_var), generated_aq_ids.generated_assessment_question_ids)
                AS quintile_stats (quintile INTEGER, mean DOUBLE PRECISION, sd DOUBLE PRECISION) ON TRUE
    )
    INSERT INTO
        assessment_quintile_statistics (assessment_id, quintile, mean_score, score_sd)
    SELECT
        assessment_id_var,
        generated_assessment_stats.quintile,
        generated_assessment_stats.mean,
        generated_assessment_stats.sd
    FROM
        generated_assessment_stats
    ON CONFLICT (assessment_id, quintile)
    DO UPDATE SET
      assessment_id=EXCLUDED.assessment_id,
      quintile=EXCLUDED.quintile,
      mean_score=EXCLUDED.mean_score,
      score_sd=EXCLUDED.score_sd;

    UPDATE
        assessments AS a
    SET
        generated_assessment_stats_last_updated = current_timestamp
    WHERE
        a.id = assessment_id_var;

END;
$$ LANGUAGE plpgsql VOLATILE;