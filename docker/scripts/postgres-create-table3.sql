-- load extension first time after install
CREATE EXTENSION cstore_fdw;

-- create server object
CREATE SERVER cstore_server FOREIGN DATA WRAPPER cstore_fdw;

CREATE FOREIGN TABLE IF NOT EXISTS push (
    id BIGINT NOT NULL, actor_id INT NOT NULL, actor_login TEXT NOT NULL, repo_id INT NOT NULL, repo_name TEXT NOT NULL,  created_at TIMESTAMP NOT NULL,
    head TEXT NOT NULL, before TEXT NOT NULL, size BIGINT NOT NULL, distinct_size BIGINT NOT NULL
)
SERVER cstore_server
OPTIONS(compression 'pglz');
