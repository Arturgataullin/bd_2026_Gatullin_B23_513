SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS bets;
DROP TABLE IF EXISTS balance_movements;
DROP TABLE IF EXISTS participants;
DROP TABLE IF EXISTS rounds;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS tournaments;
DROP TABLE IF EXISTS financial_documents;
DROP TABLE IF EXISTS game_types;

DROP TABLE IF EXISTS players;
DROP TABLE IF EXISTS moderators;
DROP TABLE IF EXISTS managers;
DROP TABLE IF EXISTS admins;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;


CREATE TABLE users (
    user_id BIGINT NOT NULL AUTO_INCREMENT,
    login VARCHAR(64) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url TEXT NULL,

    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    blocked_by_user_id BIGINT NULL,
    blocked_at DATETIME NULL,
    block_reason TEXT NULL,

    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_login (login),

    CONSTRAINT fk_users_blocked_by
        FOREIGN KEY (blocked_by_user_id)
        REFERENCES users(user_id),

    CONSTRAINT chk_users_block_state
        CHECK (
            (is_blocked = FALSE AND blocked_by_user_id IS NULL AND blocked_at IS NULL AND block_reason IS NULL)
            OR
            (is_blocked = TRUE AND blocked_by_user_id IS NOT NULL AND blocked_at IS NOT NULL AND block_reason IS NOT NULL)
        )
);

