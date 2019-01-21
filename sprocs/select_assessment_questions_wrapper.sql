-- assessment number is unused
-- we create a wrapper with an unused variable so that the function is run multiple times with different values of that
-- variable
CREATE OR REPLACE FUNCTION
    select_assessment_questions_wrapper(
    assessment_id bigint,
    assessment_number BIGINT
) RETURNS TABLE (
    assessment_question_id bigint,
    init_points double precision,
    points_list double precision[],
    question JSONB
)
AS $$
BEGIN
    return query SELECT * FROM select_assessment_questions(assessment_id);
END;
$$ LANGUAGE plpgsql VOLATILE;
