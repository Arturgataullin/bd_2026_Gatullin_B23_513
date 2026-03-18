INSERT INTO users (login, password_hash, avatar_url)
VALUES
('admin1',   'hash_admin1',   NULL),
('manager1', 'hash_manager1', NULL),
('mod1',     'hash_mod1',     NULL),
('ivan',     'hash_ivan',     NULL),
('petr',     'hash_petr',     NULL),
('anna',     'hash_anna',     NULL),
('sergey',   'hash_sergey',   NULL);

INSERT INTO admins (user_id)
SELECT user_id FROM users WHERE login = 'admin1';

INSERT INTO managers (user_id)
SELECT user_id FROM users WHERE login = 'manager1';

INSERT INTO moderators (user_id)
SELECT user_id FROM users WHERE login = 'mod1';

INSERT INTO players (user_id, global_balance)
SELECT user_id, 1000.00 FROM users WHERE login = 'ivan';

INSERT INTO players (user_id, global_balance)
SELECT user_id, 800.00 FROM users WHERE login = 'petr';

INSERT INTO players (user_id, global_balance)
SELECT user_id, 1200.00 FROM users WHERE login = 'anna';

INSERT INTO players (user_id, global_balance)
SELECT user_id, 700.00 FROM users WHERE login = 'sergey';


INSERT INTO game_types (
    name,
    description,
    rounds_count,
    max_players,
    can_join_in_progress,
    manager_user_id,
    can_have_tournament,
    min_local_balance,
    min_bet,
    can_leave_without_balance_loss
)
VALUES
(
    'Poker',
    'Классический покер',
    NULL,
    6,
    FALSE,
    (SELECT user_id FROM managers LIMIT 1),
    TRUE,
    100.00,
    10.00,
    FALSE
),
(
    'Roulette',
    'Рулетка',
    NULL,
    20,
    TRUE,
    (SELECT user_id FROM managers LIMIT 1),
    FALSE,
    0.00,
    1.00,
    TRUE
),
(
    'Blackjack',
    'Блэкджек',
    NULL,
    5,
    TRUE,
    (SELECT user_id FROM managers LIMIT 1),
    TRUE,
    50.00,
    5.00,
    TRUE
);


INSERT INTO tournaments (
    game_type_id,
    entry_fee,
    starts_at,
    prize_fund
)
VALUES
(
    (SELECT game_type_id FROM game_types WHERE name = 'Poker'),
    50.00,
    '2026-03-20 18:00:00',
    300.00
),
(
    (SELECT game_type_id FROM game_types WHERE name = 'Blackjack'),
    30.00,
    '2026-03-21 19:00:00',
    200.00
);


INSERT INTO sessions (
    game_type_id,
    moderator_user_id,
    tournament_id,
    parent_session_id,
    description,
    starts_at,
    ends_at,
    prize_fund
)
VALUES
(
    (SELECT game_type_id FROM game_types WHERE name = 'Poker'),
    (SELECT user_id FROM moderators LIMIT 1),
    (SELECT tournament_id FROM tournaments WHERE game_type_id = (SELECT game_type_id FROM game_types WHERE name = 'Poker') LIMIT 1),
    NULL,
    'Покерная турнирная сессия',
    '2026-03-20 18:00:00',
    '2026-03-20 19:30:00',
    300.00
),
(
    (SELECT game_type_id FROM game_types WHERE name = 'Roulette'),
    (SELECT user_id FROM moderators LIMIT 1),
    NULL,
    NULL,
    'Обычная сессия рулетки',
    '2026-03-20 20:00:00',
    '2026-03-20 21:00:00',
    0.00
);


INSERT INTO rounds (session_id, round_number, starts_at, ends_at)
VALUES
(1, 1, '2026-03-20 18:00:00', '2026-03-20 18:15:00'),
(1, 2, '2026-03-20 18:20:00', '2026-03-20 18:35:00'),
(1, 3, '2026-03-20 18:40:00', '2026-03-20 18:55:00'),
(2, 1, '2026-03-20 20:00:00', '2026-03-20 20:10:00'),
(2, 2, '2026-03-20 20:15:00', '2026-03-20 20:25:00');


INSERT INTO participants (
    session_id,
    player_user_id,
    joined_round_id,
    left_round_id,
    result,
    entry_fee,
    local_balance
)
VALUES
(1, (SELECT user_id FROM users WHERE login = 'ivan'),   1, NULL, 'undefined', 50.00, 200.00),
(1, (SELECT user_id FROM users WHERE login = 'petr'),   1, NULL, 'undefined', 50.00, 150.00),
(1, (SELECT user_id FROM users WHERE login = 'anna'),   1, NULL, 'undefined', 50.00, 220.00),
(2, (SELECT user_id FROM users WHERE login = 'sergey'), 4, NULL, 'undefined',  0.00, 100.00),
(2, (SELECT user_id FROM users WHERE login = 'ivan'),   4, NULL, 'undefined',  0.00, 120.00);


INSERT INTO balance_movements (participant_id, movement_type, amount)
VALUES
(1, 'global_to_local', 200.00),
(2, 'global_to_local', 150.00),
(3, 'global_to_local', 220.00),
(4, 'global_to_local', 100.00),
(5, 'global_to_local', 120.00);


INSERT INTO bets (participant_id, round_id, placed_at, amount, result, local_balance_change)
VALUES
(1, 1, '2026-03-20 18:05:00', 20.00, 'win',   40.00),
(2, 1, '2026-03-20 18:06:00', 20.00, 'lose', -20.00),
(3, 1, '2026-03-20 18:07:00', 10.00, 'win',   20.00),
(1, 2, '2026-03-20 18:22:00', 10.00, 'lose', -10.00),
(2, 2, '2026-03-20 18:23:00', 15.00, 'win',   30.00),
(3, 2, '2026-03-20 18:24:00', 15.00, 'lose', -15.00),
(4, 4, '2026-03-20 20:05:00', 10.00, 'lose', -10.00),
(5, 4, '2026-03-20 20:06:00', 10.00, 'win',   20.00),
(4, 5, '2026-03-20 20:18:00',  5.00, 'win',   10.00),
(5, 5, '2026-03-20 20:19:00',  5.00, 'lose',  -5.00);


INSERT INTO financial_documents (player_user_id, amount, doc_type)
VALUES
((SELECT user_id FROM users WHERE login = 'ivan'),   500.00, 'deposit'),
((SELECT user_id FROM users WHERE login = 'petr'),   300.00, 'deposit'),
((SELECT user_id FROM users WHERE login = 'anna'),   700.00, 'deposit'),
((SELECT user_id FROM users WHERE login = 'sergey'), 200.00, 'deposit');


UPDATE users u
JOIN (
    SELECT user_id
    FROM users
    WHERE login = 'admin1'
) AS a ON 1 = 1
SET
    u.is_blocked = TRUE,
    u.blocked_by_user_id = a.user_id,
    u.blocked_at = '2026-03-17 12:00:00',
    u.block_reason = 'Нарушение правил платформы'
WHERE u.login = 'ivan';