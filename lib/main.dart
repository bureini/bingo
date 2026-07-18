import asyncio
import json
import random
import smtplib
from email.mime.text import MIMEText
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, BackgroundTasks
import os

app = FastAPI(title="Authoritative Regulated Bingo Engine")

BINGO_RANGES = {
    'B': (1, 15),
    'I': (16, 30),
    'N': (31, 45),
    'G': (46, 60),
    'O': (61, 75)
}

ADMIN_EMAIL = "bureiniuarai@gmail.com"

def send_sync_email(username: str, room_id: str):
    """Establishes an authentic SMTP handshake to deliver entry notification emails via TLS."""
    smtp_server = os.environ.get("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.environ.get("SMTP_PORT", "587"))
    sender_email = os.environ.get("SENDER_EMAIL")
    sender_password = os.environ.get("SENDER_PASSWORD")

    if not sender_email or not sender_password:
        print("[MAIL ERROR] Config variables missing. Set SENDER_EMAIL and SENDER_PASSWORD on Render.")
        return

    msg = MIMEText(f"Hello Administrator,\n\nA new player '{username}' has successfully entered live Bingo room '{room_id}'.\n\nRegards,\nBingo Automated Engine")
    msg["Subject"] = f"🔔 Bingo Alert: {username} Joined {room_id}"
    msg["From"] = sender_email
    msg["To"] = ADMIN_EMAIL

    try:
        with smtplib.SMTP(smtp_server, smtp_port, timeout=10) as server:
            server.starttls()
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, [ADMIN_EMAIL], msg.as_string())
        print(f"[MAIL SUCCESS] Notification successfully delivered to {ADMIN_EMAIL}")
    except Exception as e:
        print(f"[MAIL ERROR] SMTP secure transaction protocol failed: {e}")

async def send_async_entry_notification(username: str, room_id: str):
    """Offloads network-heavy SMTP transactions out of the primary WebSocket runtime thread loop."""
    loop = asyncio.get_running_loop()
    await loop.run_in_executor(None, send_sync_email, username, room_id)

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.card = self.generate_card()
        # Authoritative server daub checking array matrix (False = un-marked, True = marked)
        self.daubed_grid = [[False] * 5 for _ in range(5)]
        self.daubed_grid[2][2] = True  # Auto-daub standard center FREE space
        self.is_active = True

    def generate_card(self) -> List[List[int]]:
        columns = {}
        for letter, (low, high) in BINGO_RANGES.items():
            columns[letter] = random.sample(range(low, high + 1), 5)
        card = []
        for row_idx in range(5):
            row = []
            for col_idx, letter in enumerate(['B', 'I', 'N', 'G', 'O']):
                if row_idx == 2 and col_idx == 2:
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
        self.loop_task: asyncio.Task = None

    def get_active_usernames(self) -> List[str]:
        return [p.username for p in self.players.values() if p.is_active]

    async def broadcast(self, message: dict):
        payload = json.dumps(message)
        for username, player in list(self.players.items()):
            if player.is_active:
                try:
                    await player.websocket.send_text(payload)
                except Exception:
                    player.is_active = False

    async def broadcast_user_list(self):
        await self.broadcast({
            "event": "room_users_update",
            "users": self.get_active_usernames()
        })

    async def start_game_loop(self):
        self.game_started = True
        await self.broadcast({"event": "game_started", "message": "The game has begun!"})
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(5.0)
            if self.game_over:
                break
            
            # --- "NEVER LOSE" TESTING ENGINE MECHANISM ---
            chosen_num = None
            active_players = [p for p in self.players.values() if p.is_active]
            if active_players:
                target_player = active_players[0]  # Prioritize the first active testing user
                flat_card = [num for row in target_player.card for num in row if num != 0]
                undrawn_card_nums = [n for n in flat_card if n not in self.drawn_numbers and n in self.available_numbers]
                
                # Heavy 80% extraction bias targeting numbers remaining on their card grid
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
        if any(all(row) for row in marked): return True
        if any(all(marked[r][c] for r in range(5)) for c in range(5)): return True
        if all(marked[i][i] for i in range(5)) or all(marked[i][4 - i] for i in range(5)): return True
        return False

