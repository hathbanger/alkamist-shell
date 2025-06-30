#!/usr/bin/env bash

if [ -z "$SANDSHREW_PROJECT_ID" ]; then
  echo "❌ Please export your SANDSHREW_PROJECT_ID before using Alkamist."
  echo "Example:"
  echo "  export SANDSHREW_PROJECT_ID=348ae3256c48c15cc99dcb056d2f78df"
  return 1
fi

source "$HOME/.config/alkamist/functions.sh"
echo "🔮 Alkamist loaded → available commands: decode, trace"
