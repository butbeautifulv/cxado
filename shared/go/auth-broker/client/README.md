# Go auth-broker client

Thin HTTP client for `shared/go/auth-broker`.

```go
import brokerclient "github.com/butbeautifulv/cxado/shared/go/auth-broker/client"

c := brokerclient.New(brokerclient.Config{
    BaseURL:      os.Getenv("BROKER_URL"),
    ServiceToken: os.Getenv("BROKER_SERVICE_TOKEN"),
    ServiceID:    "veneno-engage",
})
tok, err := c.GetAccessToken(ctx, "veil-api", nil)
```

When consuming from a cxado submodule checkout, add to `go.mod`:

```
replace github.com/butbeautifulv/cxado/shared/go/auth-broker => ../../../shared/go/auth-broker
```
