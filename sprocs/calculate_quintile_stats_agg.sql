-- aggregate function that takes in a list of 'assessment question IDs'
-- and returns a table with headers mean, sd, and quintile

CREATE AGGREGATE calculate_quintile_stats_agg(aq_ids BIGINT[], assessment_id_var BIGINT) (
    SFUNC =
)

DROP FUNCTION IF EXISTS calculate_quintile_stats_agg(
    enum_statistic_domain,
    BIGINT[][]
);

CREATE OR REPLACE FUNCTION
    calculate_quintile_stats_agg(
    assessment_domain enum_statistic_domain,
    generated_assessment_question_ids BIGINT[][]) RETURNS SETOF RECORD
AS $$
BEGIN
    RETURN QUERY WITH predicted_quintile_scores AS (
        SELECT
            slice((calculate_predicted_score_quintiles_multiple_reps(assessment_domain, generated_assessment_question_ids)), quintiles.quintile) AS predicted_quintile_scores,
            quintiles.quintile
        FROM
            generate_series(1,5) AS quintiles (quintile)
    ),
    predicted_quintile_scores_flattened AS (
        SELECT
            predicted_quintile_scores.quintile,
            unnest(predicted_quintile_scores.predicted_quintile_scores) AS predicted_quintile_score
        FROM
            predicted_quintile_scores
    ),
    quintile_stats AS (
        SELECT
            predicted_quintile_scores_flattened.quintile,
            avg(predicted_quintile_scores_flattened.predicted_quintile_score) AS mean,
            stddev_pop(predicted_quintile_scores_flattened.predicted_quintile_score) AS sd
        FROM
            predicted_quintile_scores_flattened
        GROUP BY
            predicted_quintile_scores_flattened.quintile
        ORDER BY
            predicted_quintile_scores_flattened.quintile
    ) SELECT * FROM quintile_stats;
END;
$$ LANGUAGE plpgsql VOLATILE;
