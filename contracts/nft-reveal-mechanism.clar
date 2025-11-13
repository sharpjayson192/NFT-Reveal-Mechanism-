(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PHASE (err u103))
(define-constant ERR-ALREADY-COMMITTED (err u104))
(define-constant ERR-NOT-COMMITTED (err u105))
(define-constant ERR-INVALID-REVEAL (err u106))
(define-constant ERR-ALREADY-REVEALED (err u107))
(define-constant ERR-ALREADY-MINTED (err u108))
(define-constant ERR-INVALID-TOKEN (err u109))
(define-constant ERR-UNAUTHORIZED (err u110))
(define-constant ERR-PAUSED (err u111))

(define-data-var token-id-nonce uint u1)
(define-data-var paused bool false)
(define-data-var commit-phase-start uint u0)
(define-data-var commit-phase-end uint u0)
(define-data-var reveal-phase-end uint u0)
(define-data-var mint-phase-end uint u0)
(define-data-var contract-uri (string-ascii 256) "")

(define-map nft-owners uint principal)
(define-map nft-metadata uint {name: (string-ascii 64), description: (string-ascii 256), image: (string-ascii 256)})
(define-map user-commits principal (buff 32))
(define-map user-reveals principal {value: uint, nonce: uint})
(define-map user-tokens principal uint)
(define-map token-approvals {token-id: uint, spender: principal} bool)
(define-map user-referrals principal principal)
(define-map referral-counts principal uint)
(define-map reward-balances principal uint)
(define-map referral-rewards principal uint)
(define-map user-stakes principal {amount: uint, start-height: uint, pool-id: uint})
(define-map staking-pools uint {name: (string-ascii 32), yield-rate: uint, min-stake: uint, lock-period: uint})
(define-map pool-stats uint {total-staked: uint, total-stakers: uint})

(define-data-var next-pool-id uint u1)
(define-data-var total-staked-global uint u0)
(define-data-var current-lottery-id uint u0)
(define-data-var lottery-treasury uint u0)

(define-map lottery-rounds uint {ticket-price: uint, max-tickets: uint, prize-pool: uint, end-height: uint, status: (string-ascii 16), winner: (optional principal)})
(define-map lottery-tickets {round-id: uint, ticket-id: uint} principal)
(define-map user-lottery-tickets {round-id: uint, user: principal} (list 20 uint))
(define-map lottery-ticket-counts uint uint)
(define-map lottery-stats principal {total-tickets: uint, total-winnings: uint, rounds-participated: uint})

(define-read-only (get-last-token-id)
  (- (var-get token-id-nonce) u1)
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get contract-uri)))
)

(define-read-only (get-owner (token-id uint))
  (ok (map-get? nft-owners token-id))
)

(define-read-only (get-current-phase)
  (let ((current-height stacks-block-height))
    (if (<= current-height (var-get commit-phase-end))
        "commit"
        (if (<= current-height (var-get reveal-phase-end))
            "reveal"
            (if (<= current-height (var-get mint-phase-end))
                "mint"
                "ended"
            )
        )
    )
  )
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-user-commitment (user principal))
  (map-get? user-commits user)
)

(define-read-only (get-user-reveal (user principal))
  (map-get? user-reveals user)
)

(define-read-only (get-user-token (user principal))
  (map-get? user-tokens user)
)

(define-read-only (get-token-metadata (token-id uint))
  (map-get? nft-metadata token-id)
)

(define-read-only (get-phase-info)
  {
    commit-start: (var-get commit-phase-start),
    commit-end: (var-get commit-phase-end),
    reveal-end: (var-get reveal-phase-end),
    mint-end: (var-get mint-phase-end),
    current-phase: (get-current-phase)
  }
)

(define-public (initialize-phases (commit-duration uint) (reveal-duration uint) (mint-duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-eq (var-get commit-phase-start) u0) ERR-ALREADY-EXISTS)
    (var-set commit-phase-start stacks-block-height)
    (var-set commit-phase-end (+ stacks-block-height commit-duration))
    (var-set reveal-phase-end (+ (var-get commit-phase-end) reveal-duration))
    (var-set mint-phase-end (+ (var-get reveal-phase-end) mint-duration))
    (ok true)
  )
)

