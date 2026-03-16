import SWELib
import SWELibBridge

/-!
# Libcurl FFI

Raw `@[extern]` declarations for libcurl.
Single function: perform an HTTP request and return status + headers + body.
-/

namespace SWELibCode.Ffi.Libcurl

/-- Perform an HTTP request via libcurl.
    Returns `(statusCode, rawHeaderBytes, rawBodyBytes)`.
    - `method`: HTTP method string ("GET", "POST", etc.)
    - `url`: full URL
    - `headers`: array of "Header: Value" strings
    - `body`: request body bytes (empty ByteArray for no body) -/
@[extern "swelib_curl_perform"]
opaque curlPerform
    (method : @& String)
    (url : @& String)
    (headers : @& Array String)
    (body : @& ByteArray)
    : IO (UInt32 × ByteArray × ByteArray)

end SWELibCode.Ffi.Libcurl
