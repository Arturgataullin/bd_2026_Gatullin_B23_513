/*
Получить информацию о финансовом состоянии игроков. Отчет представить в виде:
ФИО игрока; сумма введенных средств в систему игроком; сумма поставленных денег; сумма проигранных денег; 
сумма выигранных денег; сумма средств на глобальном балансе игрока; сумма выведенных средств из системы.
*/

WITH doc_history AS (
    SELECT
        fd.player_user_id,
        fd.created_at,
        fd.document_id,
        ROUND(
            SUM(CASE WHEN fd.doc_type = 'deposit' THEN fd.amount ELSE 0 END) OVER (
                PARTITION BY fd.player_user_id
                ORDER BY fd.created_at, fd.document_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            2
        ) AS total_input,
        ROUND(
            SUM(CASE WHEN fd.doc_type = 'withdraw' THEN fd.amount ELSE 0 END) OVER (
                PARTITION BY fd.player_user_id
                ORDER BY fd.created_at, fd.document_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            2
        ) AS total_output,
        ROW_NUMBER() OVER (
            PARTITION BY fd.player_user_id
            ORDER BY fd.created_at DESC, fd.document_id DESC
        ) AS rn
    FROM financial_documents fd
),
doc_totals AS (
    SELECT
        player_user_id,
        total_input,
        total_output
    FROM doc_history
    WHERE rn = 1
),
bet_history AS (
    SELECT
        p.player_user_id,
        b.placed_at,
        b.bet_id,
        ROUND(
            SUM(b.amount) OVER (
                PARTITION BY p.player_user_id
                ORDER BY b.placed_at, b.bet_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            2
        ) AS total_bet_amount,
        ROUND(
            SUM(CASE WHEN b.result = 'lose' THEN ABS(b.local_balance_change) ELSE 0 END) OVER (
                PARTITION BY p.player_user_id
                ORDER BY b.placed_at, b.bet_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            2
        ) AS total_lost_amount,
        ROUND(
            SUM(CASE WHEN b.result = 'win' THEN b.local_balance_change ELSE 0 END) OVER (
                PARTITION BY p.player_user_id
                ORDER BY b.placed_at, b.bet_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            2
        ) AS total_won_amount,
        ROW_NUMBER() OVER (
            PARTITION BY p.player_user_id
            ORDER BY b.placed_at DESC, b.bet_id DESC
        ) AS rn
    FROM participants p
    JOIN bets b
        ON b.participant_id = p.participant_id
),
bet_totals AS (
    SELECT
        player_user_id,
        total_bet_amount,
        total_lost_amount,
        total_won_amount
    FROM bet_history
    WHERE rn = 1
)
SELECT
    u.login AS player_login,
    COALESCE(dt.total_input, 0) AS total_input,
    COALESCE(bt.total_bet_amount, 0) AS total_bet_amount,
    COALESCE(bt.total_lost_amount, 0) AS total_lost_amount,
    COALESCE(bt.total_won_amount, 0) AS total_won_amount,
    pl.global_balance,
    COALESCE(dt.total_output, 0) AS total_output
FROM players pl
JOIN users u
    ON u.user_id = pl.user_id
LEFT JOIN doc_totals dt
    ON dt.player_user_id = pl.user_id
LEFT JOIN bet_totals bt
    ON bt.player_user_id = pl.user_id
ORDER BY u.login;