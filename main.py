import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative 6-Ticket 90-Ball Backend")

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.book = self.generate_six_ticket_book()

    def generate_six_ticket_book(self) -> List[List[List[int]]]:
        """
        Generates a complete book of 6 distinct 3x9 tickets.
        Distributes all numbers from 1 to 90 across the 6 tickets without duplicates.
        """
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
        self.loop_task: asyncio.Task = None
        self.draw_interval = 4.0  # Dynamic control tempo variable

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
        await self.broadcast({"event": "game_started", "message": "The 6-Ticket match has begun!"})
        
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

    def verify_bingo(self, player_book: List[List[List[int]]]) -> bool:
        """Verifies if at least one of the 6 tickets has achieved a Full House."""
        drawn_set = set(self.drawn_numbers) | {0}
        
        for ticket in player_book:
            ticket_won = True
            for r in range(3):
                for c in range(9):
                    val = ticket[r][c]
                    if val != 0 and val not in drawn_set:
                        ticket_won = False
                        break
                if not ticket_won:
                    break
            if ticket_won:
                return True
        return False

rooms: Dict[str, BingoRoom] = {}

@app.get("/")
def health_check():
    return {"status": "healthy", "game": "90-Ball 6-Ticket Engine Active"}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str):
    await websocket.accept()
    if room_id not in rooms:
        rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    
    # Authoritative Reconnection Resolution Logic
    if username in room.players and username != "SystemAdmin":
        try:
            await room.players[username].websocket.send_text(json.dumps({
                "event": "system_disconnect",
                "message": "You connected from another tab/device. Closing this session."
            }))
            await room.players[username].websocket.close(code=4000)
        except Exception:
            pass
    
    # Initialization Matrix Routing
    if username == "SystemAdmin":
        player = None
    else:
        player = Player(username, websocket)
        room.players[username] = player
        
        await websocket.send_text(json.dumps({
            "event": "card_assigned",
            "book": player.book,
            "username": username,
            "room_id": room_id
        }))
    
    # Synchronized State & Presence Updates
    await room.broadcast({
        "event": "player_joined",
        "username": username,
        "active_users": list(room.players.keys())
    })
    
    if len(room.players) >= 2 and not room.game_started:
        room.loop_task = asyncio.create_task(room.start_game_loop())

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            action = payload.get("action")
            
            if action == "claim_bingo" and username != "SystemAdmin" and not room.game_over:
                if room.verify_bingo(player.book):
                    room.game_over = True
                    await room.broadcast({
                        "event": "game_over",
                        "winner": username
                    })
                else:
                    await websocket.send_text(json.dumps({
                        "event": "invalid_claim",
                        "message": "No Full House found on any of your tickets yet!"
                    }))
                    
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
                    
            elif action == "update_room_rules":
                if payload.get("admin_secret") == "BingoAdmin2026":
                    new_interval = payload.get("draw_interval", 4)
                    room.draw_interval = float(max(2, min(new_interval, 15)))
                    await room.broadcast({
                        "event": "room_rules_changed",
                        "message": f"Admin updated ball drawing interval to {room.draw_interval} seconds."
                    })
                    
    except WebSocketDisconnect:
        if username in room.players:
            del room.players[username]
            
        await room.broadcast({
            "event": "player_left",
            "username": username,
            "active_users": list(room.players.keys())
        })
        
        if not room.players:
            if room.loop_task:
                room.loop_task.cancel()
            rooms.pop(room_id, None)
