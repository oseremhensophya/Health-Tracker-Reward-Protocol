# 🏃‍♂️ Health Tracker Reward Protocol

A Web3 fitness and wellness smart contract that incentivizes healthy habits through tokenized rewards and gamification.

## 🎯 Overview

The Health Tracker Reward Protocol connects real-world fitness data with blockchain rewards, encouraging consistent health habits through:

- 🏆 **Fitness Token Rewards** - Earn tokens for achieving health goals
- 🎖️ **Achievement NFT Badges** - Collectible badges for milestones
- 📊 **Oracle Integration** - Verified wearable device data
- 🏅 **Leaderboards & Streaks** - Competitive gamification
- 👥 **Team Challenges** - Collaborative fitness goals

## 🚀 Features

### Core Functionality
- **User Registration** - Create fitness profiles with streak tracking
- **Goal Creation** - Set custom fitness targets with token rewards
- **Activity Submission** - Oracle-verified fitness data from wearables
- **Reward Claims** - Mint tokens and NFTs for achievements
- **Team Formation** - Create and join fitness teams
- **Streak Tracking** - Daily activity consistency rewards

### Token Economics
- **Fitness Tokens (FT)** - Fungible rewards for goal completion
- **Achievement Badges (NFT)** - Unique milestone collectibles
- **Oracle Verification** - Prevents cheating via third-party data sources

## 📋 Usage Instructions

### For Users

#### 1. Register as a User
```clarity
(contract-call? .health-tracker-reward-protocol register-user)
```

#### 2. Join a Fitness Goal
```clarity
(contract-call? .health-tracker-reward-protocol join-goal u1)
```

#### 3. Claim Rewards
```clarity
(contract-call? .health-tracker-reward-protocol claim-goal-reward u1)
```

#### 4. Create a Team
```clarity
(contract-call? .health-tracker-reward-protocol create-team "Team Fitness")
```

### For Goal Creators

#### Create a Fitness Goal
```clarity
(contract-call? .health-tracker-reward-protocol create-fitness-goal 
  "daily-steps" 
  u10000     ; 10,000 steps target
  u100       ; 100 tokens reward
  u1008      ; 7 days duration (144 blocks/day)
)
```

### For Oracle Providers

#### Submit Activity Data
```clarity
(contract-call? .health-tracker-reward-protocol submit-activity-data 
  'SP1HTBVD3JG9C05J7HDJKDYR7QM4QJT9JZ0D0P9XJ  ; user
  u8500      ; steps
  u75        ; heart rate
  u300       ; calories
)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `register-user` | Register new user profile |
| `create-fitness-goal` | Create fitness challenge with rewards |
| `join-goal` | Join existing fitness goal |
| `submit-activity-data` | Submit verified fitness data (oracle only) |
| `claim-goal-reward` | Claim tokens for completed goals |
| `mint-achievement-badge` | Mint NFT badge (admin only) |
| `create-team` | Create fitness team |
| `join-team` | Join existing team |
| `add-oracle-provider` | Authorize oracle (admin only) |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-user-stats` | View user fitness statistics |
| `get-goal-details` | Get goal information |
| `get-user-goal-progress` | Check progress on specific goal |
| `get-daily-activity` | View daily activity data |
| `get-user-streak` | Check current fitness streak |
| `get-team-details` | View team information |
| `get-fitness-token-balance` | Check token balance |

## 🏗️ Contract Architecture

### Data Structures

- **Users**: Profile with steps, rewards, streaks, team membership
- **Fitness Goals**: Challenges with targets, rewards, and deadlines
- **User Progress**: Individual goal completion tracking
- **Daily Activity**: Verified fitness data from oracles
- **Teams**: Collaborative fitness groups
- **Streaks**: Consistency tracking for gamification

### Security Features

- ✅ Oracle authorization for data integrity
- ✅ Goal completion verification
- ✅ Reward claim protection against double-spending
- ✅ Team membership validation
- ✅ Admin-only functions for critical operations

## 🔗 Integration

### Wearable Device Support
The protocol supports integration with popular fitness wearables through authorized oracle providers:
- Fitbit
- Apple Watch
- Garmin
- Samsung Health
- Google Fit

### Oracle Requirements
Oracle providers must be authorized by contract admin and submit verified data including:
- Daily step counts
- Average heart rate
- Calories burned
- Activity verification status

## 🎮 Gamification Elements

### Streak System
- Daily activity tracking
- Streak bonuses for consistency
- Best streak records

### Leaderboards
- Weekly fitness rankings
- Monthly competitions
- Team vs team challenges

### Achievement System
- Milestone NFT badges
- Rare collectible rewards
- Progressive difficulty levels

## 🛠️ Development

### Prerequisites
- Clarinet CLI
- Node.js (for testing)

### Testing
```bash
npm install
npm test
```

### Deployment
```bash
clarinet check
clarinet deploy
```

## 📊 Smart Contract Stats

- **Lines of Code**: 360+
- **Functions**: 15+ public functions
- **Security Features**: Oracle verification, access controls
- **Token Types**: Fungible tokens + NFTs
- **Data Maps**: 10+ for comprehensive tracking

---

*Bringing fitness into the Web3 economy, one step at a time!* 🚀
