import asyncio
import json
import os
import random
import secrets
from typing import Dict, List, Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Multi-Room 6-Ticket 90-Ball Backend")

# Initialize global admin passphrase from environment or generate a secure token
ADMIN_PASSPHRASE = os.getenv("ADMIN_PASSPHRASE", secrets.token_hex(8))
print(f"[SECURITY INFO] Current Admin Passphrase: {ADMIN_PASSPHRASE}")

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.book = self.generate_six_ticket_book()

    def generate_six_ticket_book(self) -> List[List[List[int]]]:
        """Generates a complete book of 6 distinct 3x9 tickets (90-ball layout)."""
        book = [[[0 for _ in range(9)] for _ in range(3)] for _ in range(6)]
        
        for col in range(9):
            low = 1 if col == 0 else col * 10
            high = 9 if col == 0 else (89 if col == 7 else 90)
            
            pool = list(range(low, high + 1))
            random.shuffle(pool)
            
            while len(pool) < 18:
                pool.extend(random.sample(range(low, high + 1), min(18 - len(pool), (high - low + 1))))
            
            random.shuffle(pool)
            
            idx = 0
            for t in range(6):
                column_digits = pool[idx:idx+3]
                column_digits.sort()
                for row in range(3):
                    book[t][row][col] = column_digits[row]
                idx += 3

        for t in range(6):
            for row in range(3):
                clear_indices = random.sample(range(9), 4)
                for idx in clear_indices:
                    book[t][row][idx] = 0
                    
        return book

class BingoRoom:
    def __init__(self, room_id: str):
        self.room_id = room_id
        self.players: Dict[str, Player] = {}
        self.drawn_numbers: List[int] = []
        self.available_numbers: List[int] = list(range(1, 91))
        random.shuffle(self.available_numbers)
        self.game_started = False
        self.game_over = False
        self.is_paused = False
        self.loop_task: Optional[asyncio.Task] = None
        self.draw_interval = 4.0
        
        # Dynamic Room Rules & Pricing Configurations
        self.ticket_price = "Free"  # e.g., "Free", "$5.00", "100 Points"
        self.prizes = {
            "one_line": "$10.00",
            "two_lines": "$25.00",
            "full_house": "$100.00"
        }
        self.custom_notice = "1 Line = 5 marked, 2 Lines = 10 consecutive marked, Full House = 15 marked."

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
        await self.broadcast({"event": "game_started", "message": f"Match started in room {self.room_id}!"})
        
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(self.draw_interval)
            
            while self.is_paused and not self.game_over:
                await asyncio.sleep(1.0)

            if self.game_over:
                break

            num = self.available_numbers.pop()
            self.drawn_numbers.append(num)
            await self.broadcast({
                "event": "number_drawn",
                "number": num,
                "history": self.drawn_numbers
            })

    def verify_claim(self, player_book: List[List[List[int]]], claim_type: str) -> bool:
        drawn_set = set(self.drawn_numbers) | {0}

        for ticket in player_book:
            row_completed = [
                all(ticket[r][c] in drawn_set for c in range(9) if ticket[r][c] != 0)
                for r in range(3)
            ]

            if claim_type == "one_line" and any(row_completed):
                return True
            elif claim_type == "two_lines" and ((row_completed[0] and row_completed[1]) or (row_completed[1] and row_completed[2])):
                return True
            elif claim_type == "full_house" and all(row_completed):
                return True

        return False

# Global Room Registry
rooms: Dict[str, BingoRoom] = {
    "ROOM101": BingoRoom("ROOM101"),
    "VIP_LOUNGE": BingoRoom("VIP_LOUNGE")
}

