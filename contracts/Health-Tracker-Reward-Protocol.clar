;; Health Tracker Reward Protocol

(define-fungible-token fitness-token)

(define-non-fungible-token achievement-badge uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_USER_NOT_FOUND (err u101))
(define-constant ERR_INVALID_GOAL (err u102))
(define-constant ERR_GOAL_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_CLAIMED (err u104))
(define-constant ERR_GOAL_NOT_MET (err u105))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u106))
(define-constant ERR_INVALID_DATA (err u107))
(define-constant ERR_STREAK_NOT_FOUND (err u108))
(define-constant ERR_TEAM_NOT_FOUND (err u109))
(define-constant ERR_ALREADY_IN_TEAM (err u110))
(define-constant ERR_MILESTONE_NOT_FOUND (err u111))
(define-constant ERR_MILESTONE_ALREADY_CLAIMED (err u112))

(define-data-var next-goal-id uint u1)
(define-data-var next-badge-id uint u1)
(define-data-var next-team-id uint u1)
(define-data-var total-fitness-tokens uint u0)
(define-data-var next-milestone-id uint u1)

(define-map users principal {
    total-steps: uint,
    total-rewards: uint,
    current-streak: uint,
    best-streak: uint,
    team-id: (optional uint),
    last-activity: uint
})

(define-map fitness-goals uint {
    creator: principal,
    goal-type: (string-ascii 20),
    target-value: uint,
    reward-amount: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool,
    participants: uint
})

(define-map user-goal-progress {user: principal, goal-id: uint} {
    current-value: uint,
    is-completed: bool,
    claimed: bool,
    completion-block: (optional uint)
})

(define-map oracle-providers principal bool)

(define-map daily-activity principal {
    date: uint,
    steps: uint,
    heart-rate-avg: uint,
    calories-burned: uint,
    verified: bool
})

(define-map user-streaks principal {
    current-streak: uint,
    streak-start: uint,
    last-activity: uint
})

(define-map teams uint {
    name: (string-ascii 50),
    creator: principal,
    members: (list 20 principal),
    total-points: uint,
    created-at: uint
})

(define-map leaderboard-weekly principal uint)
(define-map leaderboard-monthly principal uint)

(define-map milestones uint {
    name: (string-ascii 50),
    description: (string-ascii 200),
    threshold: uint,
    reward-amount: uint,
    milestone-type: (string-ascii 20),
    is-active: bool
})

(define-map user-milestones {user: principal, milestone-id: uint} {
    achieved: bool,
    claimed: bool,
    achievement-block: (optional uint)
})

(define-public (register-user)
    (let ((user tx-sender))
        (map-set users user {
            total-steps: u0,
            total-rewards: u0,
            current-streak: u0,
            best-streak: u0,
            team-id: none,
            last-activity: stacks-block-height
        })
        (ok true)
    )
)

(define-public (create-fitness-goal (goal-type (string-ascii 20)) (target-value uint) (reward-amount uint) (duration uint))
    (let (
        (goal-id (var-get next-goal-id))
        (start-block stacks-block-height)
        (end-block (+ start-block duration))
    )
        (asserts! (> target-value u0) ERR_INVALID_GOAL)
        (asserts! (> reward-amount u0) ERR_INVALID_GOAL)
        (asserts! (> duration u0) ERR_INVALID_GOAL)
        
        (map-set fitness-goals goal-id {
            creator: tx-sender,
            goal-type: goal-type,
            target-value: target-value,
            reward-amount: reward-amount,
            start-block: start-block,
            end-block: end-block,
            is-active: true,
            participants: u0
        })
        
        (var-set next-goal-id (+ goal-id u1))
        (ok goal-id)
    )
)

(define-public (join-goal (goal-id uint))
    (let (
        (goal (unwrap! (map-get? fitness-goals goal-id) ERR_GOAL_NOT_FOUND))
        (user tx-sender)
    )
        (asserts! (get is-active goal) ERR_INVALID_GOAL)
        (asserts! (< stacks-block-height (get end-block goal)) ERR_INVALID_GOAL)
        
        (map-set user-goal-progress {user: user, goal-id: goal-id} {
            current-value: u0,
            is-completed: false,
            claimed: false,
            completion-block: none
        })
        
        (map-set fitness-goals goal-id (merge goal {participants: (+ (get participants goal) u1)}))
        (ok true)
    )
)

