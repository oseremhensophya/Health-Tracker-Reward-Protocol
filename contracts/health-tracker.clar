;; Health Tracker Reward Protocol
;; A decentralized health tracking and reward system

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INVALID-ACTIVITY (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-ACHIEVEMENT-EXISTS (err u107))

;; Data Variables
(define-data-var next-user-id uint u1)
(define-data-var next-activity-id uint u1)
(define-data-var total-rewards-pool uint u1000000)

;; Data Maps
(define-map users principal 
  {
    user-id: uint,
    total-activities: uint,
    total-rewards-earned: uint,
    streak-days: uint,
    last-activity-date: uint,
    is-active: bool
  })

(define-map activities uint 
  {
    user: principal,
    activity-type: (string-ascii 20),
    duration-minutes: uint,
    calories-burned: uint,
    date: uint,
    reward-amount: uint,
    verified: bool
  })

(define-map activity-types (string-ascii 20) uint)
(define-map daily-activity principal uint)

(define-map achievements (string-ascii 30) 
  {
    title: (string-ascii 50),
    description: (string-ascii 100),
    reward-bonus: uint,
    requirement-type: (string-ascii 20),
    requirement-value: uint
  })

(define-map user-achievements 
  {user: principal, achievement-id: (string-ascii 30)} 
  {earned-at: uint, claimed: bool})

(define-map leaderboard-scores principal 
  {score: uint, rank: uint})

;; Initialize activity reward rates (per minute)
(map-set activity-types "walking" u2)
(map-set activity-types "running" u5)
(map-set activity-types "cycling" u4)
(map-set activity-types "swimming" u6)
(map-set activity-types "yoga" u3)
(map-set activity-types "weightlifting" u4)

(map-set achievements "first-activity" {title: "First Step", description: "Complete your first activity", reward-bonus: u100, requirement-type: "activity-count", requirement-value: u1})
(map-set achievements "streak-7" {title: "Week Warrior", description: "Maintain a 7-day streak", reward-bonus: u500, requirement-type: "streak", requirement-value: u7})
(map-set achievements "streak-30" {title: "Month Master", description: "Maintain a 30-day streak", reward-bonus: u2000, requirement-type: "streak", requirement-value: u30})
(map-set achievements "activity-100" {title: "Century Club", description: "Complete 100 activities", reward-bonus: u1500, requirement-type: "activity-count", requirement-value: u100})
(map-set achievements "rewards-10000" {title: "Reward Hunter", description: "Earn 10000 total rewards", reward-bonus: u1000, requirement-type: "total-rewards", requirement-value: u10000})

;; Public Functions

;; Register a new user
(define-public (register-user)
  (let 
    (
      (caller tx-sender)
      (user-id (var-get next-user-id))
    )
    (asserts! (is-none (map-get? users caller)) ERR-ALREADY-EXISTS)
    (map-set users caller {
      user-id: user-id,
      total-activities: u0,
      total-rewards-earned: u0,
      streak-days: u0,
      last-activity-date: u0,
      is-active: true
    })
    (var-set next-user-id (+ user-id u1))
    (ok user-id)
  )
)

;; Log a health activity
(define-public (log-activity (activity-type (string-ascii 20)) (duration-minutes uint) (calories-burned uint))
  (let 
    (
      (caller tx-sender)
      (activity-id (var-get next-activity-id))
      (current-block-height block-height)
      (reward-rate (default-to u0 (map-get? activity-types activity-type)))
      (base-reward (* reward-rate duration-minutes))
      (bonus-reward (calculate-bonus-reward caller current-block-height))
      (total-reward (+ base-reward bonus-reward))
    )
    (asserts! (> duration-minutes u0) ERR-INVALID-ACTIVITY)
    (asserts! (> reward-rate u0) ERR-INVALID-ACTIVITY)
    
    ;; Ensure user is registered
    (match (map-get? users caller)
      user-data 
      (begin
        ;; Create activity record
        (map-set activities activity-id {
          user: caller,
          activity-type: activity-type,
          duration-minutes: duration-minutes,
          calories-burned: calories-burned,
          date: current-block-height,
          reward-amount: total-reward,
          verified: true
        })
        
        ;; Update user stats
        (update-user-stats caller total-reward current-block-height)
        
        ;; Update daily activity
        (map-set daily-activity caller current-block-height)
        
        ;; Increment activity ID
        (var-set next-activity-id (+ activity-id u1))
        
        (ok {activity-id: activity-id, reward-earned: total-reward})
      )
      ERR-NOT-FOUND
    )
  )
)

