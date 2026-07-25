import asyncio
import json
import random
from typing import Dict, List, Set
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI(title="Authoritative Bingo Engine with Keep-Alive & Progressive Logic")

class Player:
    def __init__(self, username: str, auth_token: str, websocket: WebSocket):
        self.username = username
        self.auth_token = auth_token
        self.websocket = websocket
        self.book = self.generate_six_ticket_book()

    def generate_six_ticket_book(self) -> List[List[List[int]]]:
        """
        Generates a valid 6-ticket strip for 90-ball bingo.
        Every number 1-90 appears exactly once across the 6 tickets without duplicates.
        Column constraints:
          Col 0: 1-9    | Col 1: 10-19 | Col 2: 20-29
          Col 3: 30-39  | Col 4: 40-49 | Col 5: 50-59
          Col 6: 60-69  | Col 7: 70-79 | Col 8: 80-90
        """
        while True:
            try:
                book = [[[0 for _ in range(9)] for _ in range(3)] for _ in range(6)]
                col_pools = {}
                
                for c in range(9):
                    low = 1 if c == 0 else c * 10
                    high = 9 if c == 0 else (90 if c == 8 else c * 10 + 9)
                    pool = list(range(low, high + 1))
                    random.shuffle(pool)
                    col_pools[c] = pool

                for c in range(9):
                    pool = col_pools[c]
                    ticket_counts = [1] * 6
                    remaining = len(pool) - 6
                    for _ in range(remaining):
                        valid_tickets = [t for t in range(6) if ticket_counts[t] < 3]
                        ticket_counts[random.choice(valid_tickets)] += 1
                    
                    for t in range(6):
                        count = ticket_counts[t]
                        drawn = [pool.pop() for _ in range(count)]
                        drawn.sort()
                        rows = random.sample(range(3), count)
                        rows.sort()
                        for r_idx in range(count):
                            book[t][rows[r_idx]][c] = drawn[r_idx]

                valid = True
                for t in range(6):
                    for r in range(3):
                        non_zero = [c for c in range(9) if book[t][r][c] != 0]
                        if len(non_zero) != 5:
                            valid = False
                            break
                    if not valid:
                        break

                if valid:
                    return book
            except Exception:
                continue

class BingoRoom:
    def __init__(self, room_id: str):
        self.room_id = room_id
        self.players: Dict[str, Player] = {}
        self.drawn_numbers: List[int] = []
        self.available_numbers: List[int] = list(range(1, 91))
        random.shuffle(self.available_numbers)
        
        self.current_stage = "1_line"
        self.winners = {
            "1_line": None,
            "2_lines": None,
            "full_house": None
        }
        
        self.game_started = False
        self.game_over = False
        self.loop_task: asyncio.Task = None

    async def broadcast(self, message: dict):
        payload = json.dumps(message)
        disconnected = []
        for username, player in list(self.players.items()):
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
            "message": "Match started! Current Objective: 1 Line.",
            "stage": self.current_stage
        })
        
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
                "stage": self.current_stage
            })

    def evaluate_ticket_lines(self, ticket: List[List[int]], drawn_set: Set[int]) -> int:
        completed_lines = 0
        for r in range(3):
            row_vals = [ticket[r][c] for c in range(9) if ticket[r][c] != 0]
            if all(val in drawn_set for val in row_vals):
                completed_lines += 1
        return completed_lines

    def verify_claim(self, player_book: List[List[List[int]]], required_stage: str) -> bool:
        drawn_set = set(self.drawn_numbers)
        for ticket in player_book:
            lines = self.evaluate_ticket_lines(ticket, drawn_set)
            if required_stage == "1_line" and lines >= 1:
                return True
            elif required_stage == "2_lines" and lines >= 2:
                return True
            elif required_stage == "full_house" and lines == 3:
                return True
        return False

rooms: Dict[str, BingoRoom] = {}

@app.get("/")
def health_check():
    return {"status": "healthy", "engine": "Active"}

@app.websocket("/ws/{room_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, room_id: str, username: str, auth_token: str = "guest_token"):
    await websocket.accept()
    if room_id not in rooms:
        rooms[room_id] = BingoRoom(room_id)
    room = rooms[room_id]
    
    player = Player(username, auth_token, websocket)
    room.players[username] = player
    
    await websocket.send_text(json.dumps({
        "event": "card_assigned",
        "book": player.book,
        "username": username,
        "room_id": room_id,
        "stage": room.current_stage,
        "winners": room.winners,
        "total_players": len(room.players)
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

            if action == "ping":
                await websocket.send_text(json.dumps({
                    "event": "pong",
                    "total_players": len(room.players),
                    "stage": room.current_stage
                }))
                continue

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
                target_stage = room.current_stage
                is_valid = room.verify_claim(player.book, target_stage)
                
                if is_valid:
                    room.winners[target_stage] = username
                    if target_stage == "1_line":
                        room.current_stage = "2_lines"
                        await room.broadcast({
                            "event": "stage_won",
                            "stage_completed": "1_line",
                            "winner": username,
                            "next_stage": "2_lines",
                            "message": f"🎉 {username} won 1 LINE! Next Objective: 2 LINES!"
                        })
                    elif target_stage == "2_lines":
                        room.current_stage = "full_house"
                        await room.broadcast({
                            "event": "stage_won",
                            "stage_completed": "2_lines",
                            "winner": username,
                            "next_stage": "full_house",
                            "message": f"🎉 {username} won 2 LINES! Final Objective: FULL HOUSE!"
                        })
                    elif target_stage == "full_house":
                        room.game_over = True
                        await room.broadcast({
                            "event": "game_over",
                            "stage_completed": "full_house",
                            "winner": username,
                            "winners_summary": room.winners,
                            "message": f"🏆 FULL HOUSE claimed by {username}! Game Completed!"
                        })
                else:
                    await websocket.send_text(json.dumps({
                        "event": "invalid_claim",
                        "message": f"Invalid claim for current objective ({target_stage.replace('_', ' ').title()})."
                    }))

    except WebSocketDisconnect:
        if username in room.players:
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