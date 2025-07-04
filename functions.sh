# ~/.config/alkamist/functions.sh

decode() {
  local hex="${1}"
  if [ -z "$hex" ]; then
    echo "Error: hex value is required"
    return 1
  fi

  hex="${hex#0x}" # strip 0x

  # Try to decode ASCII if all bytes are printable characters
  if [[ "$hex" =~ ^([0-7][0-9a-f])+$ ]]; then
    echo -n "$hex" | xxd -r -p
    echo
  elif [[ "$hex" =~ ^[[:xdigit:]]{1,16}$ ]]; then
    echo $((16#$hex))
  else
    echo -n "$hex" | xxd -r -p
  fi
}

new-token() {
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

  block_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "create").data.block')
  tx_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "create").data.tx')

  # Decode
  local name symbol cap supply vpm contract_address

  name=$(decode "$name_hex")
  symbol=$(decode "$symbol_hex")

  contract_address="$((16#${block_hex#0x})):$((16#${tx_hex#0x}))"

  # Print summary
  echo "Contract Address: $contract_address"
  echo "Name: $name"
  echo "Symbol: $symbol"
}

trace() {
  local txid="${1}"
  local vout="${2:-4}"
  local network="${3:-oylnet}"

  if [ -z "$txid" ]; then
    echo "Error: txid is required"
    echo "Usage: trace <txid> [vout] [network]"
    return 1
  fi

  oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "${network}"
}
