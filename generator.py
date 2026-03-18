import random
from datetime import datetime, timedelta
from decimal import Decimal
from faker import Faker


fake = Faker("ru_RU")
random.seed(42)
Faker.seed(42)

OUTPUT_FILE = "generated_test_data.sql"

# объёмы данных
ADMINS_COUNT = 3
MANAGERS_COUNT = 5
MODERATORS_COUNT = 6
PLAYERS_COUNT = 120

GAME_TYPES_COUNT = 12
TOURNAMENTS_COUNT = 8
SESSIONS_COUNT = 30

MIN_ROUNDS = 3
MAX_ROUNDS = 8

MIN_PARTICIPANTS = 2
MAX_PARTICIPANTS = 8

MIN_BETS_PER_PARTICIPANT = 1
MAX_BETS_PER_PARTICIPANT = 6

MIN_DOCS_PER_PLAYER = 1
MAX_DOCS_PER_PLAYER = 4

BASE_DATE = datetime(2026, 1, 1, 12, 0, 0)


def sql_str(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")


def sql_datetime(value: datetime) -> str:
    return value.strftime("%Y-%m-%d %H:%M:%S")


def rand_money(left: int, right: int) -> Decimal:
    return Decimal(random.randint(left, right)).quantize(Decimal("1.00"))


def sql_bool(value: bool) -> str:
    return "TRUE" if value else "FALSE"


def write_insert_block(lines, title):
    lines.append("")
    lines.append(f"-- {title}")


used_logins = set()


def make_login(prefix: str) -> str:
    while True:
        name = fake.user_name().replace(".", "_").replace("-", "_").lower()
        login = f"{prefix}_{name}_{random.randint(1000, 9999)}"
        if login not in used_logins:
            used_logins.add(login)
            return login


def get_game_name(index: int) -> str:
    names = [
        "Poker", "Roulette", "Blackjack", "Baccarat", "Slots",
        "Texas Holdem", "Omaha", "Casino War", "Keno", "Pai Gow",
        "Red Dog", "Sic Bo", "Video Poker", "Craps", "Wheel of Fortune"
    ]
    return names[index % len(names)]


users = []
admins = []
managers = []
moderators = []
players = []

game_types = []
tournaments = []
sessions = []
rounds = []
participants = []
balance_movements = []
bets = []
financial_documents = []

next_user_id = 1
next_game_type_id = 1
next_tournament_id = 1
next_session_id = 1
next_round_id = 1
next_participant_id = 1
next_movement_id = 1
next_bet_id = 1
next_document_id = 1


def add_user(kind: str):
    global next_user_id

    login = make_login(kind)
    user = {
        "user_id": next_user_id,
        "login": login,
        "password_hash": f"hash_{login}",
        "avatar_url": fake.image_url(),
        "is_blocked": False,
        "blocked_by_user_id": None,
        "blocked_at": None,
        "block_reason": None,
    }

    users.append(user)
    next_user_id += 1
    return user


# пользователи
for _ in range(ADMINS_COUNT):
    user = add_user("admin")
    admins.append(user["user_id"])

for _ in range(MANAGERS_COUNT):
    user = add_user("manager")
    managers.append(user["user_id"])

for _ in range(MODERATORS_COUNT):
    user = add_user("moderator")
    moderators.append(user["user_id"])

for _ in range(PLAYERS_COUNT):
    user = add_user("player")
    players.append({
        "user_id": user["user_id"],
        "global_balance": rand_money(300, 15000),
    })


# часть пользователей блокируем
possible_blockers = admins + moderators
block_reasons = [
    "Подозрительная игровая активность",
    "Нарушение правил платформы",
    "Множественные жалобы",
    "Попытка мошенничества",
]

candidates_for_block = [u for u in users if u["user_id"] not in possible_blockers]
blocked_count = max(5, len(candidates_for_block) // 20)

for user in random.sample(candidates_for_block, blocked_count):
    user["is_blocked"] = True
    user["blocked_by_user_id"] = random.choice(possible_blockers)
    user["blocked_at"] = BASE_DATE + timedelta(days=random.randint(1, 60), hours=random.randint(0, 23))
    user["block_reason"] = random.choice(block_reasons)


# типы игр
game_names = [get_game_name(i) for i in range(GAME_TYPES_COUNT)]
random.shuffle(game_names)

for i in range(GAME_TYPES_COUNT):
    can_have_tournament = random.choice([True, False])

    game_types.append({
        "game_type_id": next_game_type_id,
        "name": game_names[i],
        "description": fake.sentence(nb_words=8),
        "rounds_count": random.choice([None, random.randint(3, 10)]),
        "max_players": random.randint(2, 12),
        "can_join_in_progress": random.choice([True, False]),
        "manager_user_id": random.choice(managers),
        "can_have_tournament": can_have_tournament,
        "min_local_balance": rand_money(0, 500),
        "min_bet": rand_money(1, 50),
        "can_leave_without_balance_loss": random.choice([True, False]),
    })
    next_game_type_id += 1


# турниры
tournament_enabled_games = [g for g in game_types if g["can_have_tournament"]]
if not tournament_enabled_games:
    tournament_enabled_games = [game_types[0]]

for _ in range(TOURNAMENTS_COUNT):
    game_type = random.choice(tournament_enabled_games)
    start_time = BASE_DATE + timedelta(days=random.randint(10, 90), hours=random.randint(0, 12))

    tournaments.append({
        "tournament_id": next_tournament_id,
        "game_type_id": game_type["game_type_id"],
        "entry_fee": rand_money(20, 300),
        "starts_at": start_time,
        "prize_fund": rand_money(500, 10000),
    })
    next_tournament_id += 1


# сессии
for _ in range(SESSIONS_COUNT):
    game_type = random.choice(game_types)
    tournament_id = None

    if game_type["can_have_tournament"] and random.choice([True, False]):
        candidates = [t for t in tournaments if t["game_type_id"] == game_type["game_type_id"]]
        if candidates:
            tournament_id = random.choice(candidates)["tournament_id"]

    start_time = BASE_DATE + timedelta(days=random.randint(1, 120), hours=random.randint(0, 20))
    duration_minutes = random.randint(40, 180)

    sessions.append({
        "session_id": next_session_id,
        "game_type_id": game_type["game_type_id"],
        "moderator_user_id": random.choice(moderators),
        "tournament_id": tournament_id,
        "parent_session_id": None,
        "description": fake.text(max_nb_chars=120),
        "starts_at": start_time,
        "ends_at": start_time + timedelta(minutes=duration_minutes),
        "prize_fund": rand_money(0, 3000) if tournament_id is not None else Decimal("0.00"),
    })
    next_session_id += 1


# дочерние сессии: родитель только с меньшим id
if len(sessions) > 1:
    for session in random.sample(sessions, k=min(5, len(sessions))):
        parents = [s for s in sessions if s["session_id"] < session["session_id"]]
        if parents:
            session["parent_session_id"] = random.choice(parents)["session_id"]


# раунды
rounds_by_session = {}

for session in sessions:
    count = random.randint(MIN_ROUNDS, MAX_ROUNDS)
    rounds_by_session[session["session_id"]] = []

    current_start = session["starts_at"]
    for round_number in range(1, count + 1):
        duration = random.randint(8, 20)
        gap = random.randint(1, 5)

        round_row = {
            "round_id": next_round_id,
            "session_id": session["session_id"],
            "round_number": round_number,
            "starts_at": current_start,
            "ends_at": current_start + timedelta(minutes=duration),
        }

        rounds.append(round_row)
        rounds_by_session[session["session_id"]].append(round_row)
        next_round_id += 1

        current_start = round_row["ends_at"] + timedelta(minutes=gap)


# участники + движения денег
player_ids = [p["user_id"] for p in players]

for session in sessions:
    available_players = min(MAX_PARTICIPANTS, len(player_ids))
    min_players = min(MIN_PARTICIPANTS, available_players)
    players_count = random.randint(min_players, available_players)

    chosen_players = random.sample(player_ids, players_count)
    session_rounds = rounds_by_session[session["session_id"]]
    game_type = next(g for g in game_types if g["game_type_id"] == session["game_type_id"])

    for player_id in chosen_players:
        joined_round = random.choice(session_rounds)

        left_round = None
        if random.choice([False, False, True]):
            later_rounds = [r for r in session_rounds if r["round_number"] >= joined_round["round_number"]]
            left_round = random.choice(later_rounds)

        entry_fee = Decimal("0.00")
        if session["tournament_id"] is not None:
            tournament = next(t for t in tournaments if t["tournament_id"] == session["tournament_id"])
            entry_fee = tournament["entry_fee"]

        local_balance = max(game_type["min_local_balance"], rand_money(50, 1000))

        participant = {
            "participant_id": next_participant_id,
            "session_id": session["session_id"],
            "player_user_id": player_id,
            "joined_round_id": joined_round["round_id"],
            "left_round_id": left_round["round_id"] if left_round else None,
            "result": random.choice(["win", "lose", "undefined"]),
            "entry_fee": entry_fee,
            "local_balance": local_balance,
        }
        participants.append(participant)

        balance_movements.append({
            "movement_id": next_movement_id,
            "participant_id": next_participant_id,
            "movement_type": "global_to_local",
            "amount": local_balance,
            "created_at": joined_round["starts_at"] - timedelta(minutes=random.randint(5, 30)),
        })

        next_participant_id += 1
        next_movement_id += 1


# ставки + обратные движения денег
for participant in participants:
    session_rounds = rounds_by_session[participant["session_id"]]

    joined_round_number = next(
        r["round_number"] for r in rounds if r["round_id"] == participant["joined_round_id"]
    )

    if participant["left_round_id"] is None:
        available_rounds = [r for r in session_rounds if r["round_number"] >= joined_round_number]
    else:
        left_round_number = next(
            r["round_number"] for r in rounds if r["round_id"] == participant["left_round_id"]
        )
        available_rounds = [
            r for r in session_rounds
            if joined_round_number <= r["round_number"] <= left_round_number
        ]

    random.shuffle(available_rounds)
    if not available_rounds:
        continue

    max_bets = min(MAX_BETS_PER_PARTICIPANT, len(available_rounds))
    min_bets = min(MIN_BETS_PER_PARTICIPANT, max_bets)
    selected_rounds = available_rounds[:random.randint(min_bets, max_bets)]

    session_row = next(s for s in sessions if s["session_id"] == participant["session_id"])
    game_type = next(g for g in game_types if g["game_type_id"] == session_row["game_type_id"])

    for round_row in selected_rounds:
        amount = max(game_type["min_bet"], rand_money(1, 100))
        win = random.choice([True, False])

        bets.append({
            "bet_id": next_bet_id,
            "participant_id": participant["participant_id"],
            "round_id": round_row["round_id"],
            "placed_at": round_row["starts_at"] + timedelta(minutes=random.randint(1, 5)),
            "amount": amount,
            "result": "win" if win else "lose",
            "local_balance_change": amount * Decimal("2.00") if win else -amount,
        })
        next_bet_id += 1

    if random.choice([True, False]):
        session_end = next(s["ends_at"] for s in sessions if s["session_id"] == participant["session_id"])
        balance_movements.append({
            "movement_id": next_movement_id,
            "participant_id": participant["participant_id"],
            "movement_type": "local_to_global",
            "amount": rand_money(10, 300),
            "created_at": session_end,
        })
        next_movement_id += 1


# финансовые документы
for player in players:
    docs_count = random.randint(MIN_DOCS_PER_PLAYER, MAX_DOCS_PER_PLAYER)

    for _ in range(docs_count):
        financial_documents.append({
            "document_id": next_document_id,
            "player_user_id": player["user_id"],
            "amount": rand_money(100, 5000),
            "doc_type": random.choice(["deposit", "withdraw"]),
            "created_at": BASE_DATE + timedelta(days=random.randint(1, 120), hours=random.randint(0, 23)),
        })
        next_document_id += 1


# выгрузка в sql
lines = []
lines.append("-- generated_test_data.sql")
lines.append("-- generated by python + faker")
lines.append("")
lines.append("START TRANSACTION;")


write_insert_block(lines, "users")
for user in users:
    blocked_by = "NULL" if user["blocked_by_user_id"] is None else str(user["blocked_by_user_id"])
    blocked_at = "NULL" if user["blocked_at"] is None else f"'{sql_datetime(user['blocked_at'])}'"
    block_reason = "NULL" if user["block_reason"] is None else f"'{sql_str(user['block_reason'])}'"

    lines.append(
        "INSERT INTO users "
        "(user_id, login, password_hash, avatar_url, is_blocked, blocked_by_user_id, blocked_at, block_reason) "
        f"VALUES ({user['user_id']}, '{sql_str(user['login'])}', '{sql_str(user['password_hash'])}', "
        f"'{sql_str(user['avatar_url'])}', {sql_bool(user['is_blocked'])}, {blocked_by}, "
        f"{blocked_at}, {block_reason});"
    )


write_insert_block(lines, "admins")
for user_id in admins:
    lines.append(f"INSERT INTO admins (user_id) VALUES ({user_id});")


write_insert_block(lines, "managers")
for user_id in managers:
    lines.append(f"INSERT INTO managers (user_id) VALUES ({user_id});")


write_insert_block(lines, "moderators")
for user_id in moderators:
    lines.append(f"INSERT INTO moderators (user_id) VALUES ({user_id});")


write_insert_block(lines, "players")
for player in players:
    lines.append(
        f"INSERT INTO players (user_id, global_balance) VALUES ({player['user_id']}, {player['global_balance']});"
    )


write_insert_block(lines, "game_types")
for game_type in game_types:
    rounds_count = "NULL" if game_type["rounds_count"] is None else str(game_type["rounds_count"])

    lines.append(
        "INSERT INTO game_types "
        "(game_type_id, name, description, rounds_count, max_players, can_join_in_progress, "
        "manager_user_id, can_have_tournament, min_local_balance, min_bet, can_leave_without_balance_loss) "
        f"VALUES ({game_type['game_type_id']}, '{sql_str(game_type['name'])}', "
        f"'{sql_str(game_type['description'])}', {rounds_count}, {game_type['max_players']}, "
        f"{sql_bool(game_type['can_join_in_progress'])}, {game_type['manager_user_id']}, "
        f"{sql_bool(game_type['can_have_tournament'])}, {game_type['min_local_balance']}, "
        f"{game_type['min_bet']}, {sql_bool(game_type['can_leave_without_balance_loss'])});"
    )


write_insert_block(lines, "tournaments")
for tournament in tournaments:
    lines.append(
        "INSERT INTO tournaments "
        "(tournament_id, game_type_id, entry_fee, starts_at, prize_fund) "
        f"VALUES ({tournament['tournament_id']}, {tournament['game_type_id']}, "
        f"{tournament['entry_fee']}, '{sql_datetime(tournament['starts_at'])}', {tournament['prize_fund']});"
    )


write_insert_block(lines, "sessions")
for session in sessions:
    tournament_id = "NULL" if session["tournament_id"] is None else str(session["tournament_id"])
    parent_session_id = "NULL" if session["parent_session_id"] is None else str(session["parent_session_id"])

    lines.append(
        "INSERT INTO sessions "
        "(session_id, game_type_id, moderator_user_id, tournament_id, parent_session_id, "
        "description, starts_at, ends_at, prize_fund) "
        f"VALUES ({session['session_id']}, {session['game_type_id']}, {session['moderator_user_id']}, "
        f"{tournament_id}, {parent_session_id}, '{sql_str(session['description'])}', "
        f"'{sql_datetime(session['starts_at'])}', '{sql_datetime(session['ends_at'])}', {session['prize_fund']});"
    )


write_insert_block(lines, "rounds")
for round_row in rounds:
    lines.append(
        "INSERT INTO rounds "
        "(round_id, session_id, round_number, starts_at, ends_at) "
        f"VALUES ({round_row['round_id']}, {round_row['session_id']}, {round_row['round_number']}, "
        f"'{sql_datetime(round_row['starts_at'])}', '{sql_datetime(round_row['ends_at'])}');"
    )


write_insert_block(lines, "participants")
for participant in participants:
    left_round_id = "NULL" if participant["left_round_id"] is None else str(participant["left_round_id"])

    lines.append(
        "INSERT INTO participants "
        "(participant_id, session_id, player_user_id, joined_round_id, left_round_id, result, entry_fee, local_balance) "
        f"VALUES ({participant['participant_id']}, {participant['session_id']}, {participant['player_user_id']}, "
        f"{participant['joined_round_id']}, {left_round_id}, '{participant['result']}', "
        f"{participant['entry_fee']}, {participant['local_balance']});"
    )


write_insert_block(lines, "balance_movements")
for movement in balance_movements:
    lines.append(
        "INSERT INTO balance_movements "
        "(movement_id, participant_id, movement_type, amount, created_at) "
        f"VALUES ({movement['movement_id']}, {movement['participant_id']}, '{movement['movement_type']}', "
        f"{movement['amount']}, '{sql_datetime(movement['created_at'])}');"
    )


write_insert_block(lines, "bets")
for bet in bets:
    lines.append(
        "INSERT INTO bets "
        "(bet_id, participant_id, round_id, placed_at, amount, result, local_balance_change) "
        f"VALUES ({bet['bet_id']}, {bet['participant_id']}, {bet['round_id']}, "
        f"'{sql_datetime(bet['placed_at'])}', {bet['amount']}, '{bet['result']}', {bet['local_balance_change']});"
    )


write_insert_block(lines, "financial_documents")
for doc in financial_documents:
    lines.append(
        "INSERT INTO financial_documents "
        "(document_id, player_user_id, amount, doc_type, created_at) "
        f"VALUES ({doc['document_id']}, {doc['player_user_id']}, {doc['amount']}, "
        f"'{doc['doc_type']}', '{sql_datetime(doc['created_at'])}');"
    )

lines.append("")
lines.append("COMMIT;")

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"Готово: {OUTPUT_FILE}")
print(f"users: {len(users)}")
print(f"admins: {len(admins)}")
print(f"managers: {len(managers)}")
print(f"moderators: {len(moderators)}")
print(f"players: {len(players)}")
print(f"game_types: {len(game_types)}")
print(f"tournaments: {len(tournaments)}")
print(f"sessions: {len(sessions)}")
print(f"rounds: {len(rounds)}")
print(f"participants: {len(participants)}")
print(f"balance_movements: {len(balance_movements)}")
print(f"bets: {len(bets)}")
print(f"financial_documents: {len(financial_documents)}")