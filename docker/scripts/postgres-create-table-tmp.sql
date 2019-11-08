CREATE TEMPORARY TABLE tmp (
    id BIGINT NOT NULL, actor_id BIGINT NOT NULL, actor_login TEXT NOT NULL, repo_id BIGINT NOT NULL, repo_name TEXT NOT NULL,  created_at TIMESTAMP NOT NULL,
    head TEXT NOT NULL, before TEXT NOT NULL, size BIGINT NOT NULL, distinct_size BIGINT NOT NULL
);

