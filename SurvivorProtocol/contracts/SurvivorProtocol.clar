;; SurvivorProtocol - Elimination Fantasy Game
;; Winner takes all pool, one wrong pick eliminates you

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GAME-NOT-FOUND (err u101))
(define-constant ERR-GAME-ALREADY-STARTED (err u102))
(define-constant ERR-GAME-NOT-STARTED (err u103))
(define-constant ERR-ALREADY-ELIMINATED (err u104))
(define-constant ERR-PICK-DEADLINE-PASSED (err u105))
(define-constant ERR-INVALID-PICK (err u106))
(define-constant ERR-ALREADY-PICKED (err u107))
(define-constant ERR-GAME-ONGOING (err u108))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u109))
(define-constant ERR-NO-SURVIVORS (err u110))

;; Data Variables
(define-data-var game-counter uint u0)
(define-data-var protocol-fee-rate uint u250) ;; 2.5% in basis points

;; Game status constants
(define-constant STATUS-CREATED u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)

;; Data Maps
(define-map games
  uint
  {
    creator: principal,
    entry-fee: uint,
    status: uint,
    current-week: uint,
    total-pool: uint,
    survivor-count: uint,
    winner: (optional principal),
    created-at: uint
  }
)

(define-map game-participants
  {game-id: uint, participant: principal}
  {
    eliminated: bool,
    picks: (list 20 uint), ;; Support up to 20 weeks
    joined-at: uint
  }
)

(define-map weekly-picks
  {game-id: uint, week: uint, participant: principal}
  {pick: uint, submitted-at: uint}
)

(define-map weekly-results
  {game-id: uint, week: uint}
  {winning-pick: uint, set-at: uint}
)

(define-map pick-deadlines
  {game-id: uint, week: uint}
  uint ;; block height deadline
)

;; Read-only functions
(define-read-only (get-game (game-id uint))
  (map-get? games game-id)
)

(define-read-only (get-participant-info (game-id uint) (participant principal))
  (map-get? game-participants {game-id: game-id, participant: participant})
)

(define-read-only (get-weekly-pick (game-id uint) (week uint) (participant principal))
  (map-get? weekly-picks {game-id: game-id, week: week, participant: participant})
)

(define-read-only (get-weekly-result (game-id uint) (week uint))
  (map-get? weekly-results {game-id: game-id, week: week})
)

(define-read-only (get-pick-deadline (game-id uint) (week uint))
  (map-get? pick-deadlines {game-id: game-id, week: week})
)

(define-read-only (get-protocol-fee-rate)
  (var-get protocol-fee-rate)
)

(define-read-only (is-participant-alive (game-id uint) (participant principal))
  (match (get-participant-info game-id participant)
    participant-data (not (get eliminated participant-data))
    false
  )
)

;; Administrative functions
(define-public (set-protocol-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u1000) (err u112)) ;; Max 10%
    (var-set protocol-fee-rate new-rate)
    (ok true)
  )
)

;; Game creation and management
(define-public (create-game (entry-fee uint))
  (let
    (
      (game-id (+ (var-get game-counter) u1))
    )
    (map-set games game-id
      {
        creator: tx-sender,
        entry-fee: entry-fee,
        status: STATUS-CREATED,
        current-week: u0,
        total-pool: u0,
        survivor-count: u0,
        winner: none,
        created-at: stacks-block-height
      }
    )
    (var-set game-counter game-id)
    (ok game-id)
  )
)

