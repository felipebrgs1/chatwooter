-- +goose Up
-- Sessões do dashboard (cookie). Só o hash do token é guardado: um dump do banco não permite assumir uma sessão.
CREATE TABLE chatwooter_sessions (
    id bigserial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash bytea NOT NULL UNIQUE,
    created_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
    expires_at timestamp without time zone NOT NULL
);

CREATE INDEX chatwooter_sessions_user_id_idx ON chatwooter_sessions (user_id);

-- +goose Down
DROP TABLE chatwooter_sessions;
