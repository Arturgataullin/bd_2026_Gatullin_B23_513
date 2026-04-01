/*
Получить список самых популярных игр. Отчет представить в виде:
Название игры; количество отдельных сессий по ней; суммарное количество участников (+1 за каждого участника в сессии независимо от числа раундов); 
количество разных игроков, принявших участие в этой игре за всё время; количество турниров по этой игре; среднее число игроков на сессию.
*/

WITH session_stats AS (
    SELECT
        gt.game_type_id,
        gt.name AS game_name,
        s.session_id,
        COUNT(p.participant_id) AS participants_in_session
    FROM game_types gt
    JOIN sessions s
        ON s.game_type_id = gt.game_type_id
    LEFT JOIN participants p
        ON p.session_id = s.session_id
    WHERE gt.max_players >= 2
    GROUP BY
        gt.game_type_id,
        gt.name,
        s.session_id
    HAVING COUNT(p.participant_id) >= 1
),
player_stats AS (
    SELECT
        s.game_type_id,
        COUNT(DISTINCT p.player_user_id) AS distinct_players_count
    FROM sessions s
    JOIN participants p
        ON p.session_id = s.session_id
    GROUP BY s.game_type_id
)
SELECT
    ss.game_name,
    COUNT(ss.session_id) AS sessions_count,
    SUM(ss.participants_in_session) AS total_participants_count,
    COALESCE(ps.distinct_players_count, 0) AS distinct_players_count,
    (
        SELECT COUNT(*)
        FROM tournaments t
        WHERE t.game_type_id = ss.game_type_id
    ) AS tournaments_count,
    ROUND(AVG(ss.participants_in_session), 2) AS avg_players_per_session
FROM session_stats ss
LEFT JOIN player_stats ps
    ON ps.game_type_id = ss.game_type_id
GROUP BY
    ss.game_type_id,
    ss.game_name,
    ps.distinct_players_count
ORDER BY distinct_players_count DESC, total_participants_count DESC, ss.game_name;