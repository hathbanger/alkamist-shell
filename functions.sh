# ~/.config/alkamist/functions.sh

decode() {
  local hex="${1}"
  hex="${hex#0x}"

  if [[ -z "$hex" ]]; then
    echo "<empty>"
    return 1
  fi

  if [[ "$hex" =~ ^[0-9a-fA-F]{1,16}$ ]]; then
    echo $((16#$hex))
    return 0
  fi

  # Decode hex to string
  local decoded
  decoded=$(echo -n "$hex" | xxd -r -p 2>/dev/null)
  
  if [ -z "$decoded" ]; then
    echo "<decode-failed>"
    return 1
  fi
  
  # Check if it's a Solidity revert message (starts with 0x08c379a0)
  if [[ "$hex" =~ ^08c379a0 ]]; then
    # For Solidity revert messages, extract just the string part
    # Skip the function selector (4 bytes) and ABI encoding overhead
    local message_hex="${hex:8}" # Skip function selector
    local decoded_message
    decoded_message=$(echo -n "$message_hex" | xxd -r -p 2>/dev/null)
    
    # Extract readable part (usually starts after some ABI encoding bytes)
    echo "$decoded_message" | sed 's/.*ALKANES:/ALKANES:/' | tr -d '\0'
  else
    # For other hex strings, clean up control characters
    echo "$decoded" | tr -d '\0' | LC_ALL=C sed 's/[[:cntrl:]]//g'
  fi
}


decode_le_u64() {
  local hex="${1#0x}"

  if [[ -z "$hex" || "$hex" =~ [^0-9a-fA-F] ]]; then
    echo 0
    return
  fi

  # Ensure even length
  if (( ${#hex} % 2 != 0 )); then
    hex="0$hex"
  fi

  local reversed
  reversed=$(echo "$hex" | sed 's/../& /g' | awk '{for(i=NF;i>=1;i--) printf $i}')

  if [[ -z "$reversed" ]]; then
    echo 0
    return
  fi

  echo $((16#$reversed))
}


encode() {
  local decimal="$1"

  if [ -z "$decimal" ]; then
    echo "Error: decimal value required"
    echo "Usage: encode <number>"
    return 1
  fi

  # Convert to hex (trimmed, no padding, big-endian)
  local hex
  hex=$(printf "%x" "$decimal")

  echo "0x$hex"
}

gen() {
  local count="${1:-1}"  # default to 1 if not provided

  for ((i = 1; i <= count; i++)); do
    oyl regtest genBlocks -p oylnet
  done
}

get-alkane() {
  local target="$1"
  local network="${2:-oylnet}"

  if [ -z "$target" ]; then
    echo "Error: target address is required"
    echo "Usage: get-alkane <block:tx> [network]"
    return 1
  fi

  get_string() {
    local opcode="$1"
    oyl alkane simulate -target "$target" -inputs "$opcode" -p "$network" 2>/dev/null \
      | jq -r 'select(.status == 0) | .parsed.string // empty'
  }

  get_le() {
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
    echo "Usage: new-token-trace <txid>"
    return 1
  fi

  local trace_output
  trace_output="$(trace "$txid")"

  if ! echo "$trace_output" | jq empty >/dev/null 2>&1; then
    echo "Error: Invalid JSON returned from trace"
    echo "$trace_output"
    return 1
  fi

  # Extract relevant hex values
  local name_hex symbol_hex cap_hex supply_hex vpm_hex block_hex tx_hex
  name_hex=$(echo "$trace_output" | jq -r '.[]? | select(.event == "return").data.response.storage[]? | select(.key == "/name") | .value // ""')
  symbol_hex=$(echo "$trace_output" | jq -r '.[]? | select(.event == "return").data.response.storage[]? | select(.key == "/symbol") | .value // ""')
  cap_hex=$(echo "$trace_output" | jq -r '.[]? | select(.event == "return").data.response.storage[]? | select(.key == "/cap") | .value // ""')
  supply_hex=$(echo "$trace_output" | jq -r '.[]? | select(.event == "return").data.response.storage[]? | select(.key == "/totalsupply") | .value // ""')
  vpm_hex=$(echo "$trace_output" | jq -r '.[]? | select(.event == "return").data.response.storage[]? | select(.key == "/76616c75652d7065722d6d696e74") | .value // ""')

  block_hex=$(echo "$trace_output" | jq -r '.[]? | select(.event == "create").data.block // "0x0"')
  tx_hex=$(echo "$trace_output" | jq -r '.[]? | select(.event == "create").data.tx // "0x0"')

  # Safely decode values
  local name symbol cap raw_supply raw_vpm supply vpm
  name=$( [ -n "$name_hex" ] && decode "$name_hex" || echo "<none>" )
  symbol=$( [ -n "$symbol_hex" ] && decode "$symbol_hex" || echo "<none>" )
  cap=$( [ -n "$cap_hex" ] && decode_le_u64 "$cap_hex" || echo 0 )
  raw_supply=$( [ -n "$supply_hex" ] && decode_le_u64 "$supply_hex" || echo 0 )
  raw_vpm=$( [ -n "$vpm_hex" ] && decode_le_u64 "$vpm_hex" || echo 0 )

  # Format decimal values
  supply=$(printf "%.8f" "$(bc -l <<< "$raw_supply / 100000000")")
  vpm=$(printf "%.8f" "$(bc -l <<< "$raw_vpm / 100000000")")

  # Decode contract address
  local contract_address="$((16#${block_hex#0x})):$((16#${tx_hex#0x}))"

  # Output
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

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed. Please install jq."
    return 1
  fi

  local try_trace_output
  local output
  local all_traces=""
  local trace_count=0
  
  # Try outputs 0-9
  for vout in {0..9}; do
    try_trace_output=$(oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "$network" 2>&1)
    output=$(echo "$try_trace_output" | awk '/^\[/{flag=1} flag')
    if echo "$output" | jq empty >/dev/null 2>&1; then
      if [[ "$output" != "[]" && -n "$output" ]]; then
        if [ $trace_count -gt 0 ]; then
          # Multiple traces - add separator
          all_traces="${all_traces}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Output #$vout:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
        fi
        
        # Check if it's a revert and enhance the output
        local tx_status
        tx_status=$(echo "$output" | jq -r '.[] | select(.event == "return").data.status // empty' 2>/dev/null)
        
        if [ "$tx_status" = "revert" ]; then
          all_traces="${all_traces}🚫 Transaction Reverted${trace_count:+ (vout: $vout)}

"
          # Decode the revert reason
          local revert_data
          revert_data=$(echo "$output" | jq -r '.[] | select(.event == "return").data.response.data // empty' 2>/dev/null)
          
          if [ -n "$revert_data" ]; then
            local decoded_error
            decoded_error=$(decode "$revert_data")
            all_traces="${all_traces}Error: $decoded_error

"
          fi
          
          all_traces="${all_traces}Full trace:
$(echo "$output" | jq)"
        else
          all_traces="${all_traces}$(echo "$output" | jq)"
        fi
        
        trace_count=$((trace_count + 1))
      fi
    fi
  done

  if [ $trace_count -gt 0 ]; then
    if [ $trace_count -gt 1 ]; then
      echo "📋 Found $trace_count traces for transaction $txid"
      echo ""
    fi
    echo "$all_traces"
    return 0
  fi

  # No traces found, generate a block and retry
  echo "No results from vout 0–9. Generating a block and retrying..." >&2
  gen >&2

  all_traces=""
  trace_count=0
  
  for vout in {0..9}; do
    try_trace_output=$(oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "$network" 2>&1)
    output=$(echo "$try_trace_output" | awk '/^\[/{flag=1} flag')
    if echo "$output" | jq empty >/dev/null 2>&1; then
      if [[ "$output" != "[]" && -n "$output" ]]; then
        if [ $trace_count -gt 0 ]; then
          # Multiple traces - add separator
          all_traces="${all_traces}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Output #$vout:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
        fi
        
        # Check if it's a revert and enhance the output
        local tx_status
        tx_status=$(echo "$output" | jq -r '.[] | select(.event == "return").data.status // empty' 2>/dev/null)
        
        if [ "$tx_status" = "revert" ]; then
          all_traces="${all_traces}🚫 Transaction Reverted${trace_count:+ (vout: $vout)}

"
          # Decode the revert reason
          local revert_data
          revert_data=$(echo "$output" | jq -r '.[] | select(.event == "return").data.response.data // empty' 2>/dev/null)
          
          if [ -n "$revert_data" ]; then
            local decoded_error
            decoded_error=$(decode "$revert_data")
            all_traces="${all_traces}Error: $decoded_error

"
          fi
          
          all_traces="${all_traces}Full trace:
$(echo "$output" | jq)"
        else
          all_traces="${all_traces}$(echo "$output" | jq)"
        fi
        
        trace_count=$((trace_count + 1))
      fi
    fi
  done

  if [ $trace_count -gt 0 ]; then
    if [ $trace_count -gt 1 ]; then
      echo "📋 Found $trace_count traces for transaction $txid"
      echo ""
    fi
    echo "$all_traces"
    return 0
  fi

  echo "Still no result after generating a block." >&2
  return 1
}

vault-info() {
  local tx="$1"
  local network="${2:-oylnet}"

  if [ -z "$tx" ]; then
    echo "Usage: vault-info <tx> [network]"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq is required but not installed."
    return 1
  fi

  local contract="4:$tx"

  simulate() {
    oyl alkane simulate -target "$contract" -inputs "$1" -p "$network" 2>/dev/null
  }

  get_le_u128() {
    local opcode="$1"
    local hex
    hex=$(simulate "$opcode" | jq -r '.parsed.le // empty')
    echo "${hex:-0}"
  }

  get_le_u64() {
    local opcode="$1"
    local hex
    hex=$(simulate "$opcode" | jq -r '.parsed.le // empty')
    echo "${hex:-0}"
  }

  echo "📦 Vault at: $contract"

  # Fetch values
  local cap total_staked reward_per_share pending_rewards alloc_point
  cap=$(get_le_u128 39)
  total_staked=$(get_le_u128 40)
  reward_per_share=$(get_le_u128 41)
  pending_rewards=$(get_le_u128 42)
  alloc_point=$(get_le_u64 43)

  # Format as readable BTC values
  local fmt_cap fmt_staked fmt_reward_share fmt_pending
  fmt_cap=$(printf "%.8f" "$(bc -l <<< "$cap / 100000000")")
  fmt_staked=$(printf "%.8f" "$(bc -l <<< "$total_staked / 100000000")")
  fmt_reward_share=$(printf "%.8f" "$(bc -l <<< "$reward_per_share / 100000000")")
  fmt_pending=$(printf "%.8f" "$(bc -l <<< "$pending_rewards / 100000000")")

  echo "💰 Cap: $fmt_cap"
  echo "📈 Total Staked: $fmt_staked"
  echo "🎁 Acc. Reward/Share: $fmt_reward_share"
  echo "🕑 Pending Reward Balance: $fmt_pending"
  echo "📊 Allocation Point: $alloc_point"

  # Registered children (opcode 32)
  local sim_out raw_data
  sim_out=$(simulate 32)
  raw_data=$(echo "$sim_out" | jq -r '.parsed.bytes // empty')

  if [ -z "$raw_data" ] || [ "$raw_data" = "null" ]; then
    echo "🧒 Registered Children: 0"
    return 0
  fi

  local hex="${raw_data#0x}"
  local count_hex="${hex:0:16}"
  local count_hex_spaced=$(echo "$count_hex" | sed 's/\(..\)/\1 /g')
  local count_dec=$((16#$(echo "$count_hex_spaced" | awk '{for(i=8;i>=1;i--) printf $i}')))

  echo "🧒 Registered Children: $count_dec"

  if [ "$count_dec" -eq 0 ]; then
    return 0
  fi

  local offset=16
  local i=1

  while [ "$i" -le "$count_dec" ]; do
    local block_le="${hex:$offset:32}"
    local tx_le="${hex:$((offset + 32)):32}"

    local block_hex_spaced=$(echo "$block_le" | sed 's/\(..\)/\1 /g')
    local tx_hex_spaced=$(echo "$tx_le" | sed 's/\(..\)/\1 /g')

    local block_dec=$((16#$(echo "$block_hex_spaced" | awk '{for(j=16;j>=1;j--) printf $j}')))
    local tx_dec=$((16#$(echo "$tx_hex_spaced" | awk '{for(j=16;j>=1;j--) printf $j}')))

    echo "  - Child $i: $block_dec:$tx_dec"

    offset=$((offset + 64))
    i=$((i + 1))
  done
}

# Alkamon Token Functions

heal() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: heal <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane execute -data "2,$token_id,3" -p "$network" 2>&1)
  
  # Check if result contains txId (success case)
  if echo "$result" | grep -q "txId"; then
    echo "$result"
    gen
    
    # Extract txId for tracing
    local txid
    txid=$(echo "$result" | grep "txId:" | sed "s/.*txId: '\([^']*\)'.*/\1/")
    
    if [ -n "$txid" ]; then
      echo "\nTracing transaction $txid..."
      trace "$txid" "$network"
    fi
  else
    echo "Transaction failed:"
    echo "$result"
    return 1
  fi
}

candy() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: candy <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane execute -data "2,$token_id,4" -p "$network" 2>&1)
  
  # Check if result contains txId (success case)
  if echo "$result" | grep -q "txId"; then
    echo "$result"
    gen
    
    # Extract txId for tracing
    local txid
    txid=$(echo "$result" | grep "txId:" | sed "s/.*txId: '\([^']*\)'.*/\1/")
    
    if [ -n "$txid" ]; then
      echo "\nTracing transaction $txid..."
      trace "$txid" "$network"
    fi
  else
    echo "Transaction failed:"
    echo "$result"
    return 1
  fi
}

id() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: id <token_id> [network]"
    return 1
  fi
  
  # Run the command and extract just the le value
  oyl alkane simulate -target "2:$token_id" -inputs "10" -p "$network" 2>/dev/null | jq -r '.parsed.le // empty'
}

level() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: level <token_id> [network]"
    return 1
  fi
  
  # Run the command and extract just the le value
  oyl alkane simulate -target "2:$token_id" -inputs "11" -p "$network" 2>/dev/null | jq -r '.parsed.le // empty'
}

exp() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: exp <token_id> [network]"
    return 1
  fi
  
  # Run the command and extract just the le value
  oyl alkane simulate -target "2:$token_id" -inputs "12" -p "$network" 2>/dev/null | jq -r '.parsed.le // empty'
}

hp() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: hp <token_id> [network]"
    return 1
  fi
  
  # Run the command and extract just the le value
  oyl alkane simulate -target "2:$token_id" -inputs "13" -p "$network" 2>/dev/null | jq -r '.parsed.le // empty'
}

ivs() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: ivs <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "14" -p "$network" 2>/dev/null)
  local raw_data
  raw_data=$(echo "$result" | jq -r '.execution.data // .parsed.bytes // empty')
  
  if [ -z "$raw_data" ] || [ "$raw_data" = "null" ]; then
    echo "No IVs data found"
    return 1
  fi
  
  # Decode the hex to JSON
  local json_data
  json_data=$(echo "${raw_data#0x}" | xxd -r -p 2>/dev/null)
  
  if [ -z "$json_data" ]; then
    echo "Failed to decode IVs data"
    return 1
  fi
  
  # Parse JSON and display
  echo "IVs:"
  echo "  HP: $(echo "$json_data" | jq -r '.hp // 0')"
  echo "  Attack: $(echo "$json_data" | jq -r '.attack // 0')"
  echo "  Defense: $(echo "$json_data" | jq -r '.defense // 0')"
  echo "  Sp. Attack: $(echo "$json_data" | jq -r '.special_attack // 0')"
  echo "  Sp. Defense: $(echo "$json_data" | jq -r '.special_defense // 0')"
  echo "  Speed: $(echo "$json_data" | jq -r '.speed // 0')"
}

evs() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: evs <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "15" -p "$network" 2>/dev/null)
  local raw_data
  raw_data=$(echo "$result" | jq -r '.execution.data // .parsed.bytes // empty')
  
  if [ -z "$raw_data" ] || [ "$raw_data" = "null" ]; then
    echo "No EVs data found"
    return 1
  fi
  
  # Decode the hex to JSON
  local json_data
  json_data=$(echo "${raw_data#0x}" | xxd -r -p 2>/dev/null)
  
  if [ -z "$json_data" ]; then
    echo "Failed to decode EVs data"
    return 1
  fi
  
  # Parse JSON and display
  echo "EVs:"
  echo "  HP: $(echo "$json_data" | jq -r '.hp // 0')"
  echo "  Attack: $(echo "$json_data" | jq -r '.attack // 0')"
  echo "  Defense: $(echo "$json_data" | jq -r '.defense // 0')"
  echo "  Sp. Attack: $(echo "$json_data" | jq -r '.special_attack // 0')"
  echo "  Sp. Defense: $(echo "$json_data" | jq -r '.special_defense // 0')"
  echo "  Speed: $(echo "$json_data" | jq -r '.speed // 0')"
}

stats() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: stats <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "16" -p "$network" 2>/dev/null)
  local raw_data
  raw_data=$(echo "$result" | jq -r '.execution.data // .parsed.bytes // empty')
  
  if [ -z "$raw_data" ] || [ "$raw_data" = "null" ]; then
    echo "No base stats data found"
    return 1
  fi
  
  # Decode the hex to JSON
  local json_data
  json_data=$(echo "${raw_data#0x}" | xxd -r -p 2>/dev/null)
  
  if [ -z "$json_data" ]; then
    echo "Failed to decode base stats data"
    return 1
  fi
  
  # Parse JSON and display
  echo "Base Stats:"
  echo "  HP: $(echo "$json_data" | jq -r '.hp // 0')"
  echo "  Attack: $(echo "$json_data" | jq -r '.attack // 0')"
  echo "  Defense: $(echo "$json_data" | jq -r '.defense // 0')"
  echo "  Sp. Attack: $(echo "$json_data" | jq -r '.special_attack // 0')"
  echo "  Sp. Defense: $(echo "$json_data" | jq -r '.special_defense // 0')"
  echo "  Speed: $(echo "$json_data" | jq -r '.speed // 0')"
}