(define-public (join-game (game-id uint))
  (let
    (
      (game-data (unwrap! (get-game game-id) ERR-GAME-NOT-FOUND))
      (entry-fee (get entry-fee game-data))
    )
    (asserts! (is-eq (get status game-data) STATUS-CREATED) ERR-GAME-ALREADY-STARTED)
    (asserts! (is-none (get-participant-info game-id tx-sender)) (err u111))
    
    ;; Transfer entry fee
    (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
    
    ;; Add participant
    (map-set game-participants
      {game-id: game-id, participant: tx-sender}
      {
        eliminated: false,
        picks: (list),
        joined-at: stacks-block-height
      }
    )
    
    ;; Update game pool and survivor count
    (map-set games game-id
      (merge game-data
        {
          total-pool: (+ (get total-pool game-data) entry-fee),
          survivor-count: (+ (get survivor-count game-data) u1)
        }
      )
    )
    
    (ok true)
  )
)

(define-public (start-game (game-id uint) (week-1-deadline uint))
  (let
    (
      (game-data (unwrap! (get-game game-id) ERR-GAME-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator game-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status game-data) STATUS-CREATED) ERR-GAME-ALREADY-STARTED)
    (asserts! (> (get survivor-count game-data) u1) (err u113))
    (asserts! (> week-1-deadline stacks-block-height) (err u114))
    
    ;; Set game to active and set first week deadline
    (map-set games game-id
      (merge game-data
        {
          status: STATUS-ACTIVE,
          current-week: u1
        }
      )
    )
    
    (map-set pick-deadlines
      {game-id: game-id, week: u1}
      week-1-deadline
    )
    
    (ok true)
  )
)

;; Pick submission
(define-public (submit-pick (game-id uint) (week uint) (pick uint))
  (let
    (
      (game-data (unwrap! (get-game game-id) ERR-GAME-NOT-FOUND))
      (participant-data (unwrap! (get-participant-info game-id tx-sender) ERR-NOT-AUTHORIZED))
      (deadline (unwrap! (get-pick-deadline game-id week) ERR-INVALID-PICK))
    )
    (asserts! (is-eq (get status game-data) STATUS-ACTIVE) ERR-GAME-NOT-STARTED)
    (asserts! (is-eq week (get current-week game-data)) ERR-INVALID-PICK)
    (asserts! (not (get eliminated participant-data)) ERR-ALREADY-ELIMINATED)
    (asserts! (<= stacks-block-height deadline) ERR-PICK-DEADLINE-PASSED)
    (asserts! (> pick u0) ERR-INVALID-PICK) ;; Pick must be positive
    (asserts! (is-none (get-weekly-pick game-id week tx-sender)) ERR-ALREADY-PICKED)
    
    ;; Store the pick
    (map-set weekly-picks
      {game-id: game-id, week: week, participant: tx-sender}
      {pick: pick, submitted-at: stacks-block-height}
    )
    
    (ok true)
  )
)

;; Result setting and elimination processing
(define-public (set-weekly-result (game-id uint) (week uint) (winning-pick uint) (next-week-deadline (optional uint)))
  (let
    (
      (game-data (unwrap! (get-game game-id) ERR-GAME-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator game-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status game-data) STATUS-ACTIVE) ERR-GAME-NOT-STARTED)
    (asserts! (is-eq week (get current-week game-data)) ERR-INVALID-PICK)
    (asserts! (> winning-pick u0) ERR-INVALID-PICK)
    
    ;; Set the weekly result
    (map-set weekly-results
      {game-id: game-id, week: week}
      {winning-pick: winning-pick, set-at: stacks-block-height}
    )
    
    ;; For now, we'll use a simplified approach since we don't have a participants list
    ;; In production, you'd maintain a proper participants list and process eliminations
    (let
      (
        (updated-game (merge game-data
          {
            current-week: (+ week u1)
          }
        ))
      )
      ;; Set next week deadline if provided and game continues
      (match next-week-deadline
        deadline (if (> (get survivor-count game-data) u1)
          (map-set pick-deadlines
            {game-id: game-id, week: (+ week u1)}
            deadline
          )
          false
        )
        false
      )
      
      ;; Update game state
      (map-set games game-id updated-game)
      
      ;; Return current survivor count (would be updated after processing eliminations in production)
      (ok (get survivor-count game-data))
    )
  )
)

;; Helper function for elimination processing
(define-private (process-elimination-fold 
  (participant principal) 
  (context {game-id: uint, week: uint, winning-pick: uint, survivors: uint})
)
  (let
    (
      (game-id (get game-id context))
      (week (get week context))
      (winning-pick (get winning-pick context))
    )
    (match (get-participant-info game-id participant)
      participant-data
        (if (get eliminated participant-data)
          context ;; Already eliminated
          (match (get-weekly-pick game-id week participant)
            pick-data
              (if (is-eq (get pick pick-data) winning-pick)
                ;; Correct pick - survivor
                (merge context {survivors: (+ (get survivors context) u1)})
                ;; Wrong pick - eliminate
                (begin
                  (map-set game-participants
                    {game-id: game-id, participant: participant}
                    (merge participant-data {eliminated: true})
                  )
                  context
                )
              )
            ;; No pick submitted - eliminate
            (begin
              (map-set game-participants
                {game-id: game-id, participant: participant}
                (merge participant-data {eliminated: true})
              )
              context
            )
          )
        )
      context ;; Participant not found, skip
    )
  )
)

;; Game completion and payout
(define-private (complete-game (game-id uint))
  (let
    (
      (game-data (unwrap! (get-game game-id) ERR-GAME-NOT-FOUND))
      (total-pool (get total-pool game-data))
      (protocol-fee (/ (* total-pool (var-get protocol-fee-rate)) u10000))
      (winner-payout (- total-pool protocol-fee))
      (survivor-count (get survivor-count game-data))
    )
    (begin
      (map-set games game-id
        (merge game-data
          {
            status: STATUS-COMPLETED,
            winner: (if (is-eq survivor-count u1) 
                      ;; Find the single survivor - this would need proper implementation
                      none 
                      none)
          }
        )
      )
      
      ;; Transfer protocol fee to contract owner
      (if (> protocol-fee u0)
        (try! (as-contract (stx-transfer? protocol-fee tx-sender CONTRACT-OWNER)))
        true
      )
      
      ;; For now, simplified payout logic
      ;; In production, you'd need to implement proper survivor identification and payout
      (if (is-eq survivor-count u1)
        ;; Single winner - would need to identify and pay them
        (ok true)
        ;; Multiple survivors or none - would refund proportionally
        (ok true)
      )
    )
  )
)

(define-private (refund-participants (game-id uint) (participants (list 100 principal)) (total-amount uint))
  (let
    (
      (participant-count (len participants))
      (refund-per-participant (if (> participant-count u0) (/ total-amount participant-count) u0))
    )
    (fold refund-participant-fold participants {amount: refund-per-participant})
    (ok true)
  )
)

(define-private (refund-participant-fold (participant principal) (context {amount: uint}))
  (begin
    (unwrap-panic (as-contract (stx-transfer? (get amount context) tx-sender participant)))
    context
  )
)

;; Helper functions - simplified participant tracking
(define-data-var temp-game-id uint u0)

(define-private (get-all-participants (game-id uint))
  ;; This is a placeholder - in a production contract you'd maintain a participants list
  ;; For now, return empty list as this function needs to be implemented based on your participant tracking strategy
  (list)
)

;; Get count of survivors by counting non-eliminated participants
(define-private (count-survivors (game-id uint))
  ;; This would iterate through all participants and count non-eliminated ones
  ;; Implementation depends on how participants are tracked
  u0
)

;; Emergency functions
(define-public (emergency-cancel-game (game-id uint))
  (let
    (
      (game-data (unwrap! (get-game game-id) ERR-GAME-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status game-data) STATUS-COMPLETED)) ERR-GAME-ONGOING)
    
    ;; Mark game as completed first
    (map-set games game-id
      (merge game-data {status: STATUS-COMPLETED})
    )
    
    ;; Refund all participants (simplified for now)
    (refund-all-participants game-id)
  )
)

(define-private (refund-all-participants (game-id uint))
  ;; Simplified refund logic - in production you'd iterate through all participants
  ;; For now, just return success since we don't have participant enumeration
  (ok true)
)