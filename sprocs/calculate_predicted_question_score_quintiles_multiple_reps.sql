CREATE OR REPLACE FUNCTION
    calculate_predicted_score_quintiles_multiple_reps(
        IN assessment_id_var BIGINT,
        OUT final_result DOUBLE PRECISION[][],
        OUT generated_assessment_question_ids BIGINT[][]
    )
AS $$
DECLARE
    temp_result RECORD;
    num_reps INTEGER;
BEGIN
    num_reps = 1000;
    final_result = array_fill(NULL::DOUBLE PRECISION, ARRAY[5, num_reps]);
    FOR i IN 1..num_reps LOOP
        temp_result = get_randomly_generated_assessment_question_ids_and_calculate_predicted_score_quintiles(assessment_id_var);
        IF generated_assessment_question_ids IS NULL THEN
            generated_assessment_question_ids = array_fill(NULL::BIGINT,
                               ARRAY[num_reps, array_length(temp_result.generated_assessment_question_ids, 1)]);
        END IF;
        FOR j in 1..array_length(temp_result.generated_assessment_question_ids, 1) LOOP
            generated_assessment_question_ids[i][j] = temp_result.generated_assessment_question_ids[j];
        END LOOP;
        FOR j in 1..5 LOOP
            final_result[j][i] = temp_result.result[j];
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION
    calculate_predicted_score_quintiles_multiple_reps(
    IN assessment_domain enum_statistic_domain,
    IN generated_assessment_question_ids BIGINT[][],
    OUT final_result DOUBLE PRECISION[][]
)
AS $$
DECLARE
    temp_result DOUBLE PRECISION[];
    num_reps INTEGER;
BEGIN
    num_reps = array_length(generated_assessment_question_ids, 1);
    final_result = array_fill(NULL::DOUBLE PRECISION, ARRAY[5, num_reps]);
    FOR i IN 1..num_reps LOOP
        temp_result = calculate_predicted_score_quintiles(slice(generated_assessment_question_ids, i)::BIGINT[], assessment_domain);
        FOR j in 1..5 LOOP
            final_result[j][i] = temp_result[j];
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;


