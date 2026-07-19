import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative My Bingo Backend")

BINGO_RANGES = {
    'B': (1, 15), 'I': (16, 30), 'N': (31, 45), 'G': (46, 60), 'O': (61, 75)
}

class Player:
    def __init__(self, username: str, websocket: WebSocket, card_type: str = "75-Ball (5x5 Grid)"):
        self.username = username
        self.websocket = websocket
        self.card_type = card_type
        self.card = self.generate_card()

    def generate_card(self) -> List[List[int]]:
        if "90-Ball" in self.card_type:
            ticket = [[0 for _ in range(9)] for _ in range(3)]
            for col in range(9):
                low = 1 if col == 0 else col * 10
                high = 9 if col == 0 else (89 if col == 7 else 90)
                column_digits = random.sample(range(low, high + 1), 3)
                column_digits.sort()
                for row in range(3):
                    ticket[row][col] = column_digits[row]
            for row in range(3):
                clear_indices = random.sample(range(9), 4)
                for idx in clear_indices:
                    ticket[row][idx] = 0
            return ticket
        else:
            columns = {letter: random.sample(range(low, high + 1), 5) for letter, (low, high) in BINGO_RANGES.items()}
            card = []
            for r in range(5):
                row = []
                for c, letter in enumerate(['B', 'I', 'N', 'G', 'O']):
                    row.append(0 if r == 2 and c == 2 else columns[letter][r])
                card.append(row)
            return card

class BingoRoom:
    def __init__(self, room_id: str):
        self.room_id = room_id
        self.players: Dict[str, Player] = {}
        self.drawn_numbers: List[int] = []
        self.card_type = "75-Ball (5x5 Grid)"
        self.draw_interval = 5.0
        self.available_numbers: List[int] = list(range(1, 76))
        random.shuffle(self.available_numbers)
        self.game_started = False
        self.game_over = False
        self.loop_task: asyncio.Task = None

    async def broadcast(self, message: dict):
        payload = json.dumps(message)
        for p in list(self.players.values()):
            try:
                await p.websocket.send_text(payload)
            except Exception:
                pass

    async def update_room_rules(self, card_type: str, draw_interval: int):
        self.card_type = card_type
        self.draw_interval = float(draw_interval)
        max_pool = 91 if "90-Ball" in card_type else 76
        self.available_numbers = list(range(1, max_pool))
        random.shuffle(self.available_numbers)
        for player in self.players.values():
            player.card_type = card_type
            player.card = player.generate_card()
            await player.websocket.send_text(json.dumps({
                "event": "card_assigned", "card": player.card, "room_id": self.room_id
            }))

    async def start_game_loop(self):
        self.game_started = True
        await self.broadcast({"event": "game_started", "message": "Match Started!"})
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(self.draw_interval)
            if self.game_over: break
            num = self.available_numbers.pop()
            self.drawn_numbers.append(num)
            await self.broadcast({"event": "number_drawn", "number": num, "history": self.drawn_numbers})

    def verify_bingo(self, player_card: List[List[int]]) -> bool:
        drawn_set = set(self.drawn_numbers) | {0}
        if len(player_card[0]) == 9:
            for r in range(3):
                for c in range(9):
                    if player_card[r][c] != 0 and player_card[r][c] not in drawn_set:
                        return False
            return True
        else:
            marked = [[player_card[r][c] in drawn_set for c in range(5)] for r in range(5)]
            if any(all(row) for row in marked): return True
            if any(all(marked[r][c] for r in range(5)) for c in range(5)): return True
            return False

rooms: Dict[str, BingoRoom] = {}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str):
    await websocket.accept()
    if room_id not in rooms: rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    is_admin = (username == "SystemAdmin")
    if not is_admin:
        player = Player(username, websocket, room.card_type)
        room.players[username] = player
        await websocket.send_text(json.dumps({"event": "card_assigned", "card": player.card, "room_id": room_id}))
        if len(room.players) >= 2 and not room.game_started:
            room.loop_task = asyncio.create_task(room.start_game_loop())
    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            action = payload.get("action")
            if action == "update_room_rules" and payload.get("admin_secret") == "BingoAdmin2026":
                await room.update_room_rules(payload.get("card_type"), payload.get("draw_interval"))
                await room.broadcast({"event": "room_rules_changed", "message": f"Rules forced to {room.card_type}."})
            elif action == "claim_bingo" and not room.game_over and not is_admin:
                if room.verify_bingo(room.players[username].card):
                    room.game_over = True
                    await room.broadcast({"event": "game_over", "winner": username})
    except WebSocketDisconnect:
        if username in room.players: del room.players[username]
