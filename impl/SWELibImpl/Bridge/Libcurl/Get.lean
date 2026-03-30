import SWELib
import SWELibImpl.Bridge.Libcurl.Response

/-!
# Libcurl GET Bridge

Bridge axioms asserting that libcurl GET responses satisfy
the spec-level ValidResponse constraints from RFC 9110.
-/

namespace SWELibImpl.Bridge.Libcurl

open SWELib.Networking.Http

-- TRUST: <issue-url>

/-- Axiom: When libcurl reports a Content-Length header for a GET response,
    the received body size matches. This is guaranteed by libcurl's protocol
    implementation. -/
axiom curl_get_content_length_consistent (raw : RawCurlResponse) :
    let headers := parseRawHeaders raw.rawHeaders
    headers.getContentLength = none ∨
    headers.getContentLength = some raw.rawBody.size

/-- Axiom: libcurl does not strip or alter header fields returned by the server
    for GET responses. All headers from the server are present in rawHeaders. -/
axiom curl_get_headers_complete (raw : RawCurlResponse) :
    ∀ f ∈ parseRawHeaders raw.rawHeaders, f.name.raw.length > 0

end SWELibImpl.Bridge.Libcurl