# CRITICAL POLICY: Restrict allocation to exactly two pre-initialized structures
rooms: Dict[str, BingoRoom] = {
    "ROOM100": BingoRoom("ROOM100"),
    "ROOM101": BingoRoom("ROOM101")
}

@app.get("/admin/dashboard")
def admin_dashboard():
    """Authoritative administrative metrics dashboard endpoint."""
    return {
        "status": "operational",
        "total_managed_rooms": len(rooms),
        "room_metrics": {
            r_id: {
                "active_users": r.get_active_usernames(),
                "total_count": len(r.get_active_usernames()),
                "is_active_match": r.game_started,
                "balls_drawn": len(r.drawn_numbers)
            } for r_id, r in rooms.items()
        }
    }

@app.get("/")
def health_check():
    return {"status": "healthy"}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str, background_tasks: BackgroundTasks):
    room_id = room_id.upper().strip()
    
    # Check 1: Enforce Strict Room Authorization Set Bounds
    if room_id not in rooms:
        await websocket.accept()
        await websocket.send_text(json.dumps({"event": "invalid_claim", "message": "Access Denied: Room must be ROOM100 or ROOM101."}))
        await websocket.close()
        return

    room = rooms[room_id]
    active_count = len(room.get_active_usernames())

    # Check 2: Hard-capped lobby safety check (1-80 players max)
    if active_count >= 80 and username not in room.players:
        await websocket.accept()
        await websocket.send_text(json.dumps({"event": "invalid_claim", "message": "Lobby Full: This room has reached its 80 player maximum."}))
        await websocket.close()
        return

    await websocket.accept()
    is_new_player = username not in room.players
    
    # State recovery and re-entry hook integration
    if username in room.players:
        player = room.players[username]
        player.websocket = websocket
        player.is_active = True
        event_type = "player_reconnected"
    else:
        player = Player(username, websocket)
        room.players[username] = player
        event_type = "card_assigned"
    
    await websocket.send_text(json.dumps({
        "event": event_type,
        "card": player.card,
        "daubed_grid": player.daubed_grid,
        "username": username,
        "room_id": room_id,
        "history": room.drawn_numbers,
        "game_started": room.game_started
    }))
    
    if is_new_player:
        background_tasks.add_task(send_async_entry_notification, username, room_id)
    
    await room.broadcast_user_list()
    
    if len(room.get_active_usernames()) >= 2 and not room.game_started:
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
                    # Anti-Cheat Validation: Only sync marker if number was officially drawn or is FREE (0)
                    if target_num == 0 or target_num in room.drawn_numbers:
                        player.daubed_grid[row][col] = not player.daubed_grid[row][col]
            
            elif action == "claim_bingo" and not room.game_over:
                if room.verify_bingo(player):
                    room.game_over = True
                    await room.broadcast({"event": "game_over", "winner": username, "winning_card": player.card})
                else:
                    await websocket.send_text(json.dumps({"event": "invalid_claim", "message": "Fraudulent claim blocked! Board state mismatch."}))
            
            elif action == "send_message":
                msg_text = payload.get("message", "").strip()
                if msg_text:
                    await room.broadcast({"event": "chat_message", "sender": username, "message": msg_text})
                    
    except WebSocketDisconnect:
        player.is_active = False
        await room.broadcast_user_list()
        
        # Soft disconnect cleanup sequence
        await asyncio.sleep(30.0)
        if not any(p.is_active for p in room.players.values()):
            if room.loop_task:
                room.loop_task.cancel()
            room.game_started = False
            room.game_over = False
            room.drawn_numbers.clear()
            room.available_numbers = list(range(1, 76))
            random.shuffle(room.available_numbers)
