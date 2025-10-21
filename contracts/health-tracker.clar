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

;; Initialize activity reward rates (per minute)
(map-set activity-types "walking" u2)
(map-set activity-types "running" u5)
(map-set activity-types "cycling" u4)
(map-set activity-types "swimming" u6)
(map-set activity-types "yoga" u3)
(map-set activity-types "weightlifting" u4)

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
      )
      (map-set users user (merge user-data {
        total-activities: (+ (get total-activities user-data) u1),
        total-rewards-earned: (+ (get total-rewards-earned user-data) reward-amount),
        streak-days: new-streak,
        last-activity-date: current-date
      }))
      true
    )
    false
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