(define-public (submit-activity-data (user principal) (steps uint) (heart-rate uint) (calories uint))
    (begin
        (asserts! (default-to false (map-get? oracle-providers tx-sender)) ERR_ORACLE_NOT_AUTHORIZED)
        (asserts! (is-some (map-get? users user)) ERR_USER_NOT_FOUND)
        
        (let (
            (current-date (/ stacks-block-height u144))
            (user-data (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
        )
            (begin
                (map-set daily-activity user {
                    date: current-date,
                    steps: steps,
                    heart-rate-avg: heart-rate,
                    calories-burned: calories,
                    verified: true
                })
                
                (map-set users user (merge user-data {
                    total-steps: (+ (get total-steps user-data) steps),
                    last-activity: stacks-block-height
                }))
                

                (ok true)
            )
        )
    )
)

(define-public (claim-goal-reward (goal-id uint))
    (let (
        (user tx-sender)
        (goal (unwrap! (map-get? fitness-goals goal-id) ERR_GOAL_NOT_FOUND))
        (progress (unwrap! (map-get? user-goal-progress {user: user, goal-id: goal-id}) ERR_GOAL_NOT_FOUND))
    )
        (asserts! (get is-completed progress) ERR_GOAL_NOT_MET)
        (asserts! (not (get claimed progress)) ERR_ALREADY_CLAIMED)
        
        (map-set user-goal-progress {user: user, goal-id: goal-id} 
            (merge progress {claimed: true}))
        
        (try! (ft-mint? fitness-token (get reward-amount goal) user))
        (var-set total-fitness-tokens (+ (var-get total-fitness-tokens) (get reward-amount goal)))
        
        (let ((user-data (unwrap! (map-get? users user) ERR_USER_NOT_FOUND)))
            (map-set users user (merge user-data {
                total-rewards: (+ (get total-rewards user-data) (get reward-amount goal))
            }))
        )
        
        (ok (get reward-amount goal))
    )
)

(define-public (mint-achievement-badge (user principal) (achievement-type (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (let ((badge-id (var-get next-badge-id)))
            (try! (nft-mint? achievement-badge badge-id user))
            (var-set next-badge-id (+ badge-id u1))
            (ok badge-id)
        )
    )
)

(define-public (create-team (team-name (string-ascii 50)))
    (let (
        (team-id (var-get next-team-id))
        (creator tx-sender)
    )
        (map-set teams team-id {
            name: team-name,
            creator: creator,
            members: (list creator),
            total-points: u0,
            created-at: stacks-block-height
        })
        
        (let ((user-data (unwrap! (map-get? users creator) ERR_USER_NOT_FOUND)))
            (map-set users creator (merge user-data {team-id: (some team-id)}))
        )
        
        (var-set next-team-id (+ team-id u1))
        (ok team-id)
    )
)

(define-public (join-team (team-id uint))
    (let (
        (user tx-sender)
        (team (unwrap! (map-get? teams team-id) ERR_TEAM_NOT_FOUND))
        (user-data (unwrap! (map-get? users user) ERR_USER_NOT_FOUND))
    )
        (asserts! (is-none (get team-id user-data)) ERR_ALREADY_IN_TEAM)
        (asserts! (< (len (get members team)) u20) ERR_INVALID_DATA)
        
        (map-set teams team-id (merge team {
            members: (unwrap! (as-max-len? (append (get members team) user) u20) ERR_INVALID_DATA)
        }))
        
        (map-set users user (merge user-data {team-id: (some team-id)}))
        (ok true)
    )
)

(define-public (add-oracle-provider (oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set oracle-providers oracle true)
        (ok true)
    )
)

(define-public (remove-oracle-provider (oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-delete oracle-providers oracle)
        (ok true)
    )
)

(define-public (create-milestone (name (string-ascii 50)) (description (string-ascii 200)) (threshold uint) (reward-amount uint) (milestone-type (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> threshold u0) ERR_INVALID_DATA)
        (asserts! (> reward-amount u0) ERR_INVALID_DATA)
        
        (let ((milestone-id (var-get next-milestone-id)))
            (map-set milestones milestone-id {
                name: name,
                description: description,
                threshold: threshold,
                reward-amount: reward-amount,
                milestone-type: milestone-type,
                is-active: true
            })
            (var-set next-milestone-id (+ milestone-id u1))
            (ok milestone-id)
        )
    )
)

(define-public (check-and-update-milestones (user principal))
    (let ((user-data (unwrap! (map-get? users user) ERR_USER_NOT_FOUND)))
        (begin
            (unwrap-panic (check-milestone user u1 (get total-steps user-data) "steps"))
            (unwrap-panic (check-milestone user u2 (get total-rewards user-data) "rewards"))
            (unwrap-panic (check-milestone user u3 (get best-streak user-data) "streak"))
            (ok true)
        )
    )
)

(define-public (claim-milestone-reward (milestone-id uint))
    (let (
        (user tx-sender)
        (milestone (unwrap! (map-get? milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
        (user-milestone (default-to {achieved: false, claimed: false, achievement-block: none}
                        (map-get? user-milestones {user: user, milestone-id: milestone-id})))
    )
        (asserts! (get is-active milestone) ERR_MILESTONE_NOT_FOUND)
        (asserts! (get achieved user-milestone) ERR_GOAL_NOT_MET)
        (asserts! (not (get claimed user-milestone)) ERR_MILESTONE_ALREADY_CLAIMED)
        
        (map-set user-milestones {user: user, milestone-id: milestone-id}
            (merge user-milestone {claimed: true}))
        
        (try! (ft-mint? fitness-token (get reward-amount milestone) user))
        (var-set total-fitness-tokens (+ (var-get total-fitness-tokens) (get reward-amount milestone)))
        
        (let ((user-data (unwrap! (map-get? users user) ERR_USER_NOT_FOUND)))
            (map-set users user (merge user-data {
                total-rewards: (+ (get total-rewards user-data) (get reward-amount milestone))
            }))
        )
        
        (ok (get reward-amount milestone))
    )
)

(define-private (update-streak (user principal))
    (let (
        (current-block stacks-block-height)
        (user-streak (default-to {current-streak: u0, streak-start: current-block, last-activity: u0} 
                     (map-get? user-streaks user)))
        (last-activity (get last-activity user-streak))
        (blocks-per-day u144)
    )
        (if (<= (- current-block last-activity) blocks-per-day)
            (map-set user-streaks user (merge user-streak {
                current-streak: (+ (get current-streak user-streak) u1),
                last-activity: current-block
            }))
            (map-set user-streaks user {
                current-streak: u1,
                streak-start: current-block,
                last-activity: current-block
            })
        )
        (ok true)
    )
)

(define-private (update-goal-progress (user principal) (steps uint))
    (ok steps)
)

(define-private (check-milestone (user principal) (milestone-id uint) (current-value uint) (milestone-type (string-ascii 20)))
    (match (map-get? milestones milestone-id)
        milestone
        (if (and 
                (is-eq (get milestone-type milestone) milestone-type)
                (>= current-value (get threshold milestone))
                (get is-active milestone))
            (let ((user-milestone (default-to {achieved: false, claimed: false, achievement-block: none}
                                  (map-get? user-milestones {user: user, milestone-id: milestone-id}))))
                (if (not (get achieved user-milestone))
                    (map-set user-milestones {user: user, milestone-id: milestone-id}
                        (merge user-milestone {
                            achieved: true,
                            achievement-block: (some stacks-block-height)
                        }))
                    true
                )
                (ok true)
            )
            (ok false)
        )
        (ok false)
    )
)

(define-read-only (get-user-stats (user principal))
    (map-get? users user)
)

(define-read-only (get-goal-details (goal-id uint))
    (map-get? fitness-goals goal-id)
)

(define-read-only (get-user-goal-progress (user principal) (goal-id uint))
    (map-get? user-goal-progress {user: user, goal-id: goal-id})
)

(define-read-only (get-daily-activity (user principal))
    (map-get? daily-activity user)
)

(define-read-only (get-user-streak (user principal))
    (map-get? user-streaks user)
)

(define-read-only (get-team-details (team-id uint))
    (map-get? teams team-id)
)

(define-read-only (get-fitness-token-balance (user principal))
    (ft-get-balance fitness-token user)
)

(define-read-only (get-total-fitness-tokens)
    (var-get total-fitness-tokens)
)

(define-read-only (is-oracle-authorized (oracle principal))
    (default-to false (map-get? oracle-providers oracle))
)

(define-read-only (get-milestone-details (milestone-id uint))
    (map-get? milestones milestone-id)
)

(define-read-only (get-user-milestone-progress (user principal) (milestone-id uint))
    (map-get? user-milestones {user: user, milestone-id: milestone-id})
)

(define-read-only (get-next-milestone-id)
    (var-get next-milestone-id)
)
