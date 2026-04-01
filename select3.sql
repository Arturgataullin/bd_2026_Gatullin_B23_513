/*
Получить отчет об участие игроков в разных играх. Каждая строка отчета соответствуют одному пользователю системы. 
Первый столбце отчета содержит имена игроков, каждый следующий столбец относится к одной игре. В ячейках указывается в каком количестве раундов игрок принимал участие в этой игре. 
Для вывода в таком виде смотреть “sql transpose table”, “sql crosstab”, “sql pivot”.
*/

WITH session_last_round AS (
    SELECT
        session_id,
        MAX(round_number) AS last_round_number
    FROM rounds
    GROUP BY session_id
),
user_game_rounds AS (
    SELECT
        p.player_user_id,
        gt.name AS game_name,
        SUM(COALESCE(lr.round_number, slr.last_round_number) - jr.round_number + 1) AS rounds_count
    FROM participants p
    JOIN sessions s
        ON s.session_id = p.session_id
    JOIN game_types gt
        ON gt.game_type_id = s.game_type_id
    JOIN rounds jr
        ON jr.round_id = p.joined_round_id
    LEFT JOIN rounds lr
        ON lr.round_id = p.left_round_id
    JOIN session_last_round slr
        ON slr.session_id = p.session_id
    GROUP BY
        p.player_user_id,
        gt.name
    HAVING SUM(COALESCE(lr.round_number, slr.last_round_number) - jr.round_number + 1) > 0
)
SELECT
    u.login AS player_login,
    SUM(CASE WHEN ugr.game_name = 'Pai Gow' THEN ugr.rounds_count ELSE 0 END) AS `Pai Gow`,
    SUM(CASE WHEN ugr.game_name = 'Texas Holdem' THEN ugr.rounds_count ELSE 0 END) AS `Texas Holdem`,
    SUM(CASE WHEN ugr.game_name = 'Sic Bo' THEN ugr.rounds_count ELSE 0 END) AS `Sic Bo`,
    SUM(CASE WHEN ugr.game_name = 'Red Dog' THEN ugr.rounds_count ELSE 0 END) AS `Red Dog`,
    SUM(CASE WHEN ugr.game_name = 'Casino War' THEN ugr.rounds_count ELSE 0 END) AS `Casino War`,
    SUM(CASE WHEN ugr.game_name = 'Omaha' THEN ugr.rounds_count ELSE 0 END) AS `Omaha`,
    SUM(CASE WHEN ugr.game_name = 'Blackjack' THEN ugr.rounds_count ELSE 0 END) AS `Blackjack`,
    SUM(CASE WHEN ugr.game_name = 'Baccarat' THEN ugr.rounds_count ELSE 0 END) AS `Baccarat`,
    SUM(CASE WHEN ugr.game_name = 'Roulette' THEN ugr.rounds_count ELSE 0 END) AS `Roulette`
FROM players pl
JOIN users u
    ON u.user_id = pl.user_id
LEFT JOIN user_game_rounds ugr
    ON ugr.player_user_id = pl.user_id
GROUP BY
    u.user_id,
    u.login
ORDER BY u.login;