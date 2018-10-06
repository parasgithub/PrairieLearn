DROP FUNCTION IF EXISTS get_quintile_stats();
CREATE FUNCTION get_quintile_stats()
    RETURNS TABLE(means DOUBLE PRECISION[], sds DOUBLE PRECISION[], assessment_id BIGINT)
LANGUAGE PLPGSQL
AS $$
BEGIN
RETURN QUERY
WITH relevant_assessments AS (
    SELECT
        ci.id = 2 AND (a.tid LIKE '%quiz%' OR tid = 'final') AND NOT (a.number LIKE '%R') AS relevant,
        a.id AS assessment_id

    FROM
        assessments AS a
        JOIN course_instances AS ci ON (a.course_instance_id = ci.id)
),
generated_aq_ids AS (
    SELECT
        get_randomly_generated_assessment_question_ids_multiple_reps(a.id, 1000) AS generated_assessment_question_ids,
        a.id AS assessment_id
    FROM
        assessments AS a
        JOIN relevant_assessments ON (a.id = relevant_assessments.assessment_id)
    WHERE
        relevant_assessments.relevant
),
generated_aq_ids_flattened AS (
    SELECT
        slice(generated_aq_ids.generated_assessment_question_ids, rows.row) AS generated_assessment_question_ids,
        generated_aq_ids.assessment_id
    FROM
        generated_aq_ids,
        generate_subscripts(generated_aq_ids.generated_assessment_question_ids, 1) AS rows (row)
),
quintile_stats_object AS (
    SELECT
        quintile_stats.*,
        generated_aq_ids.assessment_id
    FROM
        generated_aq_ids
        JOIN LATERAL calculate_quintile_stats(get_domain(generated_aq_ids.assessment_id), generated_aq_ids.generated_assessment_question_ids) quintile_stats (quintile INTEGER, mean DOUBLE PRECISION, sd DOUBLE PRECISION) ON TRUE
    ORDER BY
--         generated_aq_ids.assessment_id,
        quintile_stats.quintile
),
quintile_stats AS (
    SELECT
        array_agg(quintile_stats_object.mean ORDER BY quintile_stats_object.quintile) AS means,
        array_agg(quintile_stats_object.sd ORDER BY quintile_stats_object.quintile) AS sds,
        quintile_stats_object.assessment_id
    FROM
        quintile_stats_object
    GROUP BY
        quintile_stats_object.assessment_id
)
SELECT * FROM quintile_stats;
END;
$$;

DROP FUNCTION IF EXISTS get_quintile_stats(BIGINT);
CREATE FUNCTION get_quintile_stats(assessment_id_var BIGINT)
    RETURNS TABLE(means DOUBLE PRECISION[], sds DOUBLE PRECISION[], assessment_id BIGINT)
LANGUAGE PLPGSQL
AS $$
BEGIN
    RETURN QUERY
        WITH generated_aq_ids AS (
            SELECT
                get_randomly_generated_assessment_question_ids_multiple_reps(a.id, 1000) AS generated_assessment_question_ids
            FROM
                assessments AS a
            WHERE
                a.id = assessment_id_var
        ),
            generated_aq_ids_flattened AS (
            SELECT
                slice(generated_aq_ids.generated_assessment_question_ids, rows.row) AS generated_assessment_question_ids
            FROM
                generated_aq_ids,
                        generate_subscripts(generated_aq_ids.generated_assessment_question_ids, 1) AS rows (row)
        ),
            quintile_stats_object AS (
            SELECT
                quintile_stats.*
            FROM
                generated_aq_ids
                JOIN LATERAL calculate_quintile_stats(get_domain(assessment_id_var), generated_aq_ids.generated_assessment_question_ids) quintile_stats (quintile INTEGER, mean DOUBLE PRECISION, sd DOUBLE PRECISION) ON TRUE
            ORDER BY
                quintile_stats.quintile
        ),
            quintile_stats AS (
            SELECT
                array_agg(quintile_stats_object.mean ORDER BY quintile_stats_object.quintile) AS means,
                array_agg(quintile_stats_object.sd ORDER BY quintile_stats_object.quintile) AS sds,
                assessment_id_var AS assessment_id
            FROM
                quintile_stats_object
        )
    SELECT * FROM quintile_stats;
END;
$$;