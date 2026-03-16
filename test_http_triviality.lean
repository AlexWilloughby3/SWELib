import SWELib.Networking.Http

open SWELib.Networking.Http

-- Test if theorems are trivial

#eval Method.safe_implies_idempotent .GET true
#eval Method.safe_implies_idempotent .POST false  
#eval Method.cacheableByDefault_implies_safe .GET true
#eval Method.cacheableByDefault_implies_safe .POST false

-- Test concrete examples from RFC 9110
#eval Method.isSafe .GET
#eval Method.isSafe .POST
#eval Method.isIdempotent .PUT
#eval Method.isIdempotent .POST

-- Test status codes
#eval StatusCode.isInterim StatusCode.continue_
#eval StatusCode.mayHaveBody StatusCode.noContent
#eval StatusCode.mayHaveBody StatusCode.ok

-- Test ETag comparisons
def etag1 : ETag := { value := "abc", weak := false }
def etag2 : ETag := { value := "abc", weak := true }
#eval ETag.strongEq etag1 etag2  -- Should be false
#eval ETag.weakEq etag1 etag2    -- Should be true

-- Test header operations
def headers : Headers := [
  { name := ⟨"Content-Type"⟩, value := "text/plain" },
  { name := ⟨"content-type"⟩, value := "text/html" },
  { name := ⟨"Host"⟩, value := "example.com" }
]
#eval headers.getAll ⟨"content-type"⟩  -- Should get both due to case-insensitive

-- Test defaultPort functions
#eval defaultPort "http"
#eval defaultPort "https"
#eval defaultPort "ftp"
