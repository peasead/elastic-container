# Local Docker deployment: exports config as a record for generating .env.
# Usage: nickel export nickel/targets/local-docker.ncl --format json
# Then use scripts/nickel-export.sh local-docker to write .env (or convert JSON to .env yourself).

let config = import "../config.ncl" in
config
