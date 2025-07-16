# 🧪 Alkamist CLI Helpers 

A collection of lightweight Bash utilities for working with Bitcoin txids, the [Oyl Alkanes](https://alkanes.build) protocol, and Alkamon tokens.

Includes tools like:

- `decode` — Hex-to-ASCII or hex-to-decimal decoder
- `trace` — Easily trace a Bitcoin transaction via Oyl's CLI
- `gen` — Generate blocks on regtest
- `get-alkane` — Get Alkane token information
- `alkamon` — Display complete Alkamon token information with beautiful formatting
- And many more Alkamon-specific functions!

## 🛠️ Installation

### 1. Clone the repo

```bash
git clone https://github.com/yourusername/alkamist.git ~/.config/alkamist
````

### 2. Add to your shell

Append the following to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.config/alkamist:$PATH"
alias alkamist='source ~/.config/alkamist/alkamist.sh'
```

Then reload your shell:

```bash
source ~/.zshrc  # or ~/.bashrc
```

### 3. Export your Sandshrew project ID

```bash
export SANDSHREW_PROJECT_ID=your_project_id_here
```

### 4. Load Alkamist

```bash
alkamist
```

Now you can use:

```bash
decode 0x08c3...
trace <txid>
alkamon 60  # View detailed information about Alkamon token #60
```

---

## 🔍 Commands

### General Utilities

#### `decode <hex>`
Decodes a hex string. If it starts with `0x08...`, it decodes as ASCII. Otherwise, it's treated as a number.

#### `encode <number>`
Converts a decimal number to hex format.

#### `gen [count=1]`
Generates blocks on regtest (defaults to 1 block).

#### `trace <txid> [network=oylnet]`
Calls the `trace` method via `oyl` CLI to trace a transaction.

#### `get-alkane <block:tx> [network]`
Gets comprehensive information about an Alkane token.

#### `new-token-trace <txid>`
Traces a new token creation transaction and displays formatted results.

#### `new-vault-trace <txid>`
Traces a new vault creation transaction.

#### `vault-info <tx> [network]`
Displays detailed information about a vault.

### 🎮 Alkamon Functions

#### `alkamon <token_id> [network]`
**Main command** - Displays a beautiful, comprehensive overview of your Alkamon including:
- Name, symbol, and level
- HP with visual health bar
- Experience with progress bar
- Types and moves
- Complete stats table (Base/IV/EV)
- All formatted in a game-like interface

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

#### Write Functions (Modify token state)
- `heal <token_id>` — Heal to full HP
- `candy <token_id>` — Use rare candy to level up
- `train <token_id> <opponent_type>` — Train against opponent (1-18)

All write functions automatically:
- Execute the transaction
- Generate a new block
- Trace the transaction to show results

### 📊 Example Usage

```bash
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
```

---

## 📦 Requirements

* [`oyl`](https://github.com/Oyl-Wallet/oyl-sdk) CLI installed and available on your path
* `jq` for JSON parsing (`brew install jq` or `apt install jq`)
* macOS or Linux with `bash`, `xxd`
* A Sandshrew project ID for accessing the Oyl network

---

## 💡 Pro Tip

To automatically load `alkamist` in every shell:

```bash
echo "source ~/.config/alkamist/alkamist.sh" >> ~/.zshrc
```

---

## ✨ License

MIT

