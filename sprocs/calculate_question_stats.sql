CREATE OR REPLACE FUNCTION
    calculate_question_stats (
        question_id_var bigint
    ) RETURNS VOID
AS $$
BEGIN
    -- exams
    PERFORM calculate_question_stats(question_id_var, 'Exams', 'Exam', 'Exam');
    -- practice_exams
    PERFORM calculate_question_stats(question_id_var, 'PracticeExams', 'Exam', 'Public');
    -- hws
    PERFORM calculate_question_stats(question_id_var, 'HWs', 'Homework', 'Public');
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION
    calculate_question_stats (
        question_id_var bigint,
        statistic_domain_var enum_statistic_domain,
        type_var enum_assessment_type,
        mode_var enum_mode
    ) RETURNS VOID
AS $$
BEGIN
    WITH assessment_weights AS (
        SELECT
            a.id AS assessment_id,
            count(a.id) AS weight
        FROM
            assessments AS a
            JOIN assessment_instances AS ai ON (a.id = ai.assessment_id)
        GROUP BY
            a.id
    ),
    averages_grouped_by_type_and_mode AS (
        SELECT
            weighted_avg(aq.mean_score, aw.weight::DOUBLE PRECISION) AS mean_score_per_question,
            weighted_avg(aq.discrimination, aw.weight::DOUBLE PRECISION) AS discrimination,
            weighted_avg(aq.average_number_attempts, aw.weight::DOUBLE PRECISION) AS average_number_attempts,
            array_weighted_avg(aq.quintile_scores, aw.weight::DOUBLE PRECISION) AS quintile_scores,
            weighted_avg(aq.some_correct_submission_perc, aw.weight::DOUBLE PRECISION) AS some_correct_submission_perc,
            weighted_avg(aq.first_attempt_correct_perc, aw.weight::DOUBLE PRECISION) AS first_attempt_correct_perc,
            weighted_avg(aq.last_attempt_correct_perc, aw.weight::DOUBLE PRECISION) AS last_attempt_correct_perc,
            weighted_avg(aq.some_submission_perc, aw.weight::DOUBLE PRECISION) AS some_submission_perc,
            weighted_avg(aq.average_of_average_success_rates, aw.weight::DOUBLE PRECISION) AS average_of_average_success_rates,
            array_weighted_avg(aq.average_success_rate_hist, aw.weight::DOUBLE PRECISION) AS average_success_rate_hist,
            weighted_avg(aq.average_length_of_incorrect_streak_with_some_correct_submission, aw.weight::DOUBLE PRECISION) AS average_length_of_incorrect_streak_with_some_correct_submission,
            array_weighted_avg(aq.length_of_incorrect_streak_hist_with_some_correct_submission, aw.weight::DOUBLE PRECISION) AS length_of_incorrect_streak_hist_with_some_correct_submission,
            weighted_avg(aq.average_length_of_incorrect_streak_with_no_correct_submission, aw.weight::DOUBLE PRECISION) AS average_length_of_incorrect_streak_with_no_correct_submission,
            array_weighted_avg(aq.length_of_incorrect_streak_hist_with_no_correct_submission, aw.weight::DOUBLE PRECISION) AS length_of_incorrect_streak_hist_with_no_correct_submission
        FROM
            assessment_questions AS aq
            JOIN assessments AS a ON (a.id = aq.assessment_id)
            JOIN assessment_weights AS aw ON (a.id = aw.assessment_id)
            JOIN assessment_sets AS aset ON (aset.id = a.assessment_set_id)
            JOIN course_instances AS ci ON (ci.id = a.course_instance_id)
        WHERE
            aq.deleted_at IS NULL
            AND a.type = type_var
            AND a.mode = mode_var
            AND aq.question_id = question_id_var
    )
    INSERT INTO
        question_statistics (
            question_id,
            domain,
            mean_score_per_question,
            discrimination,
            average_number_attempts,
            quintile_scores,
            some_correct_submission_perc,
            first_attempt_correct_perc,
            last_attempt_correct_perc,
            some_submission_perc,
            average_of_average_success_rates,
            average_success_rate_hist,
            average_length_of_incorrect_streak_with_some_correct_submission,
            length_of_incorrect_streak_hist_with_some_correct_submission,
            average_length_of_incorrect_streak_with_no_correct_submission,
            length_of_incorrect_streak_hist_with_no_correct_submission
        )
            SELECT
                question_id_var,
                statistic_domain_var,
                ga.mean_score_per_question,
                ga.discrimination,
                ga.average_number_attempts,
                ga.quintile_scores,
                ga.some_correct_submission_perc,
                ga.first_attempt_correct_perc,
                ga.last_attempt_correct_perc,
                ga.some_submission_perc,
                ga.average_of_average_success_rates,
                ga.average_success_rate_hist,
                ga.average_length_of_incorrect_streak_with_some_correct_submission,
                ga.length_of_incorrect_streak_hist_with_some_correct_submission,
                ga.average_length_of_incorrect_streak_with_no_correct_submission,
                ga.length_of_incorrect_streak_hist_with_no_correct_submission
            FROM
                averages_grouped_by_type_and_mode AS ga
        ON CONFLICT (question_id, domain)
            DO UPDATE SET
            question_id=EXCLUDED.question_id,
            domain=EXCLUDED.domain,
            mean_score_per_question=EXCLUDED.mean_score_per_question,
            discrimination=EXCLUDED.discrimination,
            average_number_attempts=EXCLUDED.average_number_attempts,
            quintile_scores=EXCLUDED.quintile_scores,
            some_correct_submission_perc=EXCLUDED.some_correct_submission_perc,
            first_attempt_correct_perc=EXCLUDED.first_attempt_correct_perc,
            last_attempt_correct_perc=EXCLUDED.last_attempt_correct_perc,
            some_submission_perc=EXCLUDED.some_submission_perc,
            average_of_average_success_rates=EXCLUDED.average_of_average_success_rates,
            average_success_rate_hist=EXCLUDED.average_success_rate_hist,
            average_length_of_incorrect_streak_with_some_correct_submission=EXCLUDED.average_length_of_incorrect_streak_with_some_correct_submission,
            length_of_incorrect_streak_hist_with_some_correct_submission=EXCLUDED.length_of_incorrect_streak_hist_with_some_correct_submission,
            average_length_of_incorrect_streak_with_no_correct_submission=EXCLUDED.average_length_of_incorrect_streak_with_no_correct_submission,
            length_of_incorrect_streak_hist_with_no_correct_submission=EXCLUDED.length_of_incorrect_streak_hist_with_no_correct_submission

    WHERE EXISTS (SELECT * FROM averages_grouped_by_type_and_mode);
END;
$$ LANGUAGE plpgsql VOLATILE;
