# SurvivorProtocol Smart Contract

A Clarity smart contract for elimination-style fantasy games on the Stacks blockchain. Players make weekly picks, and one wrong choice eliminates them from the game. The last survivor takes the entire prize pool.

## 🎯 Overview

SurvivorProtocol creates winner-takes-all elimination games where:
- Players pay an entry fee to join
- Each week, players submit picks before a deadline
- Wrong picks or missed deadlines eliminate players immediately  
- The last remaining player wins the entire pool (minus protocol fee)
- If no survivors remain, entry fees are refunded

## 🚀 Features

### Core Functionality
- **Game Creation**: Anyone can create games with custom entry fees
- **Flexible Participation**: Players join by paying the entry fee
- **Deadline Management**: Strict enforcement of weekly pick deadlines
- **Automatic Elimination**: Wrong picks instantly eliminate players
- **Winner-Takes-All**: Last survivor gets the entire prize pool
- **Emergency Controls**: Contract owner can cancel games if needed

### Security & Transparency  
- **Immutable Results**: Pick results cannot be changed once set
- **Access Controls**: Only game creators can manage their games
- **Audit Trail**: Complete history of all picks and eliminations
- **Protocol Fee**: Configurable fee (default 2.5%) for sustainability

## 📋 Contract Interface

### Public Functions

#### Game Management
```clarity
(create-game (entry-fee uint))
;; Creates a new elimination game
;; Returns: Game ID

(join-game (game-id uint))  
;; Join an existing game by paying entry fee
;; Requires: Game must be in CREATED status

(start-game (game-id uint) (week-1-deadline uint))
;; Start a game and set first week deadline
;; Requires: Must be game creator, >1 participants
```

#### Gameplay
```clarity
(submit-pick (game-id uint) (week uint) (pick uint))
;; Submit your pick for the current week
;; Requires: Game active, before deadline, not eliminated

(set-weekly-result (game-id uint) (week uint) (winning-pick uint) (next-week-deadline (optional uint)))
;; Set the winning pick and process eliminations
;; Requires: Must be game creator
;; Automatically eliminates players with wrong picks
```

#### Administrative
```clarity
(set-protocol-fee-rate (new-rate uint))
;; Update protocol fee (max 10%)
;; Requires: Contract owner only

(emergency-cancel-game (game-id uint))
;; Cancel game and refund all participants  
;; Requires: Contract owner only
```

### Read-Only Functions

```clarity
(get-game (game-id uint))
;; Get complete game information

(get-participant-info (game-id uint) (participant principal))  
;; Get participant status and pick history

(get-weekly-pick (game-id uint) (week uint) (participant principal))
;; Get specific weekly pick

(get-weekly-result (game-id uint) (week uint))
;; Get weekly winning result

(is-participant-alive (game-id uint) (participant principal))
;; Check if participant is still in the game
```

## 🎮 How to Play

### 1. Create or Join a Game
```clarity
;; Create a game with 1000 microSTX entry fee
(contract-call? .survivor-protocol create-game u1000000)

;; Join an existing game
(contract-call? .survivor-protocol join-game u1)
```

### 2. Game Creator Starts the Game
```clarity
;; Start game with deadline at block 150000
(contract-call? .survivor-protocol start-game u1 u150000)
```

### 3. Submit Weekly Picks
```clarity
;; Submit pick "5" for week 1 of game 1
(contract-call? .survivor-protocol submit-pick u1 u1 u5)
```

### 4. Game Creator Sets Results
```clarity
;; Set winning pick and next deadline
(contract-call? .survivor-protocol set-weekly-result u1 u1 u5 (some u160000))
```

### 5. Game Continues Until One Survivor
- Players with wrong picks are automatically eliminated
- Game continues weekly until ≤1 survivor remains
- Winner receives entire pool minus protocol fee

## 💰 Economics

### Entry Fees
- Set by game creator when creating game
- Collected upfront when players join
- Forms the total prize pool

### Protocol Fee
- Default: 2.5% of total pool
- Configurable by contract owner (max 10%)
- Paid to contract owner upon game completion

### Payouts
- **Single Winner**: Gets entire pool minus protocol fee
- **No Survivors**: All entry fees refunded proportionally
- **Emergency Cancel**: Full refunds to all participants

## 🔒 Security Features

### Access Controls
- Only game creators can start games and set results
- Only contract owner can adjust fees and cancel games
- Participants can only submit picks for themselves

### Validation & Safety
- Strict deadline enforcement prevents late picks
- Immutable elimination status once set
- Input validation on all parameters
- Comprehensive error codes for debugging

### Emergency Mechanisms  
- Contract owner can cancel problematic games
- Automatic refunds if no clear winner emerges
- Protocol fee limits prevent excessive fees

## 📊 Game States

```clarity
STATUS-CREATED  (u0)  ;; Accepting players
STATUS-ACTIVE   (u1)  ;; Game in progress  
STATUS-COMPLETED(u2)  ;; Game finished
```

## ⚠️ Current Limitations

### Participant Tracking
- Current version uses simplified participant management
- Production deployment needs robust participant enumeration
- Consider maintaining participant lists for complex elimination logic

### Elimination Processing
- Simplified elimination logic in current version
- Full implementation should process all participants systematically
- Consider gas optimization for large participant pools

### Refund Mechanisms
- Basic refund structure implemented
- Production version needs comprehensive participant refund logic

## 🚀 Deployment

### Prerequisites
- Stacks blockchain node access
- Clarity CLI for compilation and deployment
- STX tokens for deployment costs

### Compilation
```bash
clarity-cli check contracts/SurvivorProtocol.clar
```

### Deployment
```bash
clarity-cli deploy contracts/SurvivorProtocol.clar --testnet
```

## 🔧 Development Notes

### Gas Considerations
- Pick submissions are low-cost operations
- Elimination processing may require gas optimization for large games
- Consider batch processing for games with many participants

### Upgrade Path
- Current contract is immutable once deployed
- Consider proxy patterns for upgradeable versions
- Plan migration strategies for contract improvements

### Integration
- Easy integration with frontend applications
- RESTful API compatible through Stacks node
- Event-driven architecture for real-time updates

## 📈 Future Enhancements

### Advanced Features
- Multi-pick formats (confidence points, spreads)
- Seasonal/tournament brackets
- Team-based elimination games
- Custom elimination rules per game

### Scalability  
- Participant list management optimization
- Batch elimination processing
- Off-chain computation with on-chain verification

### User Experience
- Automatic deadline reminders
- Pick history and statistics
- Leaderboards and achievements
- Social features and messaging

## 📄 License

This smart contract is provided as-is for educational and development purposes. Use at your own risk in production environments.

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Robust participant management
- Gas optimization
- Additional game formats
- Enhanced security features
- Comprehensive testing suite