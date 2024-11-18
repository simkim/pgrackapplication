-- Framework data

DROP TABLE IF EXISTS routes;
CREATE TABLE routes (
    id serial PRIMARY KEY,
    path text NOT NULL,
    method text NOT NULL,
    app text NOT NULL
);

DROP TYPE IF EXISTS response_t CASCADE;
CREATE TYPE response_t AS (
    status       integer,
    body         text,
    content_type text
);

DROP TYPE IF EXISTS found_route_t CASCADE;
CREATE TYPE found_route_t AS (
    app text,
    arguments text[]
);

DROP TYPE IF EXISTS params_t CASCADE;
CREATE TYPE params_t AS (
    arguments text[]
);

-- Framework engine

DROP FUNCTION IF EXISTS route_scan(text, text);
CREATE OR REPLACE FUNCTION route_scan(in text, in text, out found_route found_route_t)
    AS $$
    DECLARE
        _method ALIAS FOR $1;
        _path ALIAS FOR $2;
    BEGIN
        raise notice 'Scanning route %', _path;
        select found.app as _app, matches[2:] as _arguments into found_route from (select routes.app, regexp_matches(_path, CONCAT('(',replace(path, '/', '\/'),')')) as matches from routes) as found order by length(matches[1]) desc limit 1;
        raise notice 'Scan return route %', found_route;
    END;
    $$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS route(text, text);
CREATE OR REPLACE FUNCTION route(in text, in text, out response response_t)
    AS $$
    DECLARE
        _app text;
        _params params_t;
        _status int;
        _method ALIAS FOR $1;
        _path ALIAS FOR $2;
        found_route found_route_t;
    BEGIN
        SELECT * INTO found_route FROM route_scan(_method, _path);
        IF found_route.app IS NULL THEN
            raise notice 'Route not found';
            response := (404, 'Not found', 'text/plain');
        ELSE
            raise notice 'Found route %', found_route;
            _app := found_route.app;
            _params := ROW(found_route.arguments);
            raise notice 'Calling app % with params %', _app, _params;
            EXECUTE 'SELECT status, body, content_type from ' || _app || '($1)' INTO response USING _params;
            raise notice 'Response %', response;
        END IF;
    END;
    $$ LANGUAGE plpgsql;

-- Framework helpers

CREATE OR REPLACE FUNCTION link_to(in text, in text, out text)
    AS $$ SELECT '<a href="' || $2 || '">' || $1 || '</a>' $$
    LANGUAGE SQL;

CREATE OR REPLACE FUNCTION content_tag(in text, in text, out text)
    AS $$ SELECT '<' || $1 || '>' || $2 || '</' || $1 || '>' $$
    LANGUAGE SQL;

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
INSERT INTO routes (path, method, app) VALUES ('/todo/(\d+)', 'GET', 'todo_show');


-- Application controllers
DROP FUNCTION IF EXISTS hello(json);
CREATE OR REPLACE FUNCTION hello(in params params_t, out response response_t)
    AS $$ SELECT 200, link_to('Hello world', '/todos'), 'text/html' $$
    LANGUAGE SQL;

DROP FUNCTION IF EXISTS todo_index(json);
CREATE OR REPLACE FUNCTION todo_index(in params params_t, out response response_t)
    AS $$
    DECLARE
        _todo todos%ROWTYPE;
        body text;
    BEGIN
        body := '<html><body><ul>';
        FOR _todo IN SELECT id, title FROM todos LOOP
            body := body || content_tag('li', link_to(_todo.title, '/todo/'||_todo.id));
        END LOOP;
        body := body || '</ul></body></html>';
        response := (200, body, 'text/html');
    END;
    $$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS todo_show(json);
CREATE OR REPLACE FUNCTION todo_show(in params params_t, out response response_t)
    AS $$
    DECLARE
        _id bigint;
        _todo todos%ROWTYPE;
        body text;
    BEGIN
        _id := params.arguments[1]::bigint;
        SELECT id, title INTO _todo FROM todos WHERE id = _id;
        IF NOT FOUND THEN
            response := (404, 'Not found', 'text/plain');
        ELSE
            body := _todo.id || ': ' || _todo.title;
            response := (200, body, 'text/plain');
        END IF;

    END;
    $$ LANGUAGE plpgsql;




