#!/usr/bin/env bash

if [ -z "$SANDSHREW_PROJECT_ID" ]; then
  echo "❌ Please export your SANDSHREW_PROJECT_ID before using Alkamist."
  echo "Example:"
  echo "  export SANDSHREW_PROJECT_ID=123456789...abcdef"
  return 1
fi

source "$HOME/.config/alkamist/functions.sh"
source "$HOME/.config/alkamist/alias.sh"
echo "🔮 Alkamist loaded → available commands: decode, gen, get-alkane, new-token-trace, new-vault-trace, trace"