;; Claim accumulated rewards
(define-public (claim-rewards)
  (let 
    (
      (caller tx-sender)
      (user-data (unwrap! (map-get? users caller) ERR-NOT-FOUND))
      (reward-amount (get total-rewards-earned user-data))
    )
    (asserts! (> reward-amount u0) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= (var-get total-rewards-pool) reward-amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Reset user rewards to zero
    (map-set users caller (merge user-data {total-rewards-earned: u0}))
    
    ;; Decrease total rewards pool
    (var-set total-rewards-pool (- (var-get total-rewards-pool) reward-amount))
    
    ;; Transfer would happen here in a full implementation with tokens
    (ok reward-amount)
  )
)

;; Add rewards to pool (owner only)
(define-public (add-to-rewards-pool (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (var-set total-rewards-pool (+ (var-get total-rewards-pool) amount))
    (ok (var-get total-rewards-pool))
  )
)

;; Update activity reward rate (owner only)
(define-public (update-activity-rate (activity-type (string-ascii 20)) (rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> rate u0) ERR-INVALID-AMOUNT)
    (map-set activity-types activity-type rate)
    (ok true)
  )
)

(define-public (create-achievement 
  (achievement-id (string-ascii 30)) 
  (title (string-ascii 50)) 
  (description (string-ascii 100)) 
  (reward-bonus uint) 
  (requirement-type (string-ascii 20)) 
  (requirement-value uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-none (map-get? achievements achievement-id)) ERR-ACHIEVEMENT-EXISTS)
    (map-set achievements achievement-id {
      title: title,
      description: description,
      reward-bonus: reward-bonus,
      requirement-type: requirement-type,
      requirement-value: requirement-value
    })
    (ok true)
  )
)

(define-public (claim-achievement-bonus (achievement-id (string-ascii 30)))
  (let 
    (
      (caller tx-sender)
      (achievement-key {user: caller, achievement-id: achievement-id})
      (user-achievement (unwrap! (map-get? user-achievements achievement-key) ERR-NOT-FOUND))
      (achievement-data (unwrap! (map-get? achievements achievement-id) ERR-NOT-FOUND))
      (bonus (get reward-bonus achievement-data))
    )
    (asserts! (not (get claimed user-achievement)) ERR-ALREADY-EXISTS)
    (map-set user-achievements achievement-key (merge user-achievement {claimed: true}))
    (match (map-get? users caller)
      user-data
      (begin
        (map-set users caller (merge user-data {
          total-rewards-earned: (+ (get total-rewards-earned user-data) bonus)
        }))
        (ok bonus)
      )
      ERR-NOT-FOUND
    )
  )
)

;; Private Functions

;; Calculate bonus reward based on streak and consistency
(define-private (calculate-bonus-reward (user principal) (current-date uint))
  (match (map-get? users user)
    user-data
    (let 
      (
        (last-date (get last-activity-date user-data))
        (current-streak (get streak-days user-data))
        (days-diff (if (> current-date last-date) (- current-date last-date) u0))
      )
      (if (and (> current-streak u6) (< days-diff u2))
        ;; Weekly streak bonus: 50% extra
        (/ (get total-rewards-earned user-data) u2)
        u0
      )
    )
    u0
  )
)

