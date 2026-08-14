#!/bin/sh
set -e

export AWS_ACCESS_KEY_ID="$REPLAY_S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$REPLAY_S3_SECRET_KEY"
export AWS_DEFAULT_REGION="garage"

ENDPOINT="http://garage:3900"
BUCKET="replay-storage"

_tries=0
until aws --endpoint-url "$ENDPOINT" s3api head-bucket --bucket "$BUCKET" 2>/dev/null; do
    _tries=$((_tries + 1))
    if [ "$_tries" -ge 30 ]; then
        echo "Bucket ${BUCKET} not available, giving up"
        exit 1
    fi
    sleep 2
done

aws --endpoint-url "$ENDPOINT" s3api put-bucket-cors --bucket "$BUCKET" --cors-configuration '{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3600
    }
  ]
}'

RETENTION_DAYS="${REPLAY_RETENTION_DAYS:-$DATA_RETENTION_DAYS}"

if [ "$RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
    aws --endpoint-url "$ENDPOINT" s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration "{
  \"Rules\": [
    {
      \"ID\": \"expire-replay-segments\",
      \"Status\": \"Enabled\",
      \"Filter\": { \"Prefix\": \"\" },
      \"Expiration\": { \"Days\": ${RETENTION_DAYS} }
    },
    {
      \"ID\": \"abort-incomplete-uploads\",
      \"Status\": \"Enabled\",
      \"Filter\": { \"Prefix\": \"\" },
      \"AbortIncompleteMultipartUpload\": { \"DaysAfterInitiation\": 1 }
    }
  ]
}"
else
    aws --endpoint-url "$ENDPOINT" s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration '{
  "Rules": [
    {
      "ID": "abort-incomplete-uploads",
      "Status": "Enabled",
      "Filter": { "Prefix": "" },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 1 }
    }
  ]
}'
fi

echo "Replay storage bucket configured"