moves() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: moves <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "17" -p "$network" 2>/dev/null)
  
  # First try parsed.vec, then decode from hex if needed
  local moves_array
  moves_array=$(echo "$result" | jq -r '.parsed.vec // empty' 2>/dev/null)
  
  if [ -z "$moves_array" ] || [ "$moves_array" = "null" ] || [ "$moves_array" = "empty" ]; then
    # Try decoding from hex
    local raw_data
    raw_data=$(echo "$result" | jq -r '.execution.data // .parsed.bytes // empty' 2>/dev/null)
    
    if [ -n "$raw_data" ] && [ "$raw_data" != "null" ]; then
      local decoded
      decoded=$(echo "${raw_data#0x}" | xxd -r -p 2>/dev/null)
      if [ -n "$decoded" ]; then
        moves_array="$decoded"
      fi
    fi
  fi
  
  if [ -z "$moves_array" ] || [ "$moves_array" = "null" ]; then
    echo "No moves found"
    return 1
  fi
  
  # Check if it's JSON array or plain array
  if echo "$moves_array" | jq -e . >/dev/null 2>&1; then
    echo "Moves:"
    echo "$moves_array" | jq -r '.[] | "  - \(.)"'
  else
    echo "Moves:"
    echo "$moves_array"
  fi
}

types() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: types <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "18" -p "$network" 2>/dev/null)
  
  # First try parsed.vec, then decode from hex if needed
  local types_array
  types_array=$(echo "$result" | jq -r '.parsed.vec // empty' 2>/dev/null)
  
  if [ -z "$types_array" ] || [ "$types_array" = "null" ] || [ "$types_array" = "empty" ]; then
    # Try decoding from hex
    local raw_data
    raw_data=$(echo "$result" | jq -r '.execution.data // .parsed.bytes // empty' 2>/dev/null)
    
    if [ -n "$raw_data" ] && [ "$raw_data" != "null" ]; then
      local decoded
      decoded=$(echo "${raw_data#0x}" | xxd -r -p 2>/dev/null)
      if [ -n "$decoded" ]; then
        types_array="$decoded"
      fi
    fi
  fi
  
  if [ -z "$types_array" ] || [ "$types_array" = "null" ]; then
    echo "No types found"
    return 1
  fi
  
  # Check if it's JSON array or plain array
  if echo "$types_array" | jq -e . >/dev/null 2>&1; then
    echo "Types:"
    echo "$types_array" | jq -r '.[] | "  - \(.)"'
  else
    echo "Types:"
    echo "$types_array"
  fi
}

name() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: name <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "99" -p "$network" 2>/dev/null)
  echo "$result" | jq -r '.parsed.string // empty'
}