;; Update user statistics after activity
(define-private (update-user-stats (user principal) (reward-amount uint) (current-date uint))
  (match (map-get? users user)
    user-data
    (let 
      (
        (last-date (get last-activity-date user-data))
        (current-streak (get streak-days user-data))
        (new-streak 
          (if (and (> current-date last-date) (< (- current-date last-date) u2))
            (+ current-streak u1)
            u1
          )
        )
        (new-total-activities (+ (get total-activities user-data) u1))
        (new-total-rewards (+ (get total-rewards-earned user-data) reward-amount))
      )
      (map-set users user (merge user-data {
        total-activities: new-total-activities,
        total-rewards-earned: new-total-rewards,
        streak-days: new-streak,
        last-activity-date: current-date
      }))
      (update-leaderboard-score user new-total-rewards)
      (check-and-award-achievements user new-total-activities new-streak new-total-rewards current-date)
      true
    )
    false
  )
)

(define-private (update-leaderboard-score (user principal) (score uint))
  (begin
    (map-set leaderboard-scores user {score: score, rank: u0})
    true
  )
)

(define-private (check-and-award-achievements (user principal) (total-activities uint) (streak uint) (total-rewards uint) (current-date uint))
  (begin
    (if (is-eq total-activities u1)
      (award-achievement user "first-activity" current-date)
      true)
    (if (is-eq streak u7)
      (award-achievement user "streak-7" current-date)
      true)
    (if (is-eq streak u30)
      (award-achievement user "streak-30" current-date)
      true)
    (if (is-eq total-activities u100)
      (award-achievement user "activity-100" current-date)
      true)
    (if (is-eq total-rewards u10000)
      (award-achievement user "rewards-10000" current-date)
      true)
    true
  )
)

(define-private (award-achievement (user principal) (achievement-id (string-ascii 30)) (date uint))
  (let 
    (
      (achievement-key {user: user, achievement-id: achievement-id})
      (existing (map-get? user-achievements achievement-key))
    )
    (if (is-none existing)
      (begin
        (map-set user-achievements achievement-key {earned-at: date, claimed: false})
        true
      )
      true
    )
  )
)

;; Read-only functions

;; Get user information
(define-read-only (get-user-info (user principal))
  (map-get? users user)
)

;; Get activity details
(define-read-only (get-activity (activity-id uint))
  (map-get? activities activity-id)
)

;; Get activity reward rate
(define-read-only (get-activity-rate (activity-type (string-ascii 20)))
  (map-get? activity-types activity-type)
)

;; Get total rewards pool
(define-read-only (get-rewards-pool)
  (var-get total-rewards-pool)
)

;; Get user's claimable rewards
(define-read-only (get-claimable-rewards (user principal))
  (match (map-get? users user)
    user-data (some (get total-rewards-earned user-data))
    none
  )
)

;; Get user's activity count for today
(define-read-only (get-daily-activity-count (user principal))
  (match (map-get? daily-activity user)
    date (if (is-eq date block-height) (some u1) (some u0))
    (some u0)
  )
)

;; Calculate estimated reward for activity
(define-read-only (calculate-reward-estimate (activity-type (string-ascii 20)) (duration-minutes uint))
  (match (map-get? activity-types activity-type)
    rate (some (* rate duration-minutes))
    none
  )
)

(define-read-only (get-achievement (achievement-id (string-ascii 30)))
  (map-get? achievements achievement-id)
)

(define-read-only (get-user-achievement (user principal) (achievement-id (string-ascii 30)))
  (map-get? user-achievements {user: user, achievement-id: achievement-id})
)

(define-read-only (get-leaderboard-score (user principal))
  (map-get? leaderboard-scores user)
)

(define-read-only (has-achievement (user principal) (achievement-id (string-ascii 30)))
  (is-some (map-get? user-achievements {user: user, achievement-id: achievement-id}))
)
