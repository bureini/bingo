import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Bingo Engine with Unique 6-Ticket Distribution")

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.book = self.generate_six_ticket_book()

    def generate_six_ticket_book(self) -> List[List[List[int]]]:
        """
        Generates a complete book of 6 distinct 3x9 tickets according to strict standard 90-Ball UK rules.
        All numbers 1-90 appear EXACTLY ONCE across the 6-ticket strip (ZERO duplicates guaranteed).
        Column boundaries:
          Col 0: 1-9 (9 numbers)
          Col 1: 10-19 (10 numbers)
          Col 2: 20-29 (10 numbers)
          Col 3: 30-39 (10 numbers)
          Col 4: 40-49 (10 numbers)
          Col 5: 50-59 (10 numbers)
          Col 6: 60-69 (10 numbers)
          Col 7: 70-79 (10 numbers)
          Col 8: 80-90 (11 numbers)
        """
        # Step 1: Initialize empty 6-ticket book (6 tickets, 3 rows, 9 cols)
        book = [[[0 for _ in range(9)] for _ in range(3)] for _ in range(6)]

        # Define number pools for each column
        col_pools = {
            0: list(range(1, 10)),
            1: list(range(10, 20)),
            2: list(range(20, 30)),
            3: list(range(30, 40)),
            4: list(range(40, 50)),
            5: list(range(50, 60)),
            6: list(range(60, 70)),
            7: list(range(70, 80)),
            8: list(range(80, 91)),
        }

        # Shuffle each column's pool of unique numbers
        for c in range(9):
            random.shuffle(col_pools[c])

        # Distribute numbers to tickets ensuring valid column distribution
        for t in range(6):
            # Each ticket must have 15 numbers total (5 per row)
            # Ensure at least 1 number per column for this ticket, then distribute remaining
            pass

        # Robust standard distribution algorithm for 6-ticket UK strip:
        while True:
            book = [[[0 for _ in range(9)] for _ in range(3)] for _ in range(6)]
            pools = {c: list(col_pools[c]) for c in range(9)}
            
            # Count numbers per ticket in each column (must total 15 per ticket, 90 across all 6)
            ticket_col_counts = [[0 for _ in range(9)] for _ in range(6)]
            
            # Assign exact count distribution per column across 6 tickets
            for c in range(9):
                total_in_col = len(pools[c]) # 9, 10, or 11
                # Distribute total_in_col slots among 6 tickets (either 1, 2, or 3 per ticket)
                counts = [1] * 6
                remaining = total_in_col - 6
                for _ in range(remaining):
                    idx = random.randint(0, 5)
                    while counts[idx] >= 3:
                        idx = random.randint(0, 5)
                    counts[idx] += 1
                for t in range(6):
                    ticket_col_counts[t][c] = counts[t]

            # Verify each ticket gets exactly 15 numbers total
            valid_distribution = True
            for t in range(6):
                if sum(ticket_col_counts[t]) != 15:
                    valid_distribution = False
                    break
            if not valid_distribution:
                continue

            # Populate numbers into tickets
            for c in range(9):
                for t in range(6):
                    count = ticket_col_counts[t][c]
                    for _ in range(count):
                        val = pools[c].pop(0)
                        # Find an open row in ticket t for column c
                        placed = False
                        rows = [0, 1, 2]
                        random.shuffle(rows)
                        for r in rows:
                            if book[t][r][c] == 0:
                                book[t][r][c] = val
                                placed = True
                                break
            
            # Post-process: ensure every row has exactly 5 numbers (clear excess if needed or adjust)
            legal_book = True
            for t in range(6):
                # Row counts check
                for r in range(3):
                    row_nums = [c for c in range(9) if book[t][r][c] != 0]
                    if len(row_nums) != 5:
                        legal_book = False
                        break
                if not legal_book:
                    break

            if legal_book:
                # Sort numbers vertically within each ticket's column
                for t in range(6):
                    for c in range(9):
                        col_vals = [book[t][r][c] for r in range(3) if book[t][r][c] != 0]
                        col_vals.sort()
                        idx = 0
                        for r in range(3):
                            if book[t][r][c] != 0:
                                book[t][r][c] = col_vals[idx]
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
    return {"status": "healthy", "game": "90-Ball Unique 6-Ticket Engine Active"}

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