CREATE TABLE IF NOT EXISTS push (
    id BIGINT NOT NULL, actor_id INT NOT NULL, actor_login TEXT NOT NULL, repo_id INT NOT NULL, repo_name TEXT NOT NULL,  created_at TIMESTAMP NOT NULL,
    head bytea NOT NULL, before bytea NOT NULL, size BIGINT NOT NULL, distinct_size BIGINT NOT NULL
);

CREATE INDEX ON push USING BRIN (created_at);
CREATE INDEX ON push USING BRIN (created_at,repo_name,actor_login);
CREATE INDEX ON push USING BRIN (repo_name);
CREATE INDEX ON push USING BRIN (actor_login);

