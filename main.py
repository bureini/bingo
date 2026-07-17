import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Bingo Backend")

# Standard Bingo ranges
BINGO_RANGES = {
    'B': (1, 15),
    'I': (16, 30),
    'N': (31, 45),
    'G': (46, 60),
    'O': (61, 75)
}

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.card = self.generate_card()

    def generate_card(self) -> List[List[int]]:
        """Generates a secure 5x5 Bingo card matrix."""
        columns = {}
        for letter, (low, high) in BINGO_RANGES.items():
            columns[letter] = random.sample(range(low, high + 1), 5)
        
        card = []
        for row_idx in range(5):
            row = []
            for col_idx, letter in enumerate(['B', 'I', 'N', 'G', 'O']):
                if row_idx == 2 and col_idx == 2:
                    row.append(0)  # Center FREE space represented as 0
                else:
                    row.append(columns[letter][row_idx])
            card.append(row)
        return card

class BingoRoom:
    def __init__(self, room_id: str):
        self.room_id = room_id
        self.players: Dict[str, Player] = {}
        self.drawn_numbers: List[int] = []
        self.available_numbers: List[int] = list(range(1, 76))
        random.shuffle(self.available_numbers)
        self.game_started = False
        self.game_over = False
        self.loop_task: asyncio.Task = None

    async def broadcast(self, message: dict):
        payload = json.dumps(message)
        disconnected = []
        for username, player in self.players.items():
            try:
                await player.websocket.send_text(payload)
            except Exception:
                disconnected.append(username)
        for username in disconnected:
            if username in self.players:
                del self.players[username]

    async def start_game_loop(self):
        self.game_started = True
        await self.broadcast({"event": "game_started", "message": "The game has begun!"})
        
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(5.0)  # Draw every 5 seconds
            if self.game_over:
                break
            num = self.available_numbers.pop()
            self.drawn_numbers.append(num)
            await self.broadcast({
                "event": "number_drawn",
                "number": num,
                "history": self.drawn_numbers
            })

    def verify_bingo(self, player_card: List[List[int]]) -> bool:
        drawn_set = set(self.drawn_numbers) | {0}
        marked = [[player_card[r][c] in drawn_set for c in range(5)] for r in range(5)]
        
        if any(all(row) for row in marked): return True
        if any(all(marked[r][c] for r in range(5)) for c in range(5)): return True
        if all(marked[i][i] for i in range(5)) or all(marked[i][4 - i] for i in range(5)): return True
        return False

rooms: Dict[str, BingoRoom] = {}

@app.get("/")
def health_check():
    return {"status": "healthy", "game": "Bingo Engine"}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str):
    await websocket.accept()
    if room_id not in rooms:
        rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    
    player = Player(username, websocket)
    room.players[username] = player
    
    await websocket.send_text(json.dumps({
        "event": "card_assigned",
        "card": player.card,
        "username": username,
        "room_id": room_id
    }))
    
    await room.broadcast({
        "event": "player_joined",
        "username": username,
        "total_players": len(room.players)
    })
    
    if len(room.players) >= 2 and not room.game_started:
        room.loop_task = asyncio.create_task(room.start_game_loop())

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            action = payload.get("action")
            
            if action == "claim_bingo" and not room.game_over:
                if room.verify_bingo(player.card):
                    room.game_over = True
                    await room.broadcast({
                        "event": "game_over",
                        "winner": username,
                        "winning_card": player.card
                    })
                else:
                    await websocket.send_text(json.dumps({
                        "event": "invalid_claim",
                        "message": "Your board doesn't match the drawn numbers yet!"
                    }))
            
            # Real-time message multiplexed router
            elif action == "send_message":
                msg_text = payload.get("message", "").strip()
                if msg_text:
                    await room.broadcast({
                        "event": "chat_message",
                        "sender": username,
                        "message": msg_text
                    })
                    
    except WebSocketDisconnect:
        if username in room.players:
            del room.players[username]
        await room.broadcast({
            "event": "player_left",
            "username": username,
            "total_players": len(room.players)
        })
        if not room.players:
            if room.loop_task:
                room.loop_task.cancel()
            rooms.pop(room_id, None)