@app.get("/")
def health_check():
    return {
        "status": "healthy",
        "active_rooms": list(rooms.keys()),
        "admin_auth_mode": "environment_variable"
    }

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str):
    global ADMIN_PASSPHRASE
    await websocket.accept()
    
    if room_id not in rooms:
        rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    
    if username == "SystemAdmin":
        player = None
    else:
        player = Player(username, websocket)
        room.players[username] = player
        
        await websocket.send_text(json.dumps({
            "event": "card_assigned",
            "book": player.book,
            "username": username,
            "room_id": room_id,
            "ticket_price": room.ticket_price,
            "prizes": room.prizes,
            "rules_notice": room.custom_notice
        }))
    
    await room.broadcast({
        "event": "player_joined",
        "username": username,
        "active_users": list(room.players.keys())
    })
    
    if len(room.players) >= 1 and not room.game_started:
        room.loop_task = asyncio.create_task(room.start_game_loop())

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            action = payload.get("action")
            provided_secret = payload.get("admin_secret")

            # --- ADVANCED ADMIN CONTROLS ---
            if provided_secret == ADMIN_PASSPHRASE:
                if action == "reset_passphrase":
                    new_pass = payload.get("new_passphrase", "").strip()
                    if new_pass:
                        ADMIN_PASSPHRASE = new_pass
                        await websocket.send_text(json.dumps({
                            "event": "admin_success",
                            "message": f"Passphrase updated successfully to: {ADMIN_PASSPHRASE}"
                        }))

                elif action == "create_room":
                    new_room_id = payload.get("new_room_id", "").strip().upper()
                    if new_room_id and new_room_id not in rooms:
                        rooms[new_room_id] = BingoRoom(new_room_id)
                        await websocket.send_text(json.dumps({
                            "event": "admin_success",
                            "message": f"Room '{new_room_id}' created successfully!"
                        }))

                elif action == "delete_room":
                    target_room_id = payload.get("target_room_id", "").strip().upper()
                    if target_room_id in rooms:
                        target_room = rooms[target_room_id]
                        await target_room.broadcast({
                            "event": "system_disconnect",
                            "message": f"Room '{target_room_id}' has been closed by the Admin."
                        })
                        if target_room.loop_task:
                            target_room.loop_task.cancel()
                        rooms.pop(target_room_id, None)
                        await websocket.send_text(json.dumps({
                            "event": "admin_success",
                            "message": f"Room '{target_room_id}' deleted."
                        }))

                elif action == "configure_rules_pricing":
                    room.ticket_price = payload.get("ticket_price", room.ticket_price)
                    room.prizes = payload.get("prizes", room.prizes)
                    room.custom_notice = payload.get("rules_notice", room.custom_notice)
                    
                    await room.broadcast({
                        "event": "rules_updated",
                        "ticket_price": room.ticket_price,
                        "prizes": room.prizes,
                        "rules_notice": room.custom_notice,
                        "message": f"📢 ROOM RULES UPDATED:\nPrice: {room.ticket_price}\nPrizes: {room.prizes}\nRules: {room.custom_notice}"
                    })

                elif action == "toggle_game_state":
                    cmd = payload.get("command")
                    if cmd == "pause":
                        room.is_paused = True
                        await room.broadcast({"event": "game_paused", "message": "⏸️ Game paused by Admin."})
                    elif cmd == "resume":
                        room.is_paused = False
                        await room.broadcast({"event": "game_resumed", "message": "▶️ Game resumed!"})

                elif action == "update_room_rules":
                    new_interval = payload.get("draw_interval", 4)
                    room.draw_interval = float(max(2, min(new_interval, 15)))
                    await room.broadcast({"event": "room_rules_changed", "message": f"Ball draw speed set to {room.draw_interval}s."})

            # --- STANDARD PLAYER ACTIONS ---
            if action == "claim_bingo" and username != "SystemAdmin" and not room.game_over:
                claim_type = payload.get("claim_type", "full_house")
                if room.verify_claim(player.book, claim_type):
                    if claim_type == "full_house":
                        room.game_over = True
                        await room.broadcast({"event": "game_over", "winner": username, "stage": "Full House"})
                    else:
                        await room.broadcast({"event": "stage_won", "winner": username, "claim_type": claim_type})
                else:
                    await websocket.send_text(json.dumps({"event": "invalid_claim", "message": f"Invalid {claim_type} claim!"}))

            elif action == "send_chat":
                msg_text = payload.get("message", "").strip()
                if msg_text:
                    import time
                    await room.broadcast({
                        "event": "chat_received",
                        "username": username,
                        "message": msg_text,
                        "timestamp": int(time.time() * 1000)
                    })

    except WebSocketDisconnect:
        if username in room.players:
            del room.players[username]
            
        await room.broadcast({
            "event": "player_left",
            "username": username,
            "active_users": list(room.players.keys())
        })
        
        if not room.players and username != "SystemAdmin" and room_id != "ROOM101":
            if room.loop_task:
                room.loop_task.cancel()
            rooms.pop(room_id, None)
