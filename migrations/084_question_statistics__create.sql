CREATE TABLE question_statistics (
  id BIGSERIAL PRIMARY KEY,
  question_id BIGINT NOT NULL REFERENCES questions,
  domain enum_statistic_domain,
  mean_score_per_question DOUBLE PRECISION,
  discrimination DOUBLE PRECISION,
  average_number_attempts DOUBLE PRECISION,
  quintile_scores DOUBLE PRECISION[],
  some_correct_submission_perc DOUBLE PRECISION,
  first_attempt_correct_perc DOUBLE PRECISION,
  last_attempt_correct_perc DOUBLE PRECISION,
  some_submission_perc DOUBLE PRECISION,
  average_of_average_success_rates DOUBLE PRECISION,
  average_success_rate_hist DOUBLE PRECISION[],
  average_length_of_incorrect_streak_with_some_correct_submission DOUBLE PRECISION,
  length_of_incorrect_streak_hist_with_some_correct_submission DOUBLE PRECISION[],
  average_length_of_incorrect_streak_with_no_correct_submission DOUBLE PRECISION,
  length_of_incorrect_streak_hist_with_no_correct_submission DOUBLE PRECISION[]
);