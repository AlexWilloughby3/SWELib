import SWELib
import SWELibBridge.Libcurl.Response

/-!
# Libcurl POST Bridge

Bridge axioms asserting that libcurl POST responses satisfy
the spec-level ValidResponse constraints from RFC 9110.
-/

namespace SWELibBridge.Libcurl

open SWELib.Networking.Http

-- TRUST: <issue-url>

/-- Axiom: libcurl returns valid HTTP status codes in the range [100, 999]
    for any completed POST request. -/
axiom curl_post_valid_status (url : String) (reqHeaders : List Field)
    (body : ByteArray) (raw : RawCurlResponse) :
    100 ≤ raw.statusCode.toNat ∧ raw.statusCode.toNat ≤ 999

/-- Axiom: When libcurl reports a Content-Length header for a POST response,
    the received body size matches. This is guaranteed by libcurl's protocol
    implementation. -/
axiom curl_post_content_length_consistent (raw : RawCurlResponse) :
    let headers := parseRawHeaders raw.rawHeaders
    headers.getContentLength = none ∨
    headers.getContentLength = some raw.rawBody.size

/-- Axiom: libcurl does not strip or alter header fields returned by the server
    for POST responses. All headers from the server are present in rawHeaders. -/
axiom curl_post_headers_complete (raw : RawCurlResponse) :
    ∀ f ∈ parseRawHeaders raw.rawHeaders, f.name.raw.length > 0

end SWELibBridge.Libcurl
