/*
Получить распределение онлайна игроков по временным промежуткам длительностью в 3 часа по дням недели за последние 8 недель.
 Отчет должен содержать 56 строк (1 строка для отрезка времени в 3 часа в одном из дней недели). Отчет представить в следующем виде:
День недели; отрезок времени в формате (09:00 – 12:00); число раундов, которые начались в этот отрезок времени; 
средний онлайн в это время (среднее число уникальных участников в новых раундах за это время); % онлайна от максимального онлайна за трехчасовой промежуток.
*/

WITH RECURSIVE weekdays AS (
    SELECT 0 AS weekday_num
    UNION ALL
    SELECT weekday_num + 1
    FROM weekdays
    WHERE weekday_num < 6
),
slots AS (
    SELECT 0 AS slot_idx
    UNION ALL
    SELECT slot_idx + 1
    FROM slots
    WHERE slot_idx < 7
),
grid AS (
    SELECT
        w.weekday_num,
        s.slot_idx
    FROM weekdays w
    CROSS JOIN slots s
),
session_last_round AS (
    SELECT
        session_id,
        MAX(round_number) AS last_round_number
    FROM rounds
    GROUP BY session_id
),
round_online AS (
    SELECT
        r.round_id,
        WEEKDAY(r.starts_at) AS weekday_num,
        FLOOR(HOUR(r.starts_at) / 3) AS slot_idx,
        COUNT(DISTINCT p.player_user_id) AS online_count
    FROM rounds r
    JOIN participants p
        ON p.session_id = r.session_id
    JOIN rounds jr
        ON jr.round_id = p.joined_round_id
    LEFT JOIN rounds lr
        ON lr.round_id = p.left_round_id
    JOIN session_last_round slr
        ON slr.session_id = r.session_id
    WHERE r.starts_at >= CURRENT_TIMESTAMP - INTERVAL 8 WEEK
      AND r.starts_at < CURRENT_TIMESTAMP
      AND r.round_number BETWEEN jr.round_number
                             AND COALESCE(lr.round_number, slr.last_round_number)
    GROUP BY
        r.round_id,
        WEEKDAY(r.starts_at),
        FLOOR(HOUR(r.starts_at) / 3)
),
bucket_stats AS (
    SELECT
        g.weekday_num,
        g.slot_idx,
        COUNT(ro.round_id) AS started_rounds_count,
        ROUND(COALESCE(AVG(ro.online_count), 0), 2) AS avg_online
    FROM grid g
    LEFT JOIN round_online ro
        ON ro.weekday_num = g.weekday_num
       AND ro.slot_idx = g.slot_idx
    GROUP BY
        g.weekday_num,
        g.slot_idx
),
calc AS (
    SELECT
        weekday_num,
        slot_idx,
        started_rounds_count,
        avg_online,
        LAG(avg_online) OVER (
            PARTITION BY weekday_num
            ORDER BY slot_idx
        ) AS prev_avg_online,
        LEAD(avg_online) OVER (
            PARTITION BY weekday_num
            ORDER BY slot_idx
        ) AS next_avg_online,
        MAX(avg_online) OVER () AS max_avg_online
    FROM bucket_stats
)
SELECT
    CASE weekday_num
        WHEN 0 THEN 'Понедельник'
        WHEN 1 THEN 'Вторник'
        WHEN 2 THEN 'Среда'
        WHEN 3 THEN 'Четверг'
        WHEN 4 THEN 'Пятница'
        WHEN 5 THEN 'Суббота'
        WHEN 6 THEN 'Воскресенье'
    END AS day_of_week,
    CONCAT(
        '(',
        LPAD(slot_idx * 3, 2, '0'),
        ':00 - ',
        CASE
            WHEN slot_idx = 7 THEN '24:00'
            ELSE CONCAT(LPAD((slot_idx + 1) * 3, 2, '0'), ':00')
        END,
        ')'
    ) AS time_slot,
    started_rounds_count,
    avg_online,
    ROUND(
        CASE
            WHEN max_avg_online = 0 THEN 0
            ELSE avg_online / max_avg_online * 100
        END,
        2
    ) AS online_pct_of_max
FROM calc
ORDER BY weekday_num, slot_idx;