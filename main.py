import asyncio
import json
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Bingo Engine with Claim Verification")

class Player:
    def __init__(self, username: str, websocket: WebSocket):
        self.username = username
        self.websocket = websocket
        self.book = self.generate_six_ticket_book()

    def generate_six_ticket_book(self) -> List[List[List[int]]]:
        """
        Generates a 6-ticket strip where all numbers 1-90 appear EXACTLY ONCE.
        Guarantees zero duplicate numbers across the entire 6-ticket book.
        """
        while True:
            col_pools = {
                0: list(range(1, 10)),      # 1-9
                1: list(range(10, 20)),    # 10-19
                2: list(range(20, 30)),    # 20-29
                3: list(range(30, 40)),    # 30-39
                4: list(range(40, 50)),    # 40-49
                5: list(range(50, 60)),    # 50-59
                6: list(range(60, 70)),    # 60-69
                7: list(range(70, 80)),    # 70-79
                8: list(range(80, 91)),    # 80-90 inclusive
            }
            for c in range(9):
                random.shuffle(col_pools[c])

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

            if any(sum(ticket_col_counts[t]) != 15 for t in range(6)):
                continue

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

    def verify_bingo(self, player_book: List[List[List[int]]]) -> (bool, str):
        """
        Verifies whether any ticket has achieved a 1 Line, 2 Lines, or Full House.
        Returns tuple: (is_valid, pattern_type)
        """
        drawn_set = set(self.drawn_numbers)
        
        for ticket in player_book:
            completed_rows = 0
            for r in range(3):
                row_nums = [ticket[r][c] for c in range(9) if ticket[r][c] != 0]
                if row_nums and all(num in drawn_set for num in row_nums):
                    completed_rows += 1
            
            if completed_rows == 3:
                return True, "Full House"
            elif completed_rows >= 1:
                return True, f"{completed_rows} Line(s)"
                
        return False, "None"

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
                is_valid, pattern = room.verify_bingo(player.book)
                if is_valid:
                    room.game_over = True
                    await room.broadcast({
                        "event": "game_over",
                        "winner": f"{username} ({pattern})"
                    })
                else:
                    await websocket.send_text(json.dumps({
                        "event": "invalid_claim",
                        "message": "No complete line or Full House matched your drawn numbers yet!"
                    }))
                    
    except WebSocketDisconnect:
        if username in room.players:
            del room.players[username]
        if not room.players:
            if room.loop_task:
                room.loop_task.cancel()
            rooms.pop(room_id, None)