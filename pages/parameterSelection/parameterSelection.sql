
-- BLOCK update_num_sds_value
UPDATE
    assessments AS a
SET
    num_sds = $num_sds_value
WHERE
    a.id=$assessment_id;
