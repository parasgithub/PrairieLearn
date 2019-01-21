-- DROP FUNCTION IF EXISTS calculate_quintile_stats_as_rows(
--     enum_statistic_domain,
--     BIGINT[][]
-- );
--
-- CREATE TYPE state AS (
--     avg_accum_state DOUBLE PRECISION[],
--     stddev_pop_accum_state DOUBLE PRECISION[],
--     quintile INTEGER
-- );
--
-- CREATE TYPE result AS (
--     avg DOUBLE PRECISION,
--     stddev_pop DOUBLE PRECISION,
--     quintile INTEGER
-- );
--
-- CREATE FUNCTION calculate_quintile_stats_sfunc (
--     s state,
--     predicted_quintile_score DOUBLE PRECISION,
--     quintile INTEGER,
--     assessment_domain enum_statistic_domain
-- ) RETURNS state AS
-- $$
-- BEGIN
--     RETURN ROW(float8_accum(s.avg_accum_state, predicted_quintile_score),
--         float8_accum(s.stddev_pop_accum_state, predicted_quintile_score),
--         quintile,
--         assessment_domain)::state;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE FUNCTION calculate_quintile_stats_finalfunc (
--     s state,
--     predicted_quintile_score DOUBLE PRECISION,
--     quintile INTEGER,
--     assessment_domain enum_statistic_domain
-- ) RETURNS state AS
-- $$
-- BEGIN
--     RETURN ROW(float8_accum(s.avg_accum_state, predicted_quintile_score),
--            float8_accum(s.stddev_pop_accum_state, predicted_quintile_score),
--            quintile,
--            assessment_domain)::state;
-- END;
-- $$ LANGUAGE plpgsql;
--
--
-- CREATE AGGREGATE calculate_quintile_stats_as_rows (DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER) (
--     SFUNC = calculate_quintile_stats_sfunc,
--     STYPE = INTEGER[]
-- );
--
-- CREATE OR REPLACE FUNCTION calculate_quintile_stats_as_rows (
--     assessment_domain enum_statistic_domain,
--     generated_aq_ids SETOF<BIGINT[]>
-- ) RETURNS TABLE (quintile INTEGER, mean DOUBLE PRECISION, sd DOUBLE PRECISION)
-- AS $$
-- BEGIN
--     RETURN QUERY WITH predicted_quintile_scores AS (
--         SELECT
--             predicted_quintile_scores.predicted_score AS predicted_quintile_score,
--             quintiles.quintile
--         FROM
--             generate_series(1,5) AS quintiles (quintile)
--             JOIN LATERAL calculate_predicted_score_quintiles_as_rows(generated_aq_ids, assessment_domain)
--                 AS predicted_quintile_scores ON predicted_quintile_scores.quintile = quintiles.quintile
--     ),
--     quintile_stats AS (
--         SELECT
--             predicted_quintile_scores.quintile,
--             avg(predicted_quintile_scores.predicted_quintile_score) AS mean,
--             stddev_pop(predicted_quintile_scores.predicted_quintile_score) AS sd
--         FROM
--             predicted_quintile_scores
--         GROUP BY
--             predicted_quintile_scores.quintile
--         ORDER BY
--             predicted_quintile_scores.quintile
--     ) SELECT * FROM quintile_stats;
-- END;
-- $$ LANGUAGE plpgsql VOLATILE;
--

-- calculating quintile stats function
DROP FUNCTION IF EXISTS calculate_quintile_stats(
    enum_statistic_domain,
    BIGINT[][]
);

CREATE OR REPLACE FUNCTION
    calculate_quintile_stats(
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