symbol() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: symbol <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "100" -p "$network" 2>/dev/null)
  echo "$result" | jq -r '.parsed.string // empty'
}

data() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: data <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "1000" -p "$network" 2>/dev/null)
  echo "$result" | jq -r '.parsed.bytes // empty'
}

attr() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: attr <token_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane simulate -target "2:$token_id" -inputs "1002" -p "$network" 2>/dev/null)
  echo "$result" | jq -r '.parsed.string // empty'
}

train() {
  local token_id="$1"
  local opponent_type="$2"
  local network="${3:-oylnet}"
  
  if [ -z "$token_id" ] || [ -z "$opponent_type" ]; then
    echo "Usage: train <token_id> <opponent_type> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane execute -data "2,$token_id,21,$opponent_type" -p "$network" 2>&1)
  
  # Check if result contains txId (success case)
  if echo "$result" | grep -q "txId"; then
    echo "$result"
    gen
    
    # Extract txId for tracing
    local txid
    txid=$(echo "$result" | grep "txId:" | sed "s/.*txId: '\([^']*\)'.*/\1/")
    
    if [ -n "$txid" ]; then
      echo "\nTracing transaction $txid..."
      parse_training_trace "$txid" "$network"
    fi
  else
    echo "Transaction failed:"
    echo "$result"
    return 1
  fi
}

