import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Multi-Layout Bingo Backend")

BINGO_RANGES = {
    'B': (1, 15),
    'I': (16, 30),
    'N': (31, 45),
    'G': (46, 60),
    'O': (61, 75)
}

class Player:
    def __init__(self, username: str, websocket: WebSocket, card_type: str = "75-Ball (5x5 Grid)"):
        self.username = username
        self.websocket = websocket
        self.card_type = card_type
        self.card = self.generate_card()

    def generate_card(self) -> List[List[int]]:
        """Generates valid 75-Ball or 90-Ball matrix patterns strictly based on room setups."""
        if "90-Ball" in self.card_type:
            # Generate 90-ball ticket: 3 rows by 9 columns[cite: 1]
            # Standard distribution ranges per column: 1-9, 10-19 ... 80-90
            ticket = [[0 for _ in range(9)] for _ in range(3)]
            for col in range(9):
                low = 1 if col == 0 else col * 10
                high = 9 if col == 0 else (89 if col == 7 else 90)
                
                # Sample 3 ascending ordered values unique to the column range
                column_digits = random.sample(range(low, high + 1), 3)
                column_digits.sort()
                for row in range(3):
                    ticket[row][col] = column_digits[row]
            
            # Leave exactly 5 numbers per row by blanking out 4 cells randomly[cite: 1]
            for row in range(3):
                clear_indices = random.sample(range(9), 4)
                for idx in clear_indices:
                    ticket[row][idx] = 0
            return ticket
            
        else:
            # Standard 75-ball 5x5 card pattern layout logic[cite: 4]
            columns = {}
            for letter, (low, high) in BINGO_RANGES.items():
                columns[letter] = random.sample(range(low, high + 1), 5)
            
            card = []
            for row_idx in range(5):
                row = []
                for col_idx, letter in enumerate(['B', 'I', 'N', 'G', 'O']):
                    if row_idx == 2 and col_idx == 2:
                        row.append(0)  # Free Space indicator[cite: 4]
                    else:
                        row.append(columns[letter][row_idx])
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
        disconnected = []
        for username, player in self.players.items():
            try:
                await player.websocket.send_text(payload)
            except Exception:
                disconnected.append(username)
        for username in disconnected:
            if username in self.players:
                del self.players[username]

    async def update_room_rules(self, card_type: str, draw_interval: int):
        """Authoritatively rewrites rules mid-lobby execution from the admin panel."""
        self.card_type = card_type
        self.draw_interval = float(draw_interval)
        
        # Reset matching scopes depending on geometric selection limits
        max_pool = 91 if "90-Ball" in card_type else 76
        self.available_numbers = list(range(1, max_pool))
        random.shuffle(self.available_numbers)
        
        # Regenerate game boards for all connected players to avoid format mismatches
        for player in self.players.values():
            player.card_type = card_type
            player.card = player.generate_card()
            try:
                await player.websocket.send_text(json.dumps({
                    "event": "card_assigned",
                    "card": player.card,
                    "username": player.username,
                    "room_id": self.room_id
                }))
            except Exception:
                pass

    async def start_game_loop(self):
        self.game_started = True
        await self.broadcast({"event": "game_started", "message": "The game has begun!"})
        
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(self.draw_interval)
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
        """Authoritative pattern validation to fully mitigate game client tampering."""
        drawn_set = set(self.drawn_numbers) | {0}
        
        # 90-Ball ticket winning criteria check (Full House verification rule)[cite: 1]
        if len(player_card[0]) == 9:
            for r in range(3):
                for c in range(9):
                    val = player_card[r][c]
                    if val != 0 and val not in drawn_set:
                        return False
            return True
            
        # 75-Ball multi-line column cross matching system check[cite: 4]
        else:
            marked = [[player_card[r][c] in drawn_set for c in range(5)] for r in range(5)]
            if any(all(row) for row in marked): return True
            if any(all(marked[r][c] for r in range(5)) for c in range(5)): return True
            if all(marked[i][i] for i in range(5)) or all(marked[i][4 - i] for i in range(5)): return True
            return False

rooms: Dict[str, BingoRoom] = {}

@app.get("/")
def health_check():
    return {"status": "healthy", "game": "Bingo Engine Live"}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str):
    await websocket.accept()
    if room_id not in rooms:
        rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    
    # Handle the admin connection separately from normal players
    is_admin = (username == "SystemAdmin")
    
    if not is_admin:
        player = Player(username, websocket, room.card_type)
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
            
            # Explicit Protected Payload Router Check
            if action == "update_room_rules":
                if payload.get("admin_secret") == "BingoAdmin2026":
                    await room.update_room_rules(
                        card_type=payload.get("card_type", "75-Ball (5x5 Grid)"),
                        draw_interval=payload.get("draw_interval", 5)
                    )
                    await room.broadcast({
                        "event": "room_rules_changed",
                        "message": f"System Alert: Admin updated card rules to {room.card_type}."
                    })
            
            elif action == "claim_bingo" and not room.game_over and not is_admin:
                target_player = room.players.get(username)
                if target_player and room.verify_bingo(target_player.card):
                    room.game_over = True
                    await room.broadcast({
                        "event": "game_over",
                        "winner": username,
                        "winning_card": target_player.card
                    })
                else:
                    await websocket.send_text(json.dumps({
                        "event": "invalid_claim",
                        "message": "Your board doesn't match the drawn numbers yet!"
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
        if not is_admin and username in room.players:
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
