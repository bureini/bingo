import asyncio
import json
import random
from typing import Dict, List, Set
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative 90-Ball Bingo Engine")

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.book = self.generate_six_ticket_book()

    def generate_six_ticket_book(self) -> List[List[List[int]]]:
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
        
        # Winning Stage Trackers
        self.current_stage = "5_numbers"  # Progression: '5_numbers' -> '10_numbers' -> 'full_house'
        self.stage_winners = {
            "5_numbers": None,
            "10_numbers": None,
            "full_house": None
        }

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
        await self.broadcast({"event": "game_started", "message": "The 90-Ball match has begun!"})
        
        while self.available_numbers and not self.game_over:
            await asyncio.sleep(4.0)
            if self.game_over:
                break
            num = self.available_numbers.pop()
            self.drawn_numbers.append(num)
            await self.broadcast({
                "event": "number_drawn",
                "number": num,
                "history": self.drawn_numbers,
                "current_stage": self.current_stage
            })

    def check_player_progress(self, player_book: List[List[List[int]]]) -> int:
        """
        Calculates the maximum marked numbers on any single ticket for the player.
        Returns total marked counts across rows/tickets.
        """
        drawn_set = set(self.drawn_numbers)
        max_ticket_count = 0
        
        for ticket in player_book:
            ticket_marked = 0
            for r in range(3):
                for c in range(9):
                    val = ticket[r][c]
                    if val != 0 and val in drawn_set:
                        ticket_marked += 1
            if ticket_marked > max_ticket_count:
                max_ticket_count = ticket_marked
        return max_ticket_count

    def verify_claim(self, player_book: List[List[List[int]]]) -> bool:
        max_marked = self.check_player_progress(player_book)
        if self.current_stage == "5_numbers" and max_marked >= 5:
            return True
        elif self.current_stage == "10_numbers" and max_marked >= 10:
            return True
        elif self.current_stage == "full_house" and max_marked >= 15:
            return True
        return False

rooms: Dict[str, BingoRoom] = {}

@app.get("/")
def health_check():
    return {"status": "healthy", "game": "Authoritative 90-Ball Engine"}

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
        "room_id": room_id,
        "current_stage": room.current_stage
    }))

    if len(room.players) >= 2 and not room.game_started:
        room.loop_task = asyncio.create_task(room.start_game_loop())

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            action = payload.get("action")

            if action == "claim_bingo" and not room.game_over:
                if room.verify_claim(player.book):
                    if room.current_stage == "5_numbers":
                        room.stage_winners["5_numbers"] = username
                        room.current_stage = "10_numbers"
                        await room.broadcast({
                            "event": "stage_won",
                            "stage": "5_numbers",
                            "winner": username,
                            "next_stage": "10_numbers"
                        })
                    elif room.current_stage == "10_numbers":
                        room.stage_winners["10_numbers"] = username
                        room.current_stage = "full_house"
                        await room.broadcast({
                            "event": "stage_won",
                            "stage": "10_numbers",
                            "winner": username,
                            "next_stage": "full_house"
                        })
                    elif room.current_stage == "full_house":
                        room.stage_winners["full_house"] = username
                        room.game_over = True
                        await room.broadcast({
                            "event": "game_over",
                            "winners": room.stage_winners
                        })
                else:
                    await websocket.send_text(json.dumps({
                        "event": "invalid_claim",
                        "message": f"Claim failed for current stage: {room.current_stage}"
                    }))
    except WebSocketDisconnect:
        if username in room.players:
            del room.players[username]
        if not room.players:
            if room.loop_task:
                room.loop_task.cancel()
            rooms.pop(room_id, None)