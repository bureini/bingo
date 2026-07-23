import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Bingo Engine - Strictly Unique 1-90 Strip")

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.book = self.generate_six_ticket_book()

    def generate_six_ticket_book(self) -> List[List[List[int]]]:
        """
        Generates a complete 6-ticket strip containing all numbers 1-90.
        Guarantees zero duplicate numbers across the entire book.
        
        Column ranges:
          Col 0: 1-9   (9 numbers)
          Col 1: 10-19 (10 numbers)
          Col 2: 20-29 (10 numbers)
          Col 3: 30-39 (10 numbers)
          Col 4: 40-49 (10 numbers)
          Col 5: 50-59 (10 numbers)
          Col 6: 60-69 (10 numbers)
          Col 7: 70-79 (10 numbers)
          Col 8: 80-90 (11 numbers) -> range(80, 91)
        """
        while True:
            # 1. Prepare exact global number pools (Total: 90 unique numbers)
            col_pools = {
                0: list(range(1, 10)),      # 9 numbers (1 to 9)
                1: list(range(10, 20)),    # 10 numbers (10 to 19)
                2: list(range(20, 30)),    # 10 numbers (20 to 29)
                3: list(range(30, 40)),    # 10 numbers (30 to 39)
                4: list(range(40, 50)),    # 10 numbers (40 to 49)
                5: list(range(50, 60)),    # 10 numbers (50 to 59)
                6: list(range(60, 70)),    # 10 numbers (60 to 69)
                7: list(range(70, 80)),    # 10 numbers (70 to 79)
                8: list(range(80, 91)),    # 11 numbers (80 to 90 inclusive)
            }
            for c in range(9):
                random.shuffle(col_pools[c])

            # 2. Assign exact number counts per ticket for each column
            ticket_col_counts = [[0 for _ in range(9)] for _ in range(6)]
            
            for c in range(9):
                total_in_col = len(col_pools[c])
                counts = [1] * 6
                rem = total_in_col - 6
                indices = list(range(6))
                random.shuffle(indices)
                for i in range(rem):
                    counts[indices[i]] += 1
                for t in range(6):
                    ticket_col_counts[t][c] = counts[t]

            # Verify each ticket gets exactly 15 numbers total (5 per row)
            if any(sum(ticket_col_counts[t]) != 15 for t in range(6)):
                continue

            # 3. Build ticket grid matrices
            book = [[[0 for _ in range(9)] for _ in range(3)] for _ in range(6)]
            success = True

            for t in range(6):
                row_counts = [0, 0, 0]
                cols_by_count = list(range(9))
                cols_by_count.sort(key=lambda c: ticket_col_counts[t][c], reverse=True)

                for c in cols_by_count:
                    cnt = ticket_col_counts[t][c]
                    avail_rows = [r for r in range(3) if row_counts[r] < 5]
                    if len(avail_rows) < cnt:
                        success = False
                        break
                    
                    avail_rows.sort(key=lambda r: row_counts[r])
                    chosen_rows = avail_rows[:cnt]
                    
                    for r in chosen_rows:
                        val = col_pools[c].pop(0)
                        book[t][r][c] = val
                        row_counts[r] += 1
                
                if not success or any(rc != 5 for rc in row_counts):
                    success = False
                    break

            if not success:
                continue

            # 4. Sort column numbers vertically in ascending order per ticket
            for t in range(6):
                for c in range(9):
                    vals = [book[t][r][c] for r in range(3) if book[t][r][c] != 0]
                    vals.sort()
                    idx = 0
                    for r in range(3):
                        if book[t][r][c] != 0:
                            book[t][r][c] = vals[idx]
                            idx += 1

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
    return {"status": "healthy", "game": "90-Ball 100% Unique 6-Ticket Engine Active"}

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