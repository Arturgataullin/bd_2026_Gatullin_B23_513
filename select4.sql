/*
Получить информацию о всех сессиях, которые не завершены. Отчет представить в виде:
Id сессии; тип игры; номер последнего завершенного раунда; признак, идет ли сейчас новый раунд (да/нет); 
время, сколько идет уже начатый раунд (или NULL, если раунд не начат); время начала первого раунда.
*/

WITH finished_sessions AS (
    SELECT
        session_id
    FROM sessions
    WHERE ends_at IS NOT NULL
      AND ends_at <= CURRENT_TIMESTAMP
),
round_stats AS (
    SELECT
        r.session_id,
        MAX(
            CASE
                WHEN r.ends_at IS NOT NULL
                 AND r.ends_at <= CURRENT_TIMESTAMP
                THEN r.round_number
            END
        ) AS last_completed_round_number,
        MIN(
            CASE
                WHEN r.starts_at <= CURRENT_TIMESTAMP
                 AND (r.ends_at IS NULL OR r.ends_at > CURRENT_TIMESTAMP)
                THEN r.starts_at
            END
        ) AS running_round_start,
        MIN(r.starts_at) AS first_round_start
    FROM rounds r
    GROUP BY r.session_id
)
SELECT
    s.session_id,
    gt.name AS game_type,
    rs.last_completed_round_number,
    CASE
        WHEN rs.running_round_start IS NOT NULL THEN 'да'
        ELSE 'нет'
    END AS is_new_round_running,
    CASE
        WHEN rs.running_round_start IS NOT NULL
        THEN TIMEDIFF(CURRENT_TIMESTAMP, rs.running_round_start)
        ELSE NULL
    END AS current_round_duration,
    rs.first_round_start
FROM sessions s
LEFT JOIN finished_sessions fs
    ON fs.session_id = s.session_id
JOIN game_types gt
    ON gt.game_type_id = s.game_type_id
LEFT JOIN round_stats rs
    ON rs.session_id = s.session_id
WHERE fs.session_id IS NULL
ORDER BY rs.first_round_start, s.session_id;