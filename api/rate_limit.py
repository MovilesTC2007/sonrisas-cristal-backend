from slowapi import Limiter
from slowapi.util import get_remote_address

# App-level rate limiting: a second layer behind nginx's limit_req zones
# (nginx/conf/nginx.conf). Defense in depth -- still applies even if nginx is
# ever bypassed, misconfigured, or a request reaches the API directly (e.g.
# compose.dev.yml's published port).
limiter = Limiter(key_func=get_remote_address)