# Parse training trace with battle log formatting
parse_training_trace() {
  local txid="$1"
  local network="${2:-oylnet}"
  
  # Get raw trace data directly from oyl command
  local trace_result
  for vout in {0..6}; do
    local try_trace_output
    try_trace_output=$(oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "$network" 2>&1)
    trace_result=$(echo "$try_trace_output" | awk '/^\[/{flag=1} flag')
    if echo "$trace_result" | jq empty >/dev/null 2>&1; then
      if [[ "$trace_result" != "[]" && -n "$trace_result" ]]; then
        break
      fi
    fi
  done
  
  if [ -z "$trace_result" ] || [ "$trace_result" = "[]" ]; then
    echo "Failed to get trace data"
    return 1
  fi
  
  # Check if it's a revert
  local tx_status
  tx_status=$(echo "$trace_result" | jq -r '.[] | select(.event == "return").data.status // empty' 2>/dev/null)
  
  if [ "$tx_status" = "revert" ]; then
    echo "🚫 Training Failed - Transaction Reverted"
    echo ""
    
    # Decode the revert reason
    local revert_data
    revert_data=$(echo "$trace_result" | jq -r '.[] | select(.event == "return").data.response.data // empty' 2>/dev/null)
    
    if [ -n "$revert_data" ]; then
      local decoded_error
      decoded_error=$(decode "$revert_data")
      echo "💥 Error: $decoded_error"
    fi
    
    echo ""
    echo "💡 Common causes:"
    echo "   - Not enough fuel (try again)"
    echo "   - Insufficient DUST tokens"
    echo "   - Invalid opponent type (use 1-18)"
    echo "   - Alkamon may be fainted (try healing first)"
    echo ""
    return 1
  fi
  
  # Parse successful training
  local battle_data
  battle_data=$(echo "$trace_result" | jq -r '.[] | select(.event == "return").data.response.data // empty' 2>/dev/null)
  
  if [ -z "$battle_data" ]; then
    echo "No battle data found in trace"
    return 1
  fi
  
  # Decode the hex data to JSON
  local json_data
  json_data=$(echo "${battle_data#0x}" | xxd -r -p 2>/dev/null)
  
  if [ -z "$json_data" ]; then
    echo "Failed to decode battle data"
    return 1
  fi
  
  # Parse and display battle results
  echo "⚔️  Training Battle Results"
  echo "=================================="
  echo ""
  
  # Winner
  local winner
  winner=$(echo "$json_data" | jq -r '.winner // "Unknown"')
  echo "🏆 Winner: $winner"
  
  # Battle stats
  local turns
  turns=$(echo "$json_data" | jq -r '.total_turns // 0')
  echo "🔄 Total Turns: $turns"
  
  local training_count
  training_count=$(echo "$json_data" | jq -r '.training_count // 0')
  echo "📊 Training Count: $training_count"
  
  # DUST costs
  local dust_cost
  dust_cost=$(echo "$json_data" | jq -r '.dust_cost // 0')
  echo "💰 DUST Cost: $dust_cost"
  
  # HP status
  local current_hp max_hp
  current_hp=$(echo "$json_data" | jq -r '.current_hp // 0')
  max_hp=$(echo "$json_data" | jq -r '.max_hp // 0')
  echo "❤️  HP After Battle: $current_hp/$max_hp"
  
  # Experience gained
  local exp_gained total_exp
  exp_gained=$(echo "$json_data" | jq -r '.exp_gained // 0')
  total_exp=$(echo "$json_data" | jq -r '.total_exp // 0')
  echo "⭐ EXP Gained: +$exp_gained (Total: $total_exp)"
  
  # EV gains
  local ev_gains
  ev_gains=$(echo "$json_data" | jq -r '.ev_gains // empty')
  if [ -n "$ev_gains" ] && [ "$ev_gains" != "null" ]; then
    echo ""
    echo "📈 EV Gains:"
    echo "$ev_gains" | jq -r 'to_entries[] | "  \(.key | ascii_upcase): +\(.value)"'
  fi
  
  # Total EVs
  local total_evs
  total_evs=$(echo "$json_data" | jq -r '.total_evs // empty')
  if [ -n "$total_evs" ] && [ "$total_evs" != "null" ]; then
    echo ""
    echo "🔢 Total EVs:"
    echo "$total_evs" | jq -r 'to_entries[] | select(.key != "total") | "  \(.key | ascii_upcase): \(.value)"'
    local total_ev_sum
    total_ev_sum=$(echo "$total_evs" | jq -r '.total // 0')
    echo "  TOTAL: $total_ev_sum/510"
  fi
  
  # Battle log
  local battle_log
  battle_log=$(echo "$json_data" | jq -r '.battle_log // empty')
  if [ -n "$battle_log" ] && [ "$battle_log" != "null" ]; then
    echo ""
    echo "⚔️  Battle Log:"
    echo "---------------"
    
    # Parse each turn
    echo "$battle_log" | jq -r '.[] | "Turn \(.turn): \(.attacker) used \(.move_used)! \(if .effectiveness != 1.0 then "(\(.effectiveness)x effectiveness) " else "" end)Dealt \(.damage) damage to \(.defender) (HP: \(.defender_hp))"'
  fi
  
  echo ""
  echo "=================================="
}

# Initialize function
init() {
  local factory_id="$1"
  local alkamon_factory_id="$2"
  local network="${3:-oylnet}"
  
  if [ -z "$factory_id" ] || [ -z "$alkamon_factory_id" ]; then
    echo "Usage: init <factory_id> <alkamon_factory_id> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane execute -data "4,$factory_id,0,2,12253,2,12253,0,0,$alkamon_factory_id" -p "$network" 2>&1)
  
  # Check if result contains txId (success case)
  if echo "$result" | grep -q "txId"; then
    echo "$result"
    gen
    
    # Extract txId for tracing
    local txid
    txid=$(echo "$result" | grep "txId:" | sed "s/.*txId: '\([^']*\)'.*/\1/")
    
    if [ -n "$txid" ]; then
      echo ""
      echo "Tracing init transaction $txid..."
      trace "$txid" "$network"
    fi
  else
    echo "Init failed:"
    echo "$result"
    return 1
  fi
}

# Summon function
summon() {
  local summon_type="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$summon_type" ]; then
    echo "Usage: summon <type> [network]"
    return 1
  fi
  
  local result
  result=$(oyl alkane execute -data "4,$summon_type,1" -p "$network" 2>&1)
  
  # Check if result contains txId (success case)
  if echo "$result" | grep -q "txId"; then
    echo "$result"
    gen
    
    # Extract txId for tracing
    local txid
    txid=$(echo "$result" | grep "txId:" | sed "s/.*txId: '\([^']*\)'.*/\1/")
    
    if [ -n "$txid" ]; then
      echo ""
      echo "Tracing summon transaction $txid..."
      
      # Get trace data and parse it
      local trace_output
      for vout in {0..6}; do
        local try_trace_output
        try_trace_output=$(oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "$network" 2>&1)
        trace_output=$(echo "$try_trace_output" | awk '/^\[/{flag=1} flag')
        if echo "$trace_output" | jq empty >/dev/null 2>&1; then
          if [[ "$trace_output" != "[]" && -n "$trace_output" ]]; then
            break
          fi
        fi
      done
      
      if [ -n "$trace_output" ] && [ "$trace_output" != "[]" ]; then
        # Parse the summon results
        local alkamon_tx alkamon_name alkamon_symbol
        
        # Get the created alkamon's tx ID (convert from hex)
        alkamon_tx=$(echo "$trace_output" | jq -r '.[] | select(.event == "create").data.tx // empty' | head -1)
        if [ -n "$alkamon_tx" ]; then
          alkamon_tx=$((16#${alkamon_tx#0x}))
        fi
        
        # Get name and symbol from storage
        local name_hex symbol_hex
        name_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "return").data.response.storage[] | select(.key == "/name").value // empty' | head -1)
        symbol_hex=$(echo "$trace_output" | jq -r '.[] | select(.event == "return").data.response.storage[] | select(.key == "/symbol").value // empty' | head -1)
        
        if [ -n "$name_hex" ]; then
          alkamon_name=$(decode "$name_hex")
        fi
        
        if [ -n "$symbol_hex" ]; then
          alkamon_symbol=$(decode "$symbol_hex")
        fi
        
        # Display results
        echo ""
        echo "✨ SUMMON SUCCESSFUL!"
        echo "===================="
        echo "🎮 Alkamon: $alkamon_name [$alkamon_symbol]"
        echo "📍 Token ID: #$alkamon_tx"
        echo ""
        echo "You can now use commands like:"
        echo "  alkamon $alkamon_tx"
        echo "  train $alkamon_tx 1"
        echo "  heal $alkamon_tx"
        echo ""
      else
        echo "Failed to parse summon trace"
        return 1
      fi
    fi
  else
    echo "Summon failed:"
    echo "$result"
    return 1
  fi
}

