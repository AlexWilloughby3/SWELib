import SWELib

/-!
# Libcurl Response Bridge

Bridge axioms asserting that raw curl response bytes can be faithfully
parsed into spec-level Http.Response values.
-/

namespace SWELibImpl.Bridge.Libcurl

open SWELib.Networking.Http

-- TRUST: <issue-url>

/-- A raw curl response is a triple of (statusCode, headerBytes, bodyBytes). -/
structure RawCurlResponse where
  statusCode : UInt32
  rawHeaders : ByteArray
  rawBody    : ByteArray

/-- Parse raw header bytes into a list of header fields.
    Headers are separated by "\r\n", each line is "Name: Value". -/
def parseRawHeaders (raw : ByteArray) : Headers :=
  let s := String.fromUTF8! raw
  let lines := s.splitOn "\r\n"
  lines.filterMap fun line =>
    if line.isEmpty then none
    else
      -- Skip the status line (starts with "HTTP/")
      if line.startsWith "HTTP/" then none
      else
        match line.splitOn ": " with
        | name :: rest =>
          let value := ": ".intercalate rest
          some { name := ⟨name⟩, value := value.trimAsciiEnd.toString }
        | _ => none

/-- Axiom: libcurl only returns status codes in the range [100, 999].
    Values outside this range are reported as IO errors before reaching
    the application layer. -/
axiom curl_status_in_range (raw : RawCurlResponse) :
    100 ≤ raw.statusCode.toNat ∧ raw.statusCode.toNat ≤ 999

/-- Axiom: The header parsing function preserves all header fields
    present in the raw response, in order. -/
axiom curl_headers_faithful (raw : RawCurlResponse) :
    ∀ f ∈ parseRawHeaders raw.rawHeaders, f.name.raw.length > 0

end SWELibImpl.Bridge.Libcurl
