module Ntfy

export ntfy
export NtfyLogger

using Base64
using Downloads
using Logging
using Preferences
using Printf

const DEFAULT_BASE_URL = "https://ntfy.sh"
const BASE_URL_PREFERENCE = "base_url"
const BASE_URL_ENVIRONMENT = "NTFY_BASE_URL"
const USER_PREFERENCE = "user"
const USER_ENVIRONMENT = "NTFY_USER"
const PASSWORD_PREFERENCE = "password"
const PASSWORD_ENVIRONMENT = "NTFY_PASSWORD"
const TOKEN_PREFERENCE = "token"
const TOKEN_ENVIRONMENT = "NTFY_TOKEN"

include("utils.jl")
include("function.jl")
include("logger.jl")

end # module
