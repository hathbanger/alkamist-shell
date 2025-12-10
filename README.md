# 🧪 Alkamist CLI Helpers

A collection of lightweight Bash utilities for working with Bitcoin txids, the [Alkanes](https://alkanes.build) protocol, and Alkamon tokens.

Includes tools like:

- `decode` — Hex-to-ASCII or hex-to-decimal decoder
- `encode` — Decimal to hex encoder
- `ensure_hex` — Smart hex encoder (auto-detects format)
- `trace` — Easily trace a Bitcoin transaction via JSON-RPC
- `gen` — Generate blocks on regtest
- `get-alkane` — Get Alkane token information
- `alkamon` — Display complete Alkamon token information with beautiful formatting
- `execute` — Interactive alkane execution interface
- And many more Alkamon-specific functions!

## 🛠️ Installation

### 1. Install alkanes-cli

#### Prerequisites

Before installing, ensure you have:
- **Rust 1.70+** — Install via [rustup](https://rustup.rs/): `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- **Git** — For cloning the repository
- **Build tools** — Including `gcc` and `make` (usually pre-installed on macOS/Linux)

#### Build from Source

Clone and build alkanes-cli from the develop branch:

```bash
# Clone the alkanes-rs repository (develop branch)
git clone https://github.com/kungfuflex/alkanes-rs.git -b develop ~/code/oyl/alkanes-rs

# Build the project
cd ~/code/oyl/alkanes-rs
cargo build --release -p alkanes-cli
```

#### Add to PATH

Choose one of these methods:

**Option 1: User-local symlink (recommended)**
```bash
mkdir -p ~/.local/bin
ln -sf ~/code/oyl/alkanes-rs/target/release/alkanes-cli ~/.local/bin/alkanes-cli

# Ensure ~/.local/bin is in your PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Option 2: System-wide installation**
```bash
sudo cp ~/code/oyl/alkanes-rs/target/release/alkanes-cli /usr/local/bin/
```

**Option 3: Shell profile PATH**
```bash
echo 'export PATH="$HOME/code/oyl/alkanes-rs/target/release:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### Verify Installation

```bash
alkanes-cli --version
alkanes-cli --help
```

You should see version information and available commands.

### 2. Clone this repo

```bash
git clone https://github.com/hathbanger/alkamist.git ~/.config/alkamist
```

### 3. Add to your shell

Append the following to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.config/alkamist:$PATH"
alias alkamist='source ~/.config/alkamist/alkamist.sh'
```

Then reload your shell:

```bash
source ~/.zshrc  # or ~/.bashrc
```

### 4. Configure environment variables

#### Required for all operations:

```bash
export SANDSHREW_PROJECT_ID=your_project_id_here
```

#### Optional - Override defaults:

```bash
# Custom alkanes-cli binary path (default: /Users/$USER/code/oyl/alkanes-rs/target/release/alkanes-cli)
export ALKANES_CLI_BIN=/path/to/alkanes-cli

# Custom wallet file (default: ~/.alkanes/wallet.json)
export ALKANES_WALLET_FILE=~/.alkanes/wallet.json

# Custom wallet passphrase (default: amh05055)
export ALKANES_PASSWORD=your_passphrase

# Custom RPC endpoint (default: https://regtest.subfrost.io/v4/...)
export ALKANES_JSONRPC_URL=https://regtest.subfrost.io/v4/your_project_id

# Custom data API endpoint (default: https://regtest.subfrost.io/v4/...)
export ALKANES_DATA_API=https://regtest.subfrost.io/v4/your_project_id
```

**⚠️ Security Note**: Keep your wallet passphrase secure and never share it. Consider adding these to your shell profile (`.zshrc`/`.bashrc`) for convenience.

### 5. Create a wallet

Before using alkamist, create an alkanes-cli wallet:

```bash
alkanes-cli -p regtest \
  --wallet-file ~/.alkanes/wallet.json \
  --passphrase your_passphrase \
  wallet create
```

### 6. Load Alkamist

```bash
alkamist
```

Now you can use:

```bash
decode 0x08c3...
trace <txid>
alkamon 60  # View detailed information about Alkamon token #60
execute     # Interactive execution interface
```

---

## 🔍 Commands

### General Utilities

#### `decode <hex>`

Decodes a hex string. If it starts with `0x08...`, it decodes as ASCII. Otherwise, it's treated as a number.

```bash
decode 0x416c6b616d6f6e  # Returns: "Alkamon"
decode 0x63              # Returns: 99
```

#### `encode <number>`

Converts a decimal number to hex format.

```bash
encode 99  # Returns: 0x63
```

#### `ensure_hex <value>`

Smart hex encoder that auto-detects input format and converts appropriately:

```bash
ensure_hex 99           # Returns: 0x63 (decimal → hex)
ensure_hex 0x63         # Returns: 0x63 (already hex)
ensure_hex abc          # Returns: 0xabc (hex string → add prefix)
ensure_hex deadbeef     # Returns: 0xdeadbeef (hex string)
```

#### `gen [count=1] [network=oylnet]`

Generates blocks on regtest (defaults to 1 block).

```bash
gen           # Generate 1 block
gen 10        # Generate 10 blocks
gen 5 oylnet  # Generate 5 blocks on oylnet
```

#### `trace <txid> [network=oylnet]`

Traces a transaction via JSON-RPC to the Subfrost API.

```bash
trace abc123def456  # Trace transaction on oylnet
trace abc123 signet # Trace on signet
```

#### `get-alkane <block:tx> [network]`

Gets comprehensive information about an Alkane token.

```bash
get-alkane 4:12825           # Get alkane at block 4, tx 12825
get-alkane 4:12825 signet    # Get alkane on signet
```

#### `new-token-trace <txid>`

Traces a new token creation transaction and displays formatted results.

#### `new-vault-trace <txid>`

Traces a new vault creation transaction.

#### `vault-info <tx> [network]`

Displays detailed information about a vault.

```bash
vault-info 12825           # Get vault info
vault-info 12825 signet    # Get vault info on signet
```

#### `execute`

Interactive alkane execution interface with prompts for:
- Block number (default: 4)
- Contract TX
- OpCode (default: 0)
- Additional arguments
- Network (default: oylnet)
- Fee rate (default: 10)

```bash
execute
# Follow the prompts to execute an alkane call
```

### 🎮 Alkamon Functions

#### `alkamon <token_id> [network]`

**Main command** - Displays a beautiful, comprehensive overview of your Alkamon including:

- Name, symbol, and level
- HP with visual health bar
- Experience with progress bar
- Types and moves
- Complete stats table (Base/IV/EV)
- All formatted in a game-like interface

```bash
alkamon 60           # View Alkamon #60
alkamon 60 signet    # View on signet
```

#### Read Functions (Query token state)

- `id <token_id>` — Get token ID
- `level <token_id>` — Get current level
- `exp <token_id>` — Get experience points
- `hp <token_id>` — Get current HP
- `ivs <token_id>` — Get Individual Values (genetics)
- `evs <token_id>` — Get Effort Values (training stats)
- `stats <token_id>` — Get base stats
- `moves <token_id>` — Get move list
- `types <token_id>` — Get type list
- `name <token_id>` — Get name
- `symbol <token_id>` — Get symbol
- `data <token_id>` — Get raw data
- `attr <token_id>` — Get attributes

All read functions support an optional `[network]` parameter (default: oylnet).

#### Write Functions (Modify token state)

- `heal <token_id> [network]` — Heal to full HP
- `candy <token_id> [network]` — Use rare candy to level up
- `train <token_id> <opponent_type> [network]` — Train against opponent (1-18)
- `summon <type> [network]` — Summon a new Alkamon
- `init <factory_id> <alkamon_factory_id> [network]` — Initialize factory
- `p2p <contract_id> <player1_id> <player2_id> [network]` — PvP battle

**⚠️ Note**: Write functions require a funded wallet with the correct passphrase.

All write functions automatically:

- Execute the transaction
- Generate a new block
- Trace the transaction to show results

#### Battle Functions

- `simulate <alkamon_id> <opponent_level> [network]` — Simulate a battle
- `p2p <contract_id> <player1_id> <player2_id> [network]` — Execute PvP battle

### 📊 Example Usage

```bash
# First-time setup
export SANDSHREW_PROJECT_ID=your_project_id_here

# Create wallet (one time)
alkanes-cli -p regtest \
  --wallet-file ~/.alkanes/wallet.json \
  --passphrase your_passphrase \
  wallet create

# Load alkamist
alkamist

# View complete token information
alkamon 60

# Check specific stats
level 60
hp 60
ivs 60

# Train your Alkamon
train 60 1  # Train against Fire type (1)

# Heal after training
heal 60

# Use rare candy to level up
candy 60

# Simulate a battle
simulate 60 5  # Battle against level 5 opponent

# Interactive execution
execute
```

---

## 📦 Requirements

- **Rust/Cargo** (for building alkanes-cli)
- **[alkanes-cli](https://github.com/kungfuflex/alkanes-rs)** (built from source)
- **jq** for JSON parsing (`brew install jq` or `apt install jq`)
- **curl** for JSON-RPC calls
- **macOS or Linux** with `bash`, `xxd`
- **Sandshrew project ID** for accessing the Alkanes network
- **Funded wallet** for write operations (heal, candy, train, etc.)

---

## 🔧 Advanced Usage

### Direct JSON-RPC Calls

You can make direct calls to the Subfrost API using the `ensure_hex` helper:

```bash
# Source alkamist functions
source ~/.config/alkamist/functions.sh

# Example: Simulate calling opcode 99 (name) on token 2:12825
OPCODE=99
TARGET_BLOCK=2
TARGET_TX=12825

# Convert opcode to hex
HEX_OPCODE=$(ensure_hex $OPCODE)

# Make the API call
curl -X POST https://regtest.subfrost.io/v4/your_project_id \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"alkanes_simulate\",
    \"params\": [{
      \"target\": {\"block\": $TARGET_BLOCK, \"tx\": $TARGET_TX},
      \"inputs\": [\"$HEX_OPCODE\"],
      \"pointer\": 0,
      \"refundPointer\": 0,
      \"vout\": 0
    }],
    \"id\": 1
  }"
```

### Network Mapping

Alkamist automatically maps network names:
- `oylnet` → `regtest` (for alkanes-cli)
- `signet` → `signet`
- `bitcoin` → `bitcoin`

This allows you to use familiar network names while the tools use the correct underlying network.

---

## 💡 Pro Tip

To automatically load `alkamist` in every shell:

```bash
echo "source ~/.config/alkamist/alkamist.sh" >> ~/.zshrc
```

---

## 🏗️ Architecture

Alkamist uses:
- **alkanes-cli** for blockchain interactions and execution
- **Subfrost JSON-RPC API** for traces and queries
- **Direct wallet management** via alkanes-cli's wallet system
- **Protostone format** (`[params]:v0:v0`) for alkane calls

All commands are designed to work seamlessly with regtest, signet, and mainnet.

---

## ✨ License

MIT
