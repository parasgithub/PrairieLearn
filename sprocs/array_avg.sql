DO $$
BEGIN

IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'array_and_int') THEN
    CREATE TYPE array_and_int AS (arr double precision[], intVal int);
END IF;

END$$;

CREATE OR REPLACE FUNCTION
    array_avg_sfunc (state array_and_int, nextVal anyarray) RETURNS array_and_int AS $$
BEGIN
    IF nextVal IS NULL THEN
        RETURN state;
    END IF;

    IF state IS NULL THEN
        state := ROW(array_fill(0, ARRAY[array_length(nextVal, 1)]), 0);
    END IF;

    FOR i in 1 .. array_length(state.arr, 1) LOOP
        state.arr[i] = state.arr[i] + nextVal[i];
    END LOOP;

    state.intVal := state.intVal + 1;

    RETURN state;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION
    array_avg_finalfunc(state array_and_int) RETURNS double precision[] AS $$
BEGIN
    IF state IS NULL THEN
        RETURN NULL;
    END IF;

    FOR i in 1 .. array_length(state.arr, 1) LOOP
        state.arr[i] = state.arr[i] / state.intVal;
    END LOOP;

    RETURN state.arr;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP AGGREGATE IF EXISTS array_avg (anyarray) CASCADE;
CREATE AGGREGATE array_avg (anyarray) (
    sfunc = array_avg_sfunc,
    stype = array_and_int,
    finalfunc = array_avg_finalfunc
);