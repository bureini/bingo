import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Bingo Engine with Chat & Announcement Support")

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
            await asyncio.sleep(4.0)
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
    return {"status": "healthy", "game": "90-Ball 6-Ticket Engine Active with Chat Relay"}

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
        "book": player.book,
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
            
            # --- CHAT & BROADCAST HANDLERS ---
            if action == "send_chat":
                chat_msg = payload.get("message", "").strip()
                if chat_msg:
                    await room.broadcast({
                        "event": "chat_message",
                        "sender": username,
                        "message": chat_msg,
                        "is_admin": username in ["SystemAdmin", "MasterAdmin"]
                    })

            elif action == "system_announcement":
                announcement = payload.get("message", "").strip()
                if announcement:
                    await room.broadcast({
                        "event": "system_announcement",
                        "message": announcement,
                        "sender": "System Admin"
                    })

            elif action == "claim_bingo" and not room.game_over:
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
                    
    except WebSocketDisconnect:
        if username in room.players:
            del room.players[username]
        if not room.players:
            if room.loop_task:
                room.loop_task.cancel()
            rooms.pop(room_id, None)