# Simulate battle function
simulate() {
  local alkamon_id="$1"
  local opponent_level="$2"
  local network="${3:-oylnet}"
  
  if [ -z "$alkamon_id" ] || [ -z "$opponent_level" ]; then
    echo "Usage: simulate <alkamon_id> <opponent_level> [network]"
    return 1
  fi
  
  # Run the simulation and parse with jq
  oyl alkane simulate -target "2:$alkamon_id" -inputs "21,$opponent_level" -p "$network" | jq -r '
  # Get gas used and battle data
  . as $root |
  
  # Format gas with color if over 3.5M
  ($root.gasUsed | 
    if . > 3500000 then 
      "\u001b[31m\(.)\u001b[0m"  # Red color
    else 
      "\(.)" 
    end
  ) as $gas_display |
  
  # Extract the parsed battle data
  .parsed.string | fromjson | 
  
  # Create the battle summary
  "\n🎮 SIMULATE BATTLE SUMMARY\n" +
  "================\n" +
  "Winner: \(.winner)\n" +
  "Total Turns: \(.total_turns)\n" +
  "Gas Used: " + $gas_display + "\n" +
  "\n💰 REWARDS\n" +
  "=========\n" +
  "Experience Gained: \(.exp_gained)\n" +
  "Total Experience: \(.total_exp)\n" +
  "Dust Cost: \(.dust_cost)\n" +
  "\n📊 STATS\n" +
  "========\n" +
  "Current HP: \(.current_hp)/\(.max_hp)\n" +
  "EV Gains: " + (if .ev_gains | length > 0 then (.ev_gains | to_entries | map("\(.key): +\(.value)") | join(", ")) else "None" end) + "\n" +
  "Total EVs: Speed=\(.total_evs.speed) (Total: \(.total_evs.total))\n" +
  "\n⚔️  BATTLE LOG\n" +
  "============\n" +
  (.battle_log | map(
    "Turn \(.turn): \(.message)\n" +
    "  \(.defender): \(.defender_hp) HP (−\(.damage) damage)\n"
  ) | join("\n"))
  '
}

# Main Alkamon display function
alkamon() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: alkamon <token_id> [network]"
    return 1
  fi
  
  # Gather all data
  local token_name token_symbol token_level token_exp token_hp token_id_val
  token_name=$(name "$token_id" "$network")
  token_symbol=$(symbol "$token_id" "$network")
  token_level=$(level "$token_id" "$network")
  token_exp=$(exp "$token_id" "$network")
  token_hp=$(hp "$token_id" "$network")
  token_id_val=$(id "$token_id" "$network")
  
  # Get types and moves
  local token_types token_moves
  token_types=$(types "$token_id" "$network" 2>/dev/null)
  token_moves=$(moves "$token_id" "$network" 2>/dev/null)
  
  # Get stats
  local token_ivs token_evs token_stats
  token_ivs=$(ivs "$token_id" "$network" 2>/dev/null)
  token_evs=$(evs "$token_id" "$network" 2>/dev/null)
  token_stats=$(stats "$token_id" "$network" 2>/dev/null)
  
  # Extract individual stats first (we need them for HP calculation and the table)
  local base_hp=$(echo "$token_stats" | grep -E "^  HP:" | awk '{print $2}')
  local base_atk=$(echo "$token_stats" | grep -E "^  Attack:" | head -1 | awk '{print $2}')
  local base_def=$(echo "$token_stats" | grep -E "^  Defense:" | head -1 | awk '{print $2}')
  local base_spa=$(echo "$token_stats" | grep -E "^  Sp\\. Attack:" | awk '{print $3}')
  local base_spd=$(echo "$token_stats" | grep -E "^  Sp\\. Defense:" | awk '{print $3}')
  local base_spe=$(echo "$token_stats" | grep -E "^  Speed:" | awk '{print $2}')
  
  local iv_hp=$(echo "$token_ivs" | grep -E "^  HP:" | awk '{print $2}')
  local iv_atk=$(echo "$token_ivs" | grep -E "^  Attack:" | head -1 | awk '{print $2}')
  local iv_def=$(echo "$token_ivs" | grep -E "^  Defense:" | head -1 | awk '{print $2}')
  local iv_spa=$(echo "$token_ivs" | grep -E "^  Sp\\. Attack:" | awk '{print $3}')
  local iv_spd=$(echo "$token_ivs" | grep -E "^  Sp\\. Defense:" | awk '{print $3}')
  local iv_spe=$(echo "$token_ivs" | grep -E "^  Speed:" | awk '{print $2}')
  
  local ev_hp=$(echo "$token_evs" | grep -E "^  HP:" | awk '{print $2}')
  local ev_atk=$(echo "$token_evs" | grep -E "^  Attack:" | head -1 | awk '{print $2}')
  local ev_def=$(echo "$token_evs" | grep -E "^  Defense:" | head -1 | awk '{print $2}')
  local ev_spa=$(echo "$token_evs" | grep -E "^  Sp\\. Attack:" | awk '{print $3}')
  local ev_spd=$(echo "$token_evs" | grep -E "^  Sp\\. Defense:" | awk '{print $3}')
  local ev_spe=$(echo "$token_evs" | grep -E "^  Speed:" | awk '{print $2}')
  
  # Calculate max HP using the correct formula from the Rust code
  # Formula: ((2 * base_hp + iv_hp + (ev_hp / 4)) * level / 100) + level + 10
  
  # Calculate max HP
  local max_hp=$(( ((2 * ${base_hp:-48} + ${iv_hp:-0} + ${ev_hp:-0} / 4) * token_level / 100) + token_level + 10 ))
  
  # Display header
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                        ALKAMON DETAILS                         ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  
  # Basic info
  echo "🎮 ${token_name} [${token_symbol}]"
  echo "📍 Token ID: #${token_id} (Internal: ${token_id_val})"
  echo ""
  
  # Level and experience
  echo "📊 Level ${token_level}"
  local exp_bar_length=20
  local exp_to_next=$((token_level * token_level * 100))
  local exp_progress=$((token_exp * exp_bar_length / exp_to_next))
  [ $exp_progress -gt $exp_bar_length ] && exp_progress=$exp_bar_length
  
  printf "   EXP: ["
  for ((i=0; i<exp_bar_length; i++)); do
    if [ $i -lt $exp_progress ]; then
      printf "█"
    else
      printf "░"
    fi
  done
  printf "] %s\n" "$token_exp"
  
  # HP bar
  echo ""
  echo "❤️  HP: ${token_hp}/${max_hp}"
  local hp_bar_length=20
  local hp_progress=$((token_hp * hp_bar_length / max_hp))
  [ $hp_progress -gt $hp_bar_length ] && hp_progress=$hp_bar_length
  
  printf "   ["
  for ((i=0; i<hp_bar_length; i++)); do
    if [ $i -lt $hp_progress ]; then
      printf "█"
    else
      printf "░"
    fi
  done
  printf "]\n"
  
  # Types
  if [ -n "$token_types" ] && [ "$token_types" != "No types found" ]; then
    echo ""
    echo "🏷️  Types:"
    echo "$token_types"
  fi
  
  # Stats display
  echo ""
  echo "📈 Battle Stats:"
  echo "┌─────────────────┬────────┬────────┬────────┐"
  echo "│ Stat            │  Base  │   IV   │   EV   │"
  echo "├─────────────────┼────────┼────────┼────────┤"
  
  
  # Parse and display stats in a table
  if [ -n "$token_stats" ] && [ "$token_stats" != "No base stats data found" ]; then
    
    printf "│ %-15s │ %6s │ %6s │ %6s │\n" "HP" "${base_hp:-0}" "${iv_hp:-0}" "${ev_hp:-0}"
    printf "│ %-15s │ %6s │ %6s │ %6s │\n" "Attack" "${base_atk:-0}" "${iv_atk:-0}" "${ev_atk:-0}"
    printf "│ %-15s │ %6s │ %6s │ %6s │\n" "Defense" "${base_def:-0}" "${iv_def:-0}" "${ev_def:-0}"
    printf "│ %-15s │ %6s │ %6s │ %6s │\n" "Sp. Attack" "${base_spa:-0}" "${iv_spa:-0}" "${ev_spa:-0}"
    printf "│ %-15s │ %6s │ %6s │ %6s │\n" "Sp. Defense" "${base_spd:-0}" "${iv_spd:-0}" "${ev_spd:-0}"
    printf "│ %-15s │ %6s │ %6s │ %6s │\n" "Speed" "${base_spe:-0}" "${iv_spe:-0}" "${ev_spe:-0}"
  fi
  echo "└─────────────────┴────────┴────────┴────────┘"
  
  # Moves
  if [ -n "$token_moves" ] && [ "$token_moves" != "No moves found" ]; then
    echo ""
    echo "⚔️  Moves:"
    echo "$token_moves"
  fi
  
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
}

