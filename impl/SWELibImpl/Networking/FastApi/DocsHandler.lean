import SWELib
import SWELibImpl.Networking.HttpServer

/-!
# FastAPI Docs Handlers

Serves Swagger UI at `/docs` and ReDoc at `/redoc` as HTML pages that
load their respective JavaScript bundles from CDNs and point to the
application's OpenAPI JSON endpoint.
-/

namespace SWELibImpl.Networking.FastApi.DocsHandler

open SWELib.Networking.FastApi
open SWELib.Networking.Http

/-- Generate the Swagger UI HTML page.
    `openApiUrl` is the path to the OpenAPI JSON endpoint (e.g., "/openapi.json").
    `title` is the application title shown in the page. -/
def swaggerUIHtml (openApiUrl : String) (title : String) : String :=
  s!"<!DOCTYPE html>
<html>
<head>
  <title>{title} - Swagger UI</title>
  <meta charset=\"utf-8\"/>
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>
  <link rel=\"stylesheet\" href=\"https://unpkg.com/swagger-ui-dist@5/swagger-ui.css\"/>
</head>
<body>
  <div id=\"swagger-ui\"></div>
  <script src=\"https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js\"></script>
  <script>
    SwaggerUIBundle(\{
      url: \"{openApiUrl}\",
      dom_id: \"#swagger-ui\",
      presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
      layout: \"StandaloneLayout\"
    })
  </script>
</body>
</html>"

/-- Generate the ReDoc HTML page. -/
def redocHtml (openApiUrl : String) (title : String) : String :=
  s!"<!DOCTYPE html>
<html>
<head>
  <title>{title} - ReDoc</title>
  <meta charset=\"utf-8\"/>
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>
</head>
<body>
  <redoc spec-url=\"{openApiUrl}\"></redoc>
  <script src=\"https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js\"></script>
</body>
</html>"

/-- Serve the Swagger UI page as an HTTP response. -/
def serveSwaggerUI (app : FastAPIApp) : IO Response := do
  let openApiUrl := app.openApiUrl.getD "/openapi.json"
  let html := swaggerUIHtml openApiUrl app.title
  pure {
    status := StatusCode.ok
    headers := [{ name := FieldName.contentType, value := "text/html; charset=utf-8" }]
    body := some html.toUTF8
  }

/-- Serve the ReDoc page as an HTTP response. -/
def serveRedoc (app : FastAPIApp) : IO Response := do
  let openApiUrl := app.openApiUrl.getD "/openapi.json"
  let html := redocHtml openApiUrl app.title
  pure {
    status := StatusCode.ok
    headers := [{ name := FieldName.contentType, value := "text/html; charset=utf-8" }]
    body := some html.toUTF8
  }

end SWELibImpl.Networking.FastApi.DocsHandler