CREATE TABLE admins (
    user_id BIGINT NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_admins_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

CREATE TABLE managers (
    user_id BIGINT NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_managers_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

CREATE TABLE moderators (
    user_id BIGINT NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_moderators_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

CREATE TABLE players (
    user_id BIGINT NOT NULL,
    global_balance DECIMAL(14,2) NOT NULL DEFAULT 0.00,

    PRIMARY KEY (user_id),

    CONSTRAINT fk_players_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_players_global_balance
        CHECK (global_balance >= 0)
);

CREATE TABLE game_types (
    game_type_id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    description TEXT NULL,

    rounds_count INT NULL,
    max_players INT NOT NULL,
    can_join_in_progress BOOLEAN NOT NULL,

    manager_user_id BIGINT NOT NULL,

    can_have_tournament BOOLEAN NOT NULL DEFAULT FALSE,

    min_local_balance DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    min_bet DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    can_leave_without_balance_loss BOOLEAN NOT NULL DEFAULT FALSE,

    PRIMARY KEY (game_type_id),
    UNIQUE KEY uq_game_types_name (name),

    CONSTRAINT fk_game_types_manager
        FOREIGN KEY (manager_user_id)
        REFERENCES managers(user_id),

    CONSTRAINT chk_game_types_rounds_count
        CHECK (rounds_count IS NULL OR rounds_count > 0),

    CONSTRAINT chk_game_types_max_players
        CHECK (max_players > 0),

    CONSTRAINT chk_game_types_min_local_balance
        CHECK (min_local_balance >= 0),

    CONSTRAINT chk_game_types_min_bet
        CHECK (min_bet >= 0)
);

CREATE TABLE tournaments (
    tournament_id BIGINT NOT NULL AUTO_INCREMENT,
    game_type_id BIGINT NOT NULL,
    entry_fee DECIMAL(14,2) NOT NULL,
    starts_at DATETIME NOT NULL,
    prize_fund DECIMAL(14,2) NOT NULL DEFAULT 0.00,

    PRIMARY KEY (tournament_id),

    CONSTRAINT fk_tournaments_game_type
        FOREIGN KEY (game_type_id)
        REFERENCES game_types(game_type_id),

    CONSTRAINT chk_tournaments_entry_fee
        CHECK (entry_fee >= 0),

    CONSTRAINT chk_tournaments_prize_fund
        CHECK (prize_fund >= 0)
);

CREATE TABLE sessions (
    session_id BIGINT NOT NULL AUTO_INCREMENT,
    game_type_id BIGINT NOT NULL,
    moderator_user_id BIGINT NOT NULL,
    tournament_id BIGINT NULL,
    parent_session_id BIGINT NULL,

    description TEXT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NULL,
    prize_fund DECIMAL(14,2) NOT NULL DEFAULT 0.00,

    PRIMARY KEY (session_id),

    CONSTRAINT fk_sessions_game_type
        FOREIGN KEY (game_type_id)
        REFERENCES game_types(game_type_id),

    CONSTRAINT fk_sessions_moderator
        FOREIGN KEY (moderator_user_id)
        REFERENCES moderators(user_id),

    CONSTRAINT fk_sessions_tournament
        FOREIGN KEY (tournament_id)
        REFERENCES tournaments(tournament_id),

    CONSTRAINT fk_sessions_parent
        FOREIGN KEY (parent_session_id)
        REFERENCES sessions(session_id),

    CONSTRAINT chk_sessions_time
        CHECK (ends_at IS NULL OR ends_at >= starts_at),

    CONSTRAINT chk_sessions_prize_fund
        CHECK (prize_fund >= 0)
);

CREATE TABLE rounds (
    round_id BIGINT NOT NULL AUTO_INCREMENT,
    session_id BIGINT NOT NULL,
    round_number INT NOT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NULL,

    PRIMARY KEY (round_id),
    UNIQUE KEY uq_rounds_session_round_number (session_id, round_number),

    CONSTRAINT fk_rounds_session
        FOREIGN KEY (session_id)
        REFERENCES sessions(session_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_rounds_number
        CHECK (round_number > 0),

    CONSTRAINT chk_rounds_time
        CHECK (ends_at IS NULL OR ends_at >= starts_at)
);

CREATE TABLE participants (
    participant_id BIGINT NOT NULL AUTO_INCREMENT,
    session_id BIGINT NOT NULL,
    player_user_id BIGINT NOT NULL,
    joined_round_id BIGINT NULL,
    left_round_id BIGINT NULL,

    result ENUM('win', 'lose', 'undefined') NOT NULL DEFAULT 'undefined',
    entry_fee DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    local_balance DECIMAL(14,2) NOT NULL DEFAULT 0.00,

    PRIMARY KEY (participant_id),
    UNIQUE KEY uq_participants_session_player (session_id, player_user_id),

    CONSTRAINT fk_participants_session
        FOREIGN KEY (session_id)
        REFERENCES sessions(session_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_participants_player
        FOREIGN KEY (player_user_id)
        REFERENCES players(user_id),

    CONSTRAINT fk_participants_joined_round
        FOREIGN KEY (joined_round_id)
        REFERENCES rounds(round_id),

    CONSTRAINT fk_participants_left_round
        FOREIGN KEY (left_round_id)
        REFERENCES rounds(round_id),

    CONSTRAINT chk_participants_entry_fee
        CHECK (entry_fee >= 0),

    CONSTRAINT chk_participants_local_balance
        CHECK (local_balance >= 0)
);

CREATE TABLE balance_movements (
    movement_id BIGINT NOT NULL AUTO_INCREMENT,
    participant_id BIGINT NOT NULL,
    movement_type ENUM('global_to_local', 'local_to_global') NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (movement_id),

    CONSTRAINT fk_balance_movements_participant
        FOREIGN KEY (participant_id)
        REFERENCES participants(participant_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_balance_movements_amount
        CHECK (amount > 0)
);

CREATE TABLE bets (
    bet_id BIGINT NOT NULL AUTO_INCREMENT,
    participant_id BIGINT NOT NULL,
    round_id BIGINT NOT NULL,
    placed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(14,2) NOT NULL,
    result ENUM('win', 'lose') NOT NULL,
    local_balance_change DECIMAL(14,2) NOT NULL,

    PRIMARY KEY (bet_id),

    CONSTRAINT fk_bets_participant
        FOREIGN KEY (participant_id)
        REFERENCES participants(participant_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_bets_round
        FOREIGN KEY (round_id)
        REFERENCES rounds(round_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_bets_amount
        CHECK (amount > 0)
);

CREATE TABLE financial_documents (
    document_id BIGINT NOT NULL AUTO_INCREMENT,
    player_user_id BIGINT NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    doc_type ENUM('deposit', 'withdraw') NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (document_id),

    CONSTRAINT fk_financial_documents_player
        FOREIGN KEY (player_user_id)
        REFERENCES players(user_id),

    CONSTRAINT chk_financial_documents_amount
        CHECK (amount > 0)
);
