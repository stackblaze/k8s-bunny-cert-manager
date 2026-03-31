#!/bin/sh
set -e

# Usage: dns-manage.sh <action> <api-key> <domain> <ttl> <ips> <cluster-name> <services>
# action: "create" or "delete"
# ips: comma-separated list
# services: comma-separated list (optional)

ACTION="$1"
API_KEY="$2"
DOMAIN="$3"
TTL="${4:-60}"
IPS="$5"
CLUSTER_NAME="$6"
SERVICES="$7"

API_BASE="https://api.bunny.net"
ZONE_ID=""
CREATED=0
DELETED=0
SKIPPED=0

log() { echo "[dns-manage] $1"; }

# Find zone ID by domain name
find_zone_id() {
  PAGE=1
  while true; do
    RESPONSE=$(curl -sf -H "AccessKey: ${API_KEY}" "${API_BASE}/dnszone?page=${PAGE}&perPage=50")
    ZONE_ID=$(echo "$RESPONSE" | sed -n 's/.*"Id":\([0-9]*\),"Domain":"'"${DOMAIN}"'".*/\1/p' | head -1)
    if [ -n "$ZONE_ID" ]; then
      log "Found zone ID: ${ZONE_ID} for ${DOMAIN}"
      return 0
    fi
    HAS_MORE=$(echo "$RESPONSE" | sed -n 's/.*"HasMoreItems":\(true\|false\).*/\1/p' | head -1)
    if [ "$HAS_MORE" != "true" ]; then
      break
    fi
    PAGE=$((PAGE + 1))
  done
  log "ERROR: Zone not found for domain: ${DOMAIN}"
  exit 1
}

# Check if A record exists
record_exists() {
  local name="$1"
  local ip="$2"
  RECORDS=$(curl -sf -H "AccessKey: ${API_KEY}" "${API_BASE}/dnszone/${ZONE_ID}")
  echo "$RECORDS" | grep -q "\"Type\":0,\"Ttl\":.*\"Value\":\"${ip}\",\"Name\":\"${name}\""
}

# Create A record if it doesn't exist
create_record() {
  local name="$1"
  local ip="$2"
  if record_exists "$name" "$ip"; then
    log "SKIP: A ${name:-@} -> ${ip} (exists)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  curl -sf -X PUT \
    -H "AccessKey: ${API_KEY}" \
    -H "Content-Type: application/json" \
    "${API_BASE}/dnszone/${ZONE_ID}/records" \
    -d "{\"Type\": 0, \"Name\": \"${name}\", \"Value\": \"${ip}\", \"Ttl\": ${TTL}}" > /dev/null
  log "CREATE: A ${name:-@} -> ${ip}"
  CREATED=$((CREATED + 1))
}

# Delete all A records matching a name
delete_records_by_name() {
  local name="$1"
  RECORDS=$(curl -sf -H "AccessKey: ${API_KEY}" "${API_BASE}/dnszone/${ZONE_ID}")
  # Extract record IDs for matching A records (Type 0)
  echo "$RECORDS" | tr '{' '\n' | grep "\"Type\":0" | grep "\"Name\":\"${name}\"" | while read -r line; do
    RID=$(echo "$line" | sed -n 's/.*"Id":\([0-9]*\).*/\1/p')
    if [ -n "$RID" ]; then
      curl -sf -X DELETE -H "AccessKey: ${API_KEY}" "${API_BASE}/dnszone/${ZONE_ID}/records/${RID}" > /dev/null
      log "DELETE: A ${name:-@} (ID: ${RID})"
      DELETED=$((DELETED + 1))
    fi
  done
}

# Main
find_zone_id

IFS=',' read -r dummy <<EOF
$IPS
EOF

if [ "$ACTION" = "create" ]; then
  log "Creating DNS records for ${DOMAIN}..."

  # Root A records
  for IP in $(echo "$IPS" | tr ',' ' '); do
    create_record "" "$IP"
  done

  # Wildcard A records
  for IP in $(echo "$IPS" | tr ',' ' '); do
    create_record "*" "$IP"
  done

  # Service wildcard records
  if [ -n "$CLUSTER_NAME" ] && [ -n "$SERVICES" ]; then
    for SVC in $(echo "$SERVICES" | tr ',' ' '); do
      for IP in $(echo "$IPS" | tr ',' ' '); do
        create_record "*.${SVC}.${CLUSTER_NAME}" "$IP"
      done
    done
  fi

  log "Done. Created: ${CREATED}, Skipped: ${SKIPPED}"

elif [ "$ACTION" = "delete" ]; then
  log "Deleting DNS records for ${DOMAIN}..."

  delete_records_by_name ""
  delete_records_by_name "*"

  if [ -n "$CLUSTER_NAME" ] && [ -n "$SERVICES" ]; then
    for SVC in $(echo "$SERVICES" | tr ',' ' '); do
      delete_records_by_name "*.${SVC}.${CLUSTER_NAME}"
    done
  fi

  log "Done. Deleted records for ${DOMAIN}"
else
  log "ERROR: Unknown action: ${ACTION}. Use 'create' or 'delete'."
  exit 1
fi
