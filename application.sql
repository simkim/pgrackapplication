-- Framework data

DROP TABLE IF EXISTS routes;
CREATE TABLE routes (
    id serial PRIMARY KEY,
    path text NOT NULL,
    method text NOT NULL,
    app text NOT NULL
);

-- Framework engine

CREATE OR REPLACE FUNCTION route(in text, in text, out status int, out body text)
    AS $$
    DECLARE
        _app text;
        _params json;
        _status int;
        _response record;
    BEGIN
        SELECT app INTO _app FROM routes WHERE method = $1 AND path = $2;
        IF NOT FOUND THEN
            status := 404;
            body := 'Not found';
        ELSE
            _params := json_build_object('id', 1);
            EXECUTE 'SELECT status, body from ' || _app || '($1::json)' INTO _response USING _params;
            status := _response.status;
            body := _response.body;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

-- Application data

DROP TABLE IF EXISTS todos;

CREATE TABLE todos(
    id bigint PRIMARY KEY,
    title text NOT NULL
);

INSERT INTO todos (id, title) VALUES (1, 'Buy milk'), (2, 'Buy eggs'), (3, 'Buy bread');

-- Application routes

INSERT INTO routes (path, method, app) VALUES ('/', 'GET', 'hello');
INSERT INTO routes (path, method, app) VALUES ('/hello', 'GET', 'hello');
INSERT INTO routes (path, method, app) VALUES ('/todos', 'GET', 'todo_index');
INSERT INTO routes (path, method, app) VALUES ('/todo/1', 'GET', 'todo_show');

-- Application controllers

CREATE OR REPLACE FUNCTION hello(in params json, out status int, out body text)
    AS $$ SELECT 200, 'Hello world' $$
    LANGUAGE SQL;

CREATE OR REPLACE FUNCTION todo_index(in params json, out status int, out body text)
    AS $$
    DECLARE
        _todo record;
    BEGIN
        body := '<html><body>';
        FOR _todo IN SELECT id, title FROM todos LOOP
            body := body || '<a href="/todo/'||_todo.id||'">' || _todo.id || ': ' || _todo.title || '</a>' || E'\n';
        END LOOP;
        body := body || '</body></html>';
        status := 200;
    END;
    $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION todo_show(in params json, out status int, out body text)
    AS $$
    DECLARE
        _id bigint;
        _todo record;
    BEGIN
        _id := (params->>'id')::bigint;
        SELECT id, title INTO _todo FROM todos WHERE id = _id;
        IF NOT FOUND THEN
            status := 404;
            body := 'Not found';
        ELSE
            body := _todo.id || ': ' || _todo.title;
            status := 200;
        END IF;
    END;
    $$ LANGUAGE plpgsql;