# Continuous alkamon monitoring
alkamon-check() {
  local token_id="$1"
  local network="${2:-oylnet}"
  
  if [ -z "$token_id" ]; then
    echo "Usage: alkamon-check <token_id> [network]"
    return 1
  fi
  
  echo "Monitoring Alkamon #$token_id (Press Ctrl+C to stop)..."
  echo "================================================"
  
  while true; do
    alkamon "$token_id" "$network"
    echo ""
    echo "Refreshing in 2 seconds..."
    sleep 2
    echo ""
    echo "================================================"
  done
}

# P2P Battle function
p2p() {
  local contract_id="$1"
  local player1_id="$2"
  local player2_id="$3"
  local network="${4:-oylnet}"
  
  if [ -z "$contract_id" ] || [ -z "$player1_id" ] || [ -z "$player2_id" ]; then
    echo "Usage: p2p <contract_id> <player1_token_id> <player2_token_id> [network]"
    echo "Example: p2p 11438 0 1"
    return 1
  fi
  
  echo "⚔️  Initiating P2P Battle..."
  echo "Contract: #$contract_id"
  echo "Player 1: Token #$player1_id"
  echo "Player 2: Token #$player2_id"
  echo ""
  
  # Execute the battle transaction
  local result
  result=$(oyl alkane execute -data "4,$contract_id,$player1_id,$player2_id,1,2,2" -p "$network" 2>&1)
  
  if echo "$result" | grep -q "txId"; then
    echo "$result"
    gen
    
    # Extract txId for tracing
    local txid
    txid=$(echo "$result" | grep "txId:" | sed "s/.*txId: '\([^']*\)'.*/\1/")
    
    if [ -n "$txid" ]; then
      echo ""
      echo "Tracing battle transaction $txid..."
      parse_p2p_trace "$txid" "$network"
    fi
  else
    echo "Battle failed:"
    echo "$result"
    return 1
  fi
}