(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set paused new-paused)
    (ok true)
  )
)

(define-public (commit (commitment (buff 32)))
  (let ((current-phase (get-current-phase)))
    (begin
      (asserts! (not (var-get paused)) ERR-PAUSED)
      (asserts! (is-eq current-phase "commit") ERR-INVALID-PHASE)
      (asserts! (is-none (map-get? user-commits tx-sender)) ERR-ALREADY-COMMITTED)
      (map-set user-commits tx-sender commitment)
      (ok true)
    )
  )
)

(define-public (commit-with-referral (commitment (buff 32)) (referrer principal))
  (let ((current-phase (get-current-phase)))
    (begin
      (asserts! (not (var-get paused)) ERR-PAUSED)
      (asserts! (is-eq current-phase "commit") ERR-INVALID-PHASE)
      (asserts! (is-none (map-get? user-commits tx-sender)) ERR-ALREADY-COMMITTED)
      (asserts! (not (is-eq tx-sender referrer)) ERR-UNAUTHORIZED)
      (map-set user-commits tx-sender commitment)
      (map-set user-referrals tx-sender referrer)
      (map-set referral-counts referrer (+ (default-to u0 (map-get? referral-counts referrer)) u1))
      (map-set reward-balances referrer (+ (default-to u0 (map-get? reward-balances referrer)) u100))
      (ok true)
    )
  )
)

(define-public (reveal (value uint) (nonce uint))
  (let (
    (current-phase (get-current-phase))
    (commitment (map-get? user-commits tx-sender))
    (value-buff (unwrap-panic (to-consensus-buff? value)))
    (nonce-buff (unwrap-panic (to-consensus-buff? nonce)))
    (expected-hash (sha256 (concat value-buff nonce-buff)))
  )
    (begin
      (asserts! (not (var-get paused)) ERR-PAUSED)
      (asserts! (is-eq current-phase "reveal") ERR-INVALID-PHASE)
      (asserts! (is-some commitment) ERR-NOT-COMMITTED)
      (asserts! (is-none (map-get? user-reveals tx-sender)) ERR-ALREADY-REVEALED)
      (asserts! (is-eq (unwrap-panic commitment) expected-hash) ERR-INVALID-REVEAL)
      (map-set user-reveals tx-sender {value: value, nonce: nonce})
      (ok true)
    )
  )
)

(define-public (mint-nft)
  (let (
    (current-phase (get-current-phase))
    (reveal-data (map-get? user-reveals tx-sender))
    (token-id (var-get token-id-nonce))
    (referrer (map-get? user-referrals tx-sender))
  )
    (begin
      (asserts! (not (var-get paused)) ERR-PAUSED)
      (asserts! (is-eq current-phase "mint") ERR-INVALID-PHASE)
      (asserts! (is-some reveal-data) ERR-NOT-COMMITTED)
      (asserts! (is-none (map-get? user-tokens tx-sender)) ERR-ALREADY-MINTED)
      (map-set nft-owners token-id tx-sender)
      (map-set user-tokens tx-sender token-id)
      (map-set nft-metadata token-id (generate-metadata (get value (unwrap-panic reveal-data))))
      (process-referral-reward referrer)
      (var-set token-id-nonce (+ token-id u1))
      (ok token-id)
    )
  )
)

(define-private (generate-metadata (revealed-value uint))
  (let ((trait-type (mod revealed-value u5)))
    (if (is-eq trait-type u0)
        {name: "Common NFT", description: "A common NFT with basic traits", image: "https://example.com/common.png"}
        (if (is-eq trait-type u1)
            {name: "Rare NFT", description: "A rare NFT with special traits", image: "https://example.com/rare.png"}
            (if (is-eq trait-type u2)
                {name: "Epic NFT", description: "An epic NFT with unique traits", image: "https://example.com/epic.png"}
                (if (is-eq trait-type u3)
                    {name: "Legendary NFT", description: "A legendary NFT with extraordinary traits", image: "https://example.com/legendary.png"}
                    {name: "Mythic NFT", description: "A mythic NFT with divine traits", image: "https://example.com/mythic.png"}
                )
            )
        )
    )
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((owner (unwrap! (map-get? nft-owners token-id) ERR-NOT-FOUND)))
    (begin
      (asserts! (not (var-get paused)) ERR-PAUSED)
      (asserts! (or (is-eq tx-sender sender) (is-eq tx-sender owner)) ERR-UNAUTHORIZED)
      (asserts! (is-eq owner sender) ERR-UNAUTHORIZED)
      (map-set nft-owners token-id recipient)
      (ok true)
    )
  )
)

