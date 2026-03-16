import SWELib.Networking.Http.Field
import SWELib.Networking.Http.Message
import SWELib.Networking.Http.Representation

/-!
# HTTP/1.1 Message Framing

RFC 9112 Section 6: Message body length determination rules.
These rules specify how to determine the length of the message body
in HTTP/1.1 using Transfer-Encoding, Content-Length, or connection close.
-/

namespace SWELib.Networking.Http

/-- The mechanism used to frame (delimit) the message body.
    RFC 9112 Section 6: message body length is determined in this order. -/
inductive FramingMechanism where
  /-- No body: HEAD, 1xx, 204, 304 responses, or CONNECT 2xx. -/
  | noBody
  /-- Transfer-Encoding: chunked (RFC 9112 Section 7.1). -/
  | chunkedTE
  /-- Transfer-Encoding other than chunked. -/
  | otherTE (coding : String)
  /-- Content-Length is used to determine body length. -/
  | contentLength (n : Nat)
  /-- Reads until connection close (only valid for responses). -/
  | readUntilClose
  deriving DecidableEq, Repr

/-- Determine the framing mechanism for a response body
    per RFC 9112 Section 6.3 (in priority order). -/
def Response.framingMechanism (resp : Response) : FramingMechanism :=
  -- Step 1: No body for 1xx, 204, 304
  if !resp.status.mayHaveBody then .noBody
  -- Step 2: Transfer-Encoding takes precedence
  else match resp.headers.getTransferEncoding with
  | some te =>
    if te == "chunked" then .chunkedTE
    else .otherTE te
  -- Step 3: Content-Length
  | none => match resp.headers.getContentLength with
  | some n => .contentLength n
  -- Step 4: read until close
  | none => .readUntilClose

/-- A chunked transfer-encoding chunk (RFC 9112 Section 7.1.1). -/
structure Chunk where
  /-- Chunk size in bytes. 0 indicates the last-chunk. -/
  size : Nat
  /-- Chunk data (empty for the last-chunk). -/
  data : ByteArray

/-- A complete chunked message body (RFC 9112 Section 7.1). -/
structure ChunkedBody where
  /-- The sequence of data chunks (size > 0). -/
  chunks : List Chunk
  /-- Optional trailer fields (RFC 9112 Section 7.1.2). -/
  trailers : Headers := []

/-- Total decoded body size of a chunked transfer. -/
def ChunkedBody.totalSize (cb : ChunkedBody) : Nat :=
  cb.chunks.foldl (· + ·.size) 0

/-- Decode a chunked body to a flat ByteArray. -/
def ChunkedBody.decode (cb : ChunkedBody) : ByteArray :=
  cb.chunks.foldl (· ++ ·.data) ByteArray.empty

-- Theorems

/-- Interim responses (1xx) always use the noBody framing mechanism. -/
theorem Response.interim_framing_is_noBody (resp : Response)
    (h : resp.status.isInterim = true) :
    resp.framingMechanism = .noBody := by
  simp only [framingMechanism]
  have hNotMayHave : resp.status.mayHaveBody = false := by
    exact StatusCode.interim_no_body resp.status h
  simp [hNotMayHave]

/-- Transfer-Encoding "chunked" takes precedence over Content-Length (RFC 9112 Section 6.3). -/
theorem Response.chunkedTE_ignores_contentLength (resp : Response)
    (hBody : resp.status.mayHaveBody = true)
    (hTE : resp.headers.getTransferEncoding = some "chunked") :
    resp.framingMechanism = .chunkedTE := by
  simp only [framingMechanism, hBody, Bool.not_true, hTE]
  native_decide

/-- An empty chunked body decodes to an empty ByteArray. -/
theorem ChunkedBody.decode_empty :
    ChunkedBody.decode { chunks := [] } = ByteArray.empty := by
  simp [decode, List.foldl]

/-- Total size of an empty chunked body is 0. -/
theorem ChunkedBody.totalSize_empty :
    ChunkedBody.totalSize { chunks := [] } = 0 := by
  simp [totalSize, List.foldl]

/-- The decoded body size equals the total chunk sizes,
    provided each chunk's data size matches its declared size. -/
theorem ChunkedBody.decode_size_eq_totalSize (cb : ChunkedBody)
    (h : ∀ c ∈ cb.chunks, c.data.size = c.size) :
    cb.decode.size = cb.totalSize := by
  unfold decode totalSize
  suffices ∀ (l : List Chunk) (acc : ByteArray) (n : Nat),
      (∀ c ∈ l, c.data.size = c.size) →
      acc.size = n →
      (l.foldl (· ++ ·.data) acc).size = l.foldl (· + ·.size) n by
    exact this cb.chunks ByteArray.empty 0 h (by rfl)
  intro l
  induction l with
  | nil => intro acc n _ hn; simp [List.foldl, hn]
  | cons c cs ih =>
    intro acc n hAll hn
    simp only [List.foldl_cons]
    apply ih
    · intro c' hc'
      exact hAll c' (List.mem_cons.mpr (Or.inr hc'))
    · rw [ByteArray.size_append, hn]
      exact congrArg (n + ·) (hAll c (List.mem_cons.mpr (Or.inl rfl)))

/-- Content-Length framing reports the correct body length. -/
theorem Response.contentLength_framing_matches (resp : Response)
    (hBody : resp.status.mayHaveBody = true)
    (hNoTE : resp.headers.getTransferEncoding = none)
    (hCL : resp.headers.getContentLength = some n) :
    resp.framingMechanism = .contentLength n := by
  simp [framingMechanism, hBody, hNoTE, hCL]

/-- readUntilClose is only used when both TE and CL are absent. -/
theorem Response.readUntilClose_iff_no_framing_headers (resp : Response)
    (hBody : resp.status.mayHaveBody = true) :
    resp.framingMechanism = .readUntilClose ↔
    resp.headers.getTransferEncoding = none ∧ resp.headers.getContentLength = none := by
  constructor
  · intro h
    unfold framingMechanism at h
    simp only [hBody, Bool.not_true] at h
    constructor
    · cases hTE : resp.headers.getTransferEncoding with
      | none => rfl
      | some te =>
        simp only [hTE] at h
        by_cases hc : te = "chunked" <;> simp [hc] at h
    · cases hTE : resp.headers.getTransferEncoding with
      | none =>
        simp only [hTE] at h
        cases hCL : resp.headers.getContentLength with
        | none => rfl
        | some n => simp [hCL] at h
      | some te =>
        simp only [hTE] at h
        by_cases hc : te = "chunked" <;> simp [hc] at h
  · intro ⟨hTE, hCL⟩
    simp [framingMechanism, hBody, hTE, hCL]

end SWELib.Networking.Http
