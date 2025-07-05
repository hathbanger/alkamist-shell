# ~/.config/alkamist/functions.sh

decode() {
  local hex="${1}"

  if [ -z "$hex" ]; then
    echo "Error: hex value is required"
    return 1
  fi

  hex="${hex#0x}" # strip leading 0x if present

  # Is it a valid number? Only hex digits and max 16 chars (u64)
  if [[ "$hex" =~ ^[0-9a-fA-F]{1,16}$ ]]; then
    echo $((16#$hex))
    return 0
  fi

  # Try ASCII decoding for longer strings
  echo -n "$hex" | xxd -r -p
}

decode_le_u64() {
  local hex="${1#0x}"
  local little_endian=$(echo "$hex" | head -c 16 | sed 's/../& /g' | awk '{for(i=8;i>=1;i--) printf $i} END {print ""}')
  echo $((16#$little_endian))
}

get-alkane() {
  local target="$1"
  local network="${2:-oylnet}"

  if [ -z "$target" ]; then
    echo "Error: target address is required"
    echo "Usage: get-alkane <block:tx> [network]"
    return 1
  fi

  local get_string() {
    local opcode="$1"
    oyl alkane simulate -target "$target" -inputs "$opcode" -p "$network" 2>/dev/null \
      | jq -r 'select(.status == 0) | .parsed.string // empty'
  }

  local get_le() {
    local opcode="$1"
    oyl alkane simulate -target "$target" -inputs "$opcode" -p "$network" 2>/dev/null \
      | jq -r 'select(.status == 0) | .parsed.le // empty'
  }

  local name symbol total_supply cap initialized value_per_mint

  name=$(get_string 99)
  symbol=$(get_string 100)
  total_supply=$(get_le 101)
  cap=$(get_le 102)
  initialized=$(get_le 103)
  value_per_mint=$(get_le 104)

  # Format decimal values (if present)
  if [[ -n "$total_supply" ]]; then
    total_supply_fmt=$(printf "%.8f" "$(bc -l <<< "$total_supply / 100000000")")
  fi

  if [[ -n "$value_per_mint" ]]; then
    value_per_mint_fmt=$(printf "%.8f" "$(bc -l <<< "$value_per_mint / 100000000")")
  fi

  echo "Alkane at: $target"
  echo "Name: ${name:-<unset>}"
  echo "Symbol: ${symbol:-<unset>}"
  echo "Cap: ${cap:-<unset>}"
  echo "Total Supply: ${total_supply_fmt:-<unset>}"
  echo "Value per Mint: ${value_per_mint_fmt:-<unset>}"
  echo "Initialized: ${initialized:-<unset>}"
}

new-token-trace() {
  local txid="$1"

  if [ -z "$txid" ]; then
    echo "Error: txid is required"
    echo "Usage: new-token <txid>"
    return 1
  fi

  local trace_output
  trace_output="$(trace "$txid" 4)"

  if [ -z "$trace_output" ]; then
    echo "Error: Failed to get trace output"
    return 1
  fi

  # Extract values
  local name_hex symbol_hex cap_hex supply_hex vpm_hex
  local block_hex tx_hex

  name_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "return").data.response.storage[] | select(.key == "/name") | .value')
  symbol_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "return").data.response.storage[] | select(.key == "/symbol") | .value')
  cap_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "return").data.response.storage[] | select(.key == "/cap") | .value')
  supply_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "return").data.response.storage[] | select(.key == "/totalsupply") | .value')
  vpm_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "return").data.response.storage[] | select(.key == "/76616c75652d7065722d6d696e74") | .value')

  block_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "create").data.block')
  tx_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "create").data.tx')

  # Decode
  local name symbol cap supply vpm contract_address

  name=$(decode "$name_hex")
  symbol=$(decode "$symbol_hex")
  cap=$(decode_le_u64 "$cap_hex")
  raw_supply=$(decode_le_u64 "$supply_hex")
  raw_vpm=$(decode_le_u64 "$vpm_hex")

  supply=$(printf "%.8f" "$(bc -l <<<"$raw_supply / 100000000")")
  vpm=$(printf "%.8f" "$(bc -l <<<"$raw_vpm / 100000000")")

  contract_address="$((16#${block_hex#0x})):$((16#${tx_hex#0x}))"

  # Print summary
  echo "Contract Address: $contract_address"
  echo "Name: $name"
  echo "Symbol: $symbol"
  echo "Cap: $cap"
  echo "Total Supply: $supply"
  echo "Value per Mint: $vpm"
}

new-vault-trace() {
  local txid="$1"

  if [ -z "$txid" ]; then
    echo "Error: txid is required"
    echo "Usage: new-vault <txid>"
    return 1
  fi

  local trace_output
  trace_output="$(trace "$txid")"

  if [ -z "$trace_output" ] || [[ "$trace_output" == "[]" ]]; then
    echo "Error: Could not find vault trace"
    return 1
  fi

  local block_hex tx_hex contract_address

  block_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "create").data.block')
  tx_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "create").data.tx')

  contract_address="$((16#${block_hex#0x})):$((16#${tx_hex#0x}))"

  echo "Vault Contract Address: $contract_address"
}

trace() {
  local txid="$1"
  local network="${2:-oylnet}"

  if [ -z "$txid" ]; then
    echo "Error: txid is required"
    echo "Usage: trace <txid> [network]"
    return 1
  fi

  local output
  for vout in {0..6}; do
    output=$(oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "$network")
    if [[ "$output" != "[]" && -n "$output" ]]; then
      echo "$output"
      return 0
    fi
  done

  echo "No results from vout 0–6. Generating a block and retrying..." >&2
  gen >&2

  for vout in {0..6}; do
    output=$(oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "$network")
    if [[ "$output" != "[]" && -n "$output" ]]; then
      echo "$output"
      return 0
    fi
  done

  echo "Still no result after generating a block." >&2
  return 1
}