# Parse P2P battle trace
parse_p2p_trace() {
  local txid="$1"
  local network="${2:-oylnet}"
  
  # Get raw trace data
  local trace_result
  for vout in {0..6}; do
    local try_trace_output
    try_trace_output=$(oyl provider alkanes -method "trace" -params "{\"txid\": \"${txid}\", \"vout\": ${vout}}" -p "$network" 2>&1)
    trace_result=$(echo "$try_trace_output" | awk '/^\[/{flag=1} flag')
    if echo "$trace_result" | jq empty >/dev/null 2>&1; then
      if [[ "$trace_result" != "[]" && -n "$trace_result" ]]; then
        break
      fi
    fi
  done
  
  if [ -z "$trace_result" ] || [ "$trace_result" = "[]" ]; then
    echo "Failed to get trace data"
    return 1
  fi
  
  # Check if it's a revert
  local tx_status
  tx_status=$(echo "$trace_result" | jq -r '.[] | select(.event == "return").data.status // empty' 2>/dev/null | tail -1)
  
  if [ "$tx_status" = "revert" ]; then
    echo "🚫 Battle Failed - Transaction Reverted"
    echo ""
    
    local revert_data
    revert_data=$(echo "$trace_result" | jq -r '.[] | select(.event == "return" and .data.status == "revert").data.response.data // empty' 2>/dev/null | tail -1)
    
    if [ -n "$revert_data" ]; then
      local decoded_error
      decoded_error=$(decode "$revert_data")
      echo "💥 Error: $decoded_error"
    fi
    
    echo ""
    return 1
  fi
  
  # Get the final battle result from the main contract
  local battle_data
  battle_data=$(echo "$trace_result" | jq -r '.[] | select(.event == "return" and .data.status == "success").data.response.data // empty' 2>/dev/null | tail -1)
  
  if [ -z "$battle_data" ] || [ "$battle_data" = "0x" ]; then
    echo "No battle data found"
    return 1
  fi
  
  # Decode the battle result
  local json_data
  json_data=$(echo "${battle_data#0x}" | xxd -r -p 2>/dev/null)
  
  if [ -z "$json_data" ]; then
    echo "Failed to decode battle data"
    return 1
  fi
  
  # Parse and display battle results
  echo ""
  echo "⚔️  P2P BATTLE RESULTS"
  echo "═══════════════════════════════════════════"
  echo ""
  
  # Battle ID
  local battle_id
  battle_id=$(echo "$json_data" | jq -r '.battle_id // 0')
  echo "🆔 Battle ID: #$battle_id"
  
  # Winner
  local winner
  winner=$(echo "$json_data" | jq -r '.winner // 0')
  if [ "$winner" = "0" ]; then
    echo "🏆 Winner: Player 1"
  elif [ "$winner" = "1" ]; then
    echo "🏆 Winner: Player 2"
  else
    echo "🏆 Winner: Draw"
  fi
  
  # Total turns
  local turns
  turns=$(echo "$json_data" | jq -r '.total_turns // 0')
  echo "🔄 Total Turns: $turns"
  echo ""
  
  # Player 1 stats
  echo "👤 Player 1 (Token #$(echo "$json_data" | jq -r '.player1.token_id // 0')):"
  echo "   Final HP: $(echo "$json_data" | jq -r '.player1.final_hp // 0')"
  echo "   EXP Gained: +$(echo "$json_data" | jq -r '.player1.exp_gained // 0')"
  
  local p1_evs
  p1_evs=$(echo "$json_data" | jq -r '.player1.ev_gains // empty')
  if [ -n "$p1_evs" ] && [ "$p1_evs" != "null" ]; then
    echo "   EV Gains:"
    echo "$p1_evs" | jq -r 'to_entries[] | select(.value > 0) | "     \(.key | ascii_upcase): +\(.value)"'
  fi
  echo ""
  
  # Player 2 stats
  echo "👤 Player 2 (Token #$(echo "$json_data" | jq -r '.player2.token_id // 0')):"
  echo "   Final HP: $(echo "$json_data" | jq -r '.player2.final_hp // 0')"
  echo "   EXP Gained: +$(echo "$json_data" | jq -r '.player2.exp_gained // 0')"
  
  local p2_evs
  p2_evs=$(echo "$json_data" | jq -r '.player2.ev_gains // empty')
  if [ -n "$p2_evs" ] && [ "$p2_evs" != "null" ]; then
    echo "   EV Gains:"
    echo "$p2_evs" | jq -r 'to_entries[] | select(.value > 0) | "     \(.key | ascii_upcase): +\(.value)"'
  fi
  
  # Battle log (if available)
  local battle_log
  battle_log=$(echo "$json_data" | jq -r '.battle_log // empty')
  if [ -n "$battle_log" ] && [ "$battle_log" != "null" ] && [ "$battle_log" != "[]" ]; then
    echo ""
    echo "⚔️  Battle Log:"
    echo "─────────────────────────────────────────"
    
    # Parse each turn from the battle log
    echo "$battle_log" | jq -r '.[] | 
      if .type == "move" then
        "Turn \(.turn): \(.attacker) used \(.move)! \(if .effectiveness != 1.0 then "(\(.effectiveness)x) " else "" end)Dealt \(.damage) damage."
      elif .type == "faint" then
        "       💀 \(.pokemon) fainted!"
      else
        "       \(.message // .)"
      end'
  fi
  
  echo ""
  echo "═══════════════════════════════════════════"
  echo ""
  
  # Get updated stats for both players using the token IDs passed to the function
  echo "📊 Post-Battle Status:"
  echo "Player 1: $(name "$player1_id" "$network") - HP: $(hp "$player1_id" "$network")"
  echo "Player 2: $(name "$player2_id" "$network") - HP: $(hp "$player2_id" "$network")"
}

# Execute function
execute() {
  local args="$1"
  shift
  
  local network="oylnet"
  local fee_rate="2"
  
  # Parse remaining arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --feeRate|--fee-rate|-f)
        if [ -n "$2" ]; then
          fee_rate="$2"
          shift 2
        else
          echo "Error: --feeRate requires a value"
          return 1
        fi
        ;;
      --network|-p)
        if [ -n "$2" ]; then
          network="$2"
          shift 2
        else
          echo "Error: --network requires a value"
          return 1
        fi
        ;;
      *)
        # If it doesn't start with --, assume it's the network for backwards compatibility
        if [[ ! "$1" =~ ^-- ]]; then
          network="$1"
        else
          echo "Error: Unknown option $1"
          return 1
        fi
        shift
        ;;
    esac
  done
  
  if [ -z "$args" ]; then
    echo "Usage: execute <args> [network] [--feeRate <rate>]"
    echo "Examples:"
    echo "  execute 12995"
    echo "  execute 12995 oylnet"
    echo "  execute 12995 --feeRate 10"
    echo "  execute 12995 oylnet --feeRate 10"
    echo "  execute 12995 --network oylnet --feeRate 10"
    echo "  execute 12995,0,2,12470,2,12470,0,0,13336,4,13527,4,13695,4,13795,4,13895"
    return 1
  fi
  
  # Check if args contains a comma
  if [[ "$args" == *","* ]]; then
    # Multiple arguments - use as-is
    oyl alkane execute -data "4,$args" -p "$network" --feeRate "$fee_rate" && gen
  else
    # Single number - use contract reserve format
    oyl alkane execute -data "4,$args,0" -p "$network" --feeRate "$fee_rate" && gen
  fi
}

