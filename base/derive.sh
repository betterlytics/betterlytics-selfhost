#!/bin/sh
# Derives a deterministic secret from SECRET_BASE using HMAC-SHA256.
# Usage: derive_secret <label> <length>
derive_secret() {
    _result="" _i=0
    while [ ${#_result} -lt "$2" ]; do
        _chunk=$(printf '%s:%d' "$1" "$_i" | openssl dgst -sha256 -hmac "$SECRET_BASE" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
        _result="${_result}${_chunk}" _i=$((_i + 1))
    done
    printf '%s' "$_result" | head -c "$2"
}

# Hex variant for consumers that require hex-only secrets (Garage RPC secret and S3 keys).
# Usage: derive_hex_secret <label> <length>
derive_hex_secret() {
    _result="" _i=0
    while [ ${#_result} -lt "$2" ]; do
        _chunk=$(printf '%s:%d' "hex:$1" "$_i" | openssl dgst -sha256 -hmac "$SECRET_BASE" | awk '{print $NF}')
        _result="${_result}${_chunk}" _i=$((_i + 1))
    done
    printf '%s' "$_result" | head -c "$2"
}
