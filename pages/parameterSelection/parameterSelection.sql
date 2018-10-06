-- get quintile stats for assessment
-- generate a bunch of assessments and return
-- assessment_number
-- predicted_score
-- whether or not we will keep it
-- then make histogram out of data

-- BLOCK generated_assessment_distribution
WITH quintile_stats AS (
    SELECT
        *
    FROM
        get_quintile_stats($assessment_id) AS quintile_stats
),
generated_assessments AS (
    SELECT
        calculate_predicted_score_from_assessment_questions(generated_aq_ids) AS predicted_score,
        filter_generated_assessment(generated_aq_ids, quintile_stats.means, quintile_stats.sds, 'Exams', $num_sds, 0) AS keep
    FROM
        quintile_stats
        CROSS JOIN get_generated_aq_ids_multiple_reps_as_rows($assessment_id, 1000) AS generated_aq_ids
),
num_exams_kept AS (
    SELECT
        count(*) AS num_exams_kept
    FROM
        generated_assessments AS ga
    WHERE
        ga.keep
),
sd_values AS (
    SELECT
        stddev_samp(ga.predicted_score) AS sd_before,
        stddev_samp(ga.predicted_score) FILTER (WHERE ga.keep) AS sd_after
    FROM
        generated_assessments AS ga
),
sd_improvement AS (
    SELECT
        100 * (sd_values.sd_before - sd_values.sd_after) / sd_values.sd_before AS sd_perc_improvement
    FROM
        sd_values
),
hist AS (
    SELECT
        keep.keep,
        histogram(ga.predicted_score, 0, 1, $num_buckets) AS predicted_score_hist
    FROM
        generated_assessments AS ga
        RIGHT JOIN (VALUES (TRUE), (FALSE)) AS keep (keep) ON (ga.keep = keep.keep)
    GROUP BY
        keep.keep
),
hist_json AS (
    SELECT
        json_agg(hist) AS json
    FROM
        hist
)
SELECT
    hist_json.json,
    num_exams_kept.num_exams_kept,
    sd_values.sd_before,
    sd_values.sd_after,
    sd_improvement.sd_perc_improvement,
    quintile_stats.means,
    quintile_stats.sds
FROM
    hist_json
    JOIN num_exams_kept ON TRUE
    JOIN sd_values ON TRUE
    JOIN sd_improvement ON TRUE
    JOIN quintile_stats ON TRUE
