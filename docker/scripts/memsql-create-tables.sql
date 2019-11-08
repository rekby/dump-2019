CREATE DATABASE IF NOT EXISTS test;

USE test;

CREATE TABLE IF NOT EXISTS push (
    id BIGINT NOT NULL, actor_id BIGINT NOT NULL, actor_login VARBINARY(10000) NOT NULL, repo_id BIGINT NOT NULL, repo_name VARBINARY(10000) NOT NULL,  created_at DATETIME NOT NULL,
    head BINARY(20) NOT NULL, `before` BINARY(20) NOT NULL, size BIGINT, distinct_size BIGINT,
    created_at_month AS LAST_DAY(created_at) PERSISTED DATE,
    KEY(created_at_month, repo_name, actor_login, `before`) USING CLUSTERED COLUMNSTORE
);
