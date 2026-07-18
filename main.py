import asyncio
import json
import os
import random
import time
from typing import Dict, List, Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, status
from pydantic import BaseModel
import jwt

app = FastAPI(title="Authoritative Secure Bingo Backend")

JWT_SECRET = os.getenv("JWT_SECRET", "YOUR_SUPER_SECRET_SECURITY_KEY")
JWT_ALGORITHM = "HS256"
ADMIN_PASSWORD = os.getenv("BINGO_ADMIN_PASSWORD", "SuperSecureAdminPassword123")

BINGO_RANGES = {
    'B': (1, 15),
    'I': (16, 30),
    'N': (31, 45),
    'G': (46, 60),
    'O': (61, 75)
}

def create_admin_token(username: str) -> str:
    payload = {
        "sub": username,
        "role": "admin",
        "exp": time.time() + 86400
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

class AdminLoginRequest(BaseModel):
    username: str
    password: str

class Player:
    def __init__(self, username: str, websocket: WebSocket, card_type: str = "classic", is_admin: bool = False):
        self.username = username
        self.websocket = websocket
        self.is_admin = is_admin
        self.card_type = card_type
        self.card = self.generate_card()

    def generate_card(self) -> List[List[int]]:
        dim = 5 if self.card_type == "classic" else 3
        columns = {}
        letters = ['B', 'I', 'N', 'G', 'O'] if dim == 5 else ['B', 'N', 'O']
        for letter in letters:
            low, high = BINGO_RANGES[letter]
            columns[letter] = random.sample(range(low, high + 1), dim)
        
        card = []
        for row_idx in range(dim):
            row = []
            for col_idx, letter in enumerate(letters):
                if dim == 5 and row_idx == 2 and col_idx == 2:
                    row.append(0)
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
        self.loop_task: Optional[asyncio.Task] = None
        self.rule_type = "standard"  
        self.card_type = "classic"   

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
        await self.broadcast({
            "event": "game_started", 
            "message": f"Game Live! Mode: {self.rule_type.upper()} ({self.card_type})"
        })
        
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(5.0)
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
        dim = len(player_card)
        marked = [[player_card[r][c] in drawn_set for c in range(dim)] for r in range(dim)]
        
        if self.rule_type == "blackout":
            return all(all(row) for row in marked)
            
        if self.rule_type == "corners":
            return marked[0][0] and marked[0][dim-1] and marked[dim-1][0] and marked[dim-1][dim-1]
            
        if any(all(row) for row in marked): return True
        if any(all(marked[r][c] for r in range(dim)) for c in range(dim)): return True
        if all(marked[i][i] for i in range(dim)) or all(marked[i][dim - 1 - i] for i in range(dim)): return True
        return False

rooms: Dict[str, BingoRoom] = {}

@app.get("/")
def health_check():
    return {"status": "healthy", "game": "Bingo Security Layer Active"}

@app.post("/api/admin/login")
def admin_login(credentials: AdminLoginRequest):
    if credentials.password != ADMIN_PASSWORD:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin credentials.")
    token = create_admin_token(credentials.username)
    return {"access_token": token, "token_type": "bearer", "username": credentials.username}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str, token: Optional[str] = None):
    await websocket.accept()
    
    is_admin_user = False
    if token:
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            if payload.get("role") == "admin" and payload.get("sub") == username:
                is_admin_user = True
        except jwt.PyJWTError:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    if room_id not in rooms:
        rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    
    player = Player(username, websocket, card_type=room.card_type, is_admin=is_admin_user)
    room.players[username] = player
    
    await websocket.send_text(json.dumps({
        "event": "card_assigned",
        "card": player.card,
        "card_type": room.card_type,
        "username": username,
        "room_id": room_id
    }))
    
    await room.broadcast({
        "event": "player_joined",
        "username": username,
        "total_players": len(room.players)
    })
    
    if len(room.players) >= 2 and not room.game_started and not is_admin_user:
        room.loop_task = asyncio.create_task(room.start_game_loop())

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            action = payload.get("action")
            
            if action == "update_room_rules":
                if not player.is_admin:
                    await websocket.send_text(json.dumps({
                        "event": "unauthorized_action",
                        "message": "Admin authorization verified token check failed."
                    }))
                    continue
                
                if not room.game_started:
                    room.rule_type = payload.get("rule_type", room.rule_type)
                    room.card_type = payload.get("card_type", room.card_type)
                    await room.broadcast({
                        "event": "room_rules_updated",
                        "rule_type": room.rule_type,
                        "card_type": room.card_type,
                        "message": f"Rules configuration updated to {room.rule_type} ({room.card_type})"
                    })
                    
            elif action == "start_admin_match":
                if player.is_admin and not room.game_started:
                    room.loop_task = asyncio.create_task(room.start_game_loop())

            elif action == "claim_bingo" and not room.game_over:
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
                        "message": "Win verification failed: Criteria unmet."
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
        if username in room.players:
            del room.players[username]
        await room.broadcast({
            "event": "player_left",
            "username": username,
            "total_players": len(room.players)
        })
        if not room.players and room.loop_task:
            room.loop_task.cancel()
            rooms.pop(room_id, None)
