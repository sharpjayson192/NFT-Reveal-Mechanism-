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

(define-data-var token-id-nonce uint u1)
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

(define-public (commit (commitment (buff 32)))
  (let ((current-phase (get-current-phase)))
    (begin
      (asserts! (is-eq current-phase "commit") ERR-INVALID-PHASE)
      (asserts! (is-none (map-get? user-commits tx-sender)) ERR-ALREADY-COMMITTED)
      (map-set user-commits tx-sender commitment)
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
  )
    (begin
      (asserts! (is-eq current-phase "mint") ERR-INVALID-PHASE)
      (asserts! (is-some reveal-data) ERR-NOT-COMMITTED)
      (asserts! (is-none (map-get? user-tokens tx-sender)) ERR-ALREADY-MINTED)
      (map-set nft-owners token-id tx-sender)
      (map-set user-tokens tx-sender token-id)
      (map-set nft-metadata token-id (generate-metadata (get value (unwrap-panic reveal-data))))
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

(define-read-only (get-contract-info)
  {
    owner: CONTRACT-OWNER,
    total-supply: (get-total-supply),
    current-phase: (get-current-phase),
    phase-info: (get-phase-info)
  }
)
