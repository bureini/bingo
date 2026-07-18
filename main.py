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
        # Authoritative server-side verification tracking grid. (False = un-daubed, True = marked)
        # Automatically pre-daub the standard center FREE space (row index 2, col index 2)
        self.daubed_grid = [[False] * 5 for _ in range(5)]
        self.daubed_grid[2][2] = True
        self.is_active = True  # Tracks structural connectivity status

    def generate_card(self) -> List[List[int]]:
        """Generates a secure, non-duplicate 5x5 Bingo card matrix."""
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
        for username, player in list(self.players.items()):
            if player.is_active:
                try:
                    await player.websocket.send_text(payload)
                except Exception:
                    player.is_active = False

    async def start_game_loop(self):
        self.game_started = True
        await self.broadcast({"event": "game_started", "message": "The game has begun!"})
        
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(5.0)  # Autorun draw interval
            if self.game_over:
                break
            
            # --- "NEVER LOSE" SANDBOX ENGINE MODIFICATION ---
            # Prioritize numbers existing on the first active user's card to force a victory loop
            chosen_num = None
            active_players = [p for p in self.players.values() if p.is_active]
            
            if active_players:
                target_player = active_players[0]  # Designate first active user as win beneficiary
                flat_card = [num for row in target_player.card for num in row if num != 0]
                undrawn_card_nums = [n for n in flat_card if n not in self.drawn_numbers and n in self.available_numbers]
                
                # Introduce a heavy 80% generation bias favoring the targeted user's numbers
                if undrawn_card_nums and random.random() < 0.80:
                    chosen_num = random.choice(undrawn_card_nums)
                    self.available_numbers.remove(chosen_num)

            if not chosen_num:
                chosen_num = self.available_numbers.pop()

            self.drawn_numbers.append(chosen_num)
            await self.broadcast({
                "event": "number_drawn",
                "number": chosen_num,
                "history": self.drawn_numbers
            })

    def verify_bingo(self, player: Player) -> bool:
        """Verifies if the player's server-validated daubs form a legal winning vector."""
        marked = player.daubed_grid
        
        # Check all winning vectors across the matrix axes
        if any(all(row) for row in marked): return True
        if any(all(marked[r][c] for r in range(5)) for c in range(5)): return True
        if all(marked[i][i] for i in range(5)) or all(marked[i][4 - i] for i in range(5)): return True
        return False

rooms: Dict[str, BingoRoom] = {}

@app.get("/")
def health_check():
    return {"status": "healthy", "game": "Bingo Authoritative Engine"}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str):
    await websocket.accept()
    if room_id not in rooms:
        rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    
    # RE-ENTRY AND DISCONNECT HANDLING
    if username in room.players:
        player = room.players[username]
        player.websocket = websocket
        player.is_active = True
        event_type = "player_reconnected"
    else:
        player = Player(username, websocket)
        room.players[username] = player
        event_type = "card_assigned"
    
    # Send authoritative recovery state packet back to the client app
    await websocket.send_text(json.dumps({
        "event": event_type,
        "card": player.card,
        "daubed_grid": player.daubed_grid,
        "username": username,
        "room_id": room_id,
        "history": room.drawn_numbers,
        "game_started": room.game_started
    }))
    
    await room.broadcast({
        "event": "player_joined",
        "username": username,
        "total_players": len([p for p in room.players.values() if p.is_active])
    })
    
    if len([p for p in room.players.values() if p.is_active]) >= 2 and not room.game_started:
        room.loop_task = asyncio.create_task(room.start_game_loop())

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            action = payload.get("action")
            
            if action == "toggle_daub":
                row, col = payload.get("row"), payload.get("col")
                if isinstance(row, int) and isinstance(col, int) and 0 <= row < 5 and 0 <= col < 5:
                    target_num = player.card[row][col]
                    # API Spoofing Mitigation: Only allow daub if number was officially drawn or is FREE space (0)
                    if target_num == 0 or target_num in room.drawn_numbers:
                        player.daubed_grid[row][col] = not player.daubed_grid[row][col]
            
            elif action == "claim_bingo" and not room.game_over:
                if room.verify_bingo(player):
                    room.game_over = True
                    await room.broadcast({
                        "event": "game_over",
                        "winner": username,
                        "winning_card": player.card
                    })
                else:
                    await websocket.send_text(json.dumps({
                        "event": "invalid_claim",
                        "message": "Fraudulent claim blocked! Your board markers do not match drawn history."
                    }))
            
            elif action == "send_message":
                msg_text = payload.get("message", "").strip()
                if msg_text:
                    await room.broadcast({
                        "event": "chat_message",
                        "sender": username,
                        "message": msg_text
                    })
                    
    except WebSocketDisconnect:
        player.is_active = False
        await room.broadcast({
            "event": "player_left",
            "username": username,
            "total_players": len([p for p in room.players.values() if p.is_active])
        })
        
        # Grace period cleanup loop: dismantle the room if it remains entirely vacant for 60 seconds
        await asyncio.sleep(60.0)
        if not any(p.is_active for p in room.players.values()):
            if room.loop_task:
                room.loop_task.cancel()
            rooms.pop(room_id, None)