(define-public (approve (token-id uint) (spender principal))
  (let ((owner (unwrap! (map-get? nft-owners token-id) ERR-NOT-FOUND)))
    (begin
      (asserts! (not (var-get paused)) ERR-PAUSED)
      (asserts! (is-eq tx-sender owner) ERR-UNAUTHORIZED)
      (map-set token-approvals {token-id: token-id, spender: spender} true)
      (ok true)
    )
  )
)

(define-public (transfer-from (token-id uint) (sender principal) (recipient principal))
  (let (
    (owner (unwrap! (map-get? nft-owners token-id) ERR-NOT-FOUND))
    (approved (default-to false (map-get? token-approvals {token-id: token-id, spender: tx-sender})))
  )
    (begin
      (asserts! (not (var-get paused)) ERR-PAUSED)
      (asserts! (or (is-eq tx-sender owner) approved) ERR-UNAUTHORIZED)
      (asserts! (is-eq owner sender) ERR-UNAUTHORIZED)
      (map-delete token-approvals {token-id: token-id, spender: tx-sender})
      (map-set nft-owners token-id recipient)
      (ok true)
    )
  )
)

(define-public (set-contract-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set contract-uri new-uri)
    (ok true)
  )
)

(define-read-only (is-approved (token-id uint) (spender principal))
  (default-to false (map-get? token-approvals {token-id: token-id, spender: spender}))
)

(define-read-only (get-total-supply)
  (- (var-get token-id-nonce) u1)
)

(define-read-only (get-balance (owner principal))
  (if (is-some (map-get? user-tokens owner)) u1 u0)
)

(define-read-only (get-referral-info (user principal))
  {
    referrer: (map-get? user-referrals user),
    referral-count: (default-to u0 (map-get? referral-counts user)),
    reward-balance: (default-to u0 (map-get? reward-balances user)),
    total-rewards-earned: (default-to u0 (map-get? referral-rewards user))
  }
)

(define-read-only (get-reward-balance (user principal))
  (default-to u0 (map-get? reward-balances user))
)

(define-public (claim-referral-bonus)
  (let (
    (current-phase (get-current-phase))
    (user-reveal (map-get? user-reveals tx-sender))
    (referrer (map-get? user-referrals tx-sender))
    (bonus-amount u50)
  )
    (begin
      (asserts! (is-eq current-phase "mint") ERR-INVALID-PHASE)
      (asserts! (is-some user-reveal) ERR-NOT-COMMITTED)
      (asserts! (is-some referrer) ERR-NOT-FOUND)
      (map-set reward-balances tx-sender (+ (default-to u0 (map-get? reward-balances tx-sender)) bonus-amount))
      (map-set referral-rewards tx-sender (+ (default-to u0 (map-get? referral-rewards tx-sender)) bonus-amount))
      (ok bonus-amount)
    )
  )
)

(define-public (spend-rewards (amount uint))
  (let ((current-balance (default-to u0 (map-get? reward-balances tx-sender))))
    (begin
      (asserts! (>= current-balance amount) ERR-UNAUTHORIZED)
      (map-set reward-balances tx-sender (- current-balance amount))
      (ok true)
    )
  )
)

(define-public (transfer-rewards (recipient principal) (amount uint))
  (let ((current-balance (default-to u0 (map-get? reward-balances tx-sender))))
    (begin
      (asserts! (>= current-balance amount) ERR-UNAUTHORIZED)
      (map-set reward-balances tx-sender (- current-balance amount))
      (map-set reward-balances recipient (+ (default-to u0 (map-get? reward-balances recipient)) amount))
      (ok true)
    )
  )
)

