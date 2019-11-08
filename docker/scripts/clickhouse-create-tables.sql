CREATE TABLE IF NOT EXISTS push (
    id UInt64, actor_id UInt32, actor_login String, repo_id UInt32, repo_name String, created_at DateTime,
    head FixedString(20) CODEC(NONE), before FixedString(20) CODEC(NONE), size UInt16, distinct_size UInt32
) ENGINE=MergeTree() PARTITION BY toYYYYMM(created_at) ORDER BY (repo_name, actor_login, before);
