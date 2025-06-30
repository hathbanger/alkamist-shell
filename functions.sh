# ~/.config/alkamist/functions.sh

decode() {
  local hex="${1}"

  if [ -z "$hex" ]; then
    echo "Error: hex value is required"
    echo "Usage: decode <hex>"
    return 1
  fi

  hex="${hex#0x}"

  if [[ "$hex" =~ ^08 ]]; then
    echo -n "$hex" | xxd -r -p
    echo
  else
    echo $((16#$hex))
  fi
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