(define-private (process-referral-reward (referrer-opt (optional principal)))
  (match referrer-opt
    referrer (begin
      (map-set reward-balances referrer (+ (default-to u0 (map-get? reward-balances referrer)) u25))
      (map-set referral-rewards referrer (+ (default-to u0 (map-get? referral-rewards referrer)) u25))
      true
    )
    false
  )
)

(define-public (create-staking-pool (name (string-ascii 32)) (yield-rate uint) (min-stake uint) (lock-period uint))
  (let ((pool-id (var-get next-pool-id)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
      (map-set staking-pools pool-id {name: name, yield-rate: yield-rate, min-stake: min-stake, lock-period: lock-period})
      (map-set pool-stats pool-id {total-staked: u0, total-stakers: u0})
      (var-set next-pool-id (+ pool-id u1))
      (ok pool-id)
    )
  )
)

(define-public (stake-tokens (pool-id uint) (amount uint))
  (let (
    (pool (unwrap! (map-get? staking-pools pool-id) ERR-NOT-FOUND))
    (current-balance (default-to u0 (map-get? reward-balances tx-sender)))
    (existing-stake (map-get? user-stakes tx-sender))
    (pool-stat (unwrap! (map-get? pool-stats pool-id) ERR-NOT-FOUND))
  )
    (begin
      (asserts! (is-none existing-stake) ERR-ALREADY-EXISTS)
      (asserts! (>= current-balance amount) ERR-UNAUTHORIZED)
      (asserts! (>= amount (get min-stake pool)) ERR-UNAUTHORIZED)
      (map-set reward-balances tx-sender (- current-balance amount))
      (map-set user-stakes tx-sender {amount: amount, start-height: stacks-block-height, pool-id: pool-id})
      (map-set pool-stats pool-id {
        total-staked: (+ (get total-staked pool-stat) amount),
        total-stakers: (+ (get total-stakers pool-stat) u1)
      })
      (var-set total-staked-global (+ (var-get total-staked-global) amount))
      (ok true)
    )
  )
)

(define-public (unstake-tokens)
  (let (
    (stake (unwrap! (map-get? user-stakes tx-sender) ERR-NOT-FOUND))
    (pool (unwrap! (map-get? staking-pools (get pool-id stake)) ERR-NOT-FOUND))
    (pool-stat (unwrap! (map-get? pool-stats (get pool-id stake)) ERR-NOT-FOUND))
    (staked-duration (- stacks-block-height (get start-height stake)))
    (lock-period (get lock-period pool))
    (yield-amount (calculate-yield stake))
    (total-return (+ (get amount stake) yield-amount))
  )
    (begin
      (asserts! (>= staked-duration lock-period) ERR-INVALID-PHASE)
      (map-delete user-stakes tx-sender)
      (map-set reward-balances tx-sender (+ (default-to u0 (map-get? reward-balances tx-sender)) total-return))
      (map-set pool-stats (get pool-id stake) {
        total-staked: (- (get total-staked pool-stat) (get amount stake)),
        total-stakers: (- (get total-stakers pool-stat) u1)
      })
      (var-set total-staked-global (- (var-get total-staked-global) (get amount stake)))
      (ok total-return)
    )
  )
)

(define-public (emergency-unstake)
  (let (
    (stake (unwrap! (map-get? user-stakes tx-sender) ERR-NOT-FOUND))
    (pool-stat (unwrap! (map-get? pool-stats (get pool-id stake)) ERR-NOT-FOUND))
    (penalty-amount (/ (get amount stake) u10))
    (return-amount (- (get amount stake) penalty-amount))
  )
    (begin
      (map-delete user-stakes tx-sender)
      (map-set reward-balances tx-sender (+ (default-to u0 (map-get? reward-balances tx-sender)) return-amount))
      (map-set pool-stats (get pool-id stake) {
        total-staked: (- (get total-staked pool-stat) (get amount stake)),
        total-stakers: (- (get total-stakers pool-stat) u1)
      })
      (var-set total-staked-global (- (var-get total-staked-global) (get amount stake)))
      (ok return-amount)
    )
  )
)

(define-private (calculate-yield (stake {amount: uint, start-height: uint, pool-id: uint}))
  (let (
    (pool (unwrap-panic (map-get? staking-pools (get pool-id stake))))
    (staked-duration (- stacks-block-height (get start-height stake)))
    (yield-per-block (/ (* (get amount stake) (get yield-rate pool)) u10000))
  )
    (* yield-per-block staked-duration)
  )
)

(define-read-only (get-stake-info (user principal))
  (match (map-get? user-stakes user)
    stake (let (
      (pool (unwrap-panic (map-get? staking-pools (get pool-id stake))))
      (current-yield (calculate-yield stake))
    )
      (some {
        amount: (get amount stake),
        start-height: (get start-height stake),
        pool-id: (get pool-id stake),
        pool-name: (get name pool),
        current-yield: current-yield,
        total-return: (+ (get amount stake) current-yield)
      })
    )
    none
  )
)

(define-read-only (get-pool-info (pool-id uint))
  (match (map-get? staking-pools pool-id)
    pool (let ((stats (unwrap-panic (map-get? pool-stats pool-id))))
      (some {
        name: (get name pool),
        yield-rate: (get yield-rate pool),
        min-stake: (get min-stake pool),
        lock-period: (get lock-period pool),
        total-staked: (get total-staked stats),
        total-stakers: (get total-stakers stats)
      })
    )
    none
  )
)

(define-read-only (get-staking-overview)
  {
    total-staked-global: (var-get total-staked-global),
    total-pools: (- (var-get next-pool-id) u1),
    user-stake: (get-stake-info tx-sender)
  }
)

(define-public (start-lottery (ticket-price uint) (max-tickets uint) (duration uint))
  (let ((lottery-id (+ (var-get current-lottery-id) u1)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
      (asserts! (> ticket-price u0) ERR-UNAUTHORIZED)
      (asserts! (> max-tickets u0) ERR-UNAUTHORIZED)
      (map-set lottery-rounds lottery-id {
        ticket-price: ticket-price,
        max-tickets: max-tickets,
        prize-pool: u0,
        end-height: (+ stacks-block-height duration),
        status: "active",
        winner: none
      })
      (map-set lottery-ticket-counts lottery-id u0)
      (var-set current-lottery-id lottery-id)
      (ok lottery-id)
    )
  )
)

(define-public (buy-lottery-tickets (round-id uint) (quantity uint))
  (let (
    (round (unwrap! (map-get? lottery-rounds round-id) ERR-NOT-FOUND))
    (current-balance (default-to u0 (map-get? reward-balances tx-sender)))
    (total-cost (* (get ticket-price round) quantity))
    (current-ticket-count (default-to u0 (map-get? lottery-ticket-counts round-id)))
    (user-tickets (default-to (list) (map-get? user-lottery-tickets {round-id: round-id, user: tx-sender})))
    (user-stats (default-to {total-tickets: u0, total-winnings: u0, rounds-participated: u0} (map-get? lottery-stats tx-sender)))
  )
    (begin
      (asserts! (is-eq (get status round) "active") ERR-INVALID-PHASE)
      (asserts! (<= stacks-block-height (get end-height round)) ERR-INVALID-PHASE)
      (asserts! (<= (+ current-ticket-count quantity) (get max-tickets round)) ERR-UNAUTHORIZED)
      (asserts! (>= current-balance total-cost) ERR-UNAUTHORIZED)
      (asserts! (<= quantity u20) ERR-UNAUTHORIZED)
      (map-set reward-balances tx-sender (- current-balance total-cost))
      (map-set lottery-rounds round-id (merge round {prize-pool: (+ (get prize-pool round) total-cost)}))
      (map-set lottery-ticket-counts round-id (+ current-ticket-count quantity))
      (allocate-tickets round-id current-ticket-count quantity)
      (map-set lottery-stats tx-sender (merge user-stats {
        total-tickets: (+ (get total-tickets user-stats) quantity),
        rounds-participated: (if (is-eq (len user-tickets) u0) (+ (get rounds-participated user-stats) u1) (get rounds-participated user-stats))
      }))
      (ok true)
    )
  )
)

(define-private (allocate-tickets (round-id uint) (start-ticket uint) (quantity uint))
  (let ((user-tickets (default-to (list) (map-get? user-lottery-tickets {round-id: round-id, user: tx-sender}))))
    (begin
      (map-set lottery-tickets {round-id: round-id, ticket-id: start-ticket} tx-sender)
      (if (> quantity u1)
        (begin
          (map-set lottery-tickets {round-id: round-id, ticket-id: (+ start-ticket u1)} tx-sender)
          (if (> quantity u2)
            (begin
              (map-set lottery-tickets {round-id: round-id, ticket-id: (+ start-ticket u2)} tx-sender)
              true
            )
            true
          )
        )
        true
      )
      (map-set user-lottery-tickets {round-id: round-id, user: tx-sender} 
        (unwrap-panic (as-max-len? (append user-tickets start-ticket) u20)))
      true
    )
  )
)

(define-public (draw-lottery-winner (round-id uint) (random-seed uint))
  (let (
    (round (unwrap! (map-get? lottery-rounds round-id) ERR-NOT-FOUND))
    (ticket-count (default-to u0 (map-get? lottery-ticket-counts round-id)))
    (winning-ticket (mod random-seed ticket-count))
    (winner (unwrap! (map-get? lottery-tickets {round-id: round-id, ticket-id: winning-ticket}) ERR-NOT-FOUND))
  )
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
      (asserts! (is-eq (get status round) "active") ERR-INVALID-PHASE)
      (asserts! (> stacks-block-height (get end-height round)) ERR-INVALID-PHASE)
      (asserts! (> ticket-count u0) ERR-NOT-FOUND)
      (map-set lottery-rounds round-id (merge round {status: "drawn", winner: (some winner)}))
      (ok winner)
    )
  )
)

(define-public (claim-lottery-prize (round-id uint))
  (let (
    (round (unwrap! (map-get? lottery-rounds round-id) ERR-NOT-FOUND))
    (winner (unwrap! (get winner round) ERR-NOT-FOUND))
    (user-stats (default-to {total-tickets: u0, total-winnings: u0, rounds-participated: u0} (map-get? lottery-stats tx-sender)))
  )
    (begin
      (asserts! (is-eq tx-sender winner) ERR-UNAUTHORIZED)
      (asserts! (is-eq (get status round) "drawn") ERR-INVALID-PHASE)
      (map-set reward-balances tx-sender (+ (default-to u0 (map-get? reward-balances tx-sender)) (get prize-pool round)))
      (map-set lottery-rounds round-id (merge round {status: "claimed"}))
      (map-set lottery-stats tx-sender (merge user-stats {
        total-winnings: (+ (get total-winnings user-stats) (get prize-pool round))
      }))
      (ok (get prize-pool round))
    )
  )
)

(define-read-only (get-lottery-round (round-id uint))
  (map-get? lottery-rounds round-id)
)

(define-read-only (get-user-lottery-tickets (round-id uint) (user principal))
  (map-get? user-lottery-tickets {round-id: round-id, user: user})
)

(define-read-only (get-lottery-stats (user principal))
  (default-to {total-tickets: u0, total-winnings: u0, rounds-participated: u0} (map-get? lottery-stats user))
)

(define-read-only (get-current-lottery)
  (let ((current-id (var-get current-lottery-id)))
    (if (> current-id u0)
      (map-get? lottery-rounds current-id)
      none
    )
  )
)

(define-read-only (get-lottery-overview)
  {
    current-lottery-id: (var-get current-lottery-id),
    lottery-treasury: (var-get lottery-treasury),
    current-lottery: (get-current-lottery),
    user-stats: (get-lottery-stats tx-sender)
  }
)

(define-read-only (get-contract-info)
  {
    owner: CONTRACT-OWNER,
    total-supply: (get-total-supply),
    current-phase: (get-current-phase),
    phase-info: (get-phase-info)
  }
)
