# 🧪 Alkamist CLI

A collection of lightweight Bash utilities for working with Bitcoin txids and the [Oyl Alkanes](https://oyl.dev) protocol.

Includes tools like:

- `decode` — Hex-to-ASCII or hex-to-decimal decoder
- `trace` — Easily trace a Bitcoin transaction via Oyl’s CLI

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

### 3. Load Alkamist

```bash
alkamist
```

Now you can use:

```bash
decode 0x08c3...
trace <txid>
```

---

## 🔍 Commands

### `decode <hex>`

Decodes a hex string. If it starts with `0x08...`, it decodes as ASCII. Otherwise, it's treated as a number.

### `trace <txid> [vout=4] [network=oylnet]`

Calls the `trace` method via `oyl` CLI.

---

## 📦 Requirements

* [`oyl`](https://oyl.dev) CLI installed and available on your path
* macOS or Linux with `bash`, `xxd`

---

## 💡 Pro Tip

To automatically load `alkamist` in every shell:

```bash
echo "source ~/.config/alkamist/alkamist.sh" >> ~/.zshrc
```

---

## ✨ License

MIT

