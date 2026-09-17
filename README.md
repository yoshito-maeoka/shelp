# shelp
```
    .@@@@@.
   @( •ᴥ• )@  shelp
    `@@@@@`
```

**sh**ell + h**elp**: a tiny terminal assistant that answers **zsh and bash questions** using a
local [Ollama](https://ollama.com) model. Off-topic questions are refused, and nothing leaves your machine.

````text
$ shelp
shelp 0.2.0 — zsh questions via gemma3:12b. /clear resets, exit or Ctrl-D quits.
shelp> how can I read .env and exec this ./setup-keycloak-client.sh ?
```bash
set -a
source .env
set +a
./setup-keycloak-client.sh
```

`set -a` exports every variable defined in `.env`, so the script can see them ...

shelp> what's a good pasta recipe?
shelp only answers zsh/bash questions.
````

## Features

- **Interactive prompt**: run `shelp` with no arguments and keep asking. Follow-up questions keep context.
- **One-shot mode**: `shelp <question>` or `echo <question> | shelp`, handy in scripts.
- **Command-only mode**: `-c` prints just the command.
- **Answers fit your setup**: the prompt includes your shell and OS, so on macOS it prefers BSD options.
- **Stays on topic**: anything done in a terminal is answered (scripts, `.env`, git, docker, curl, …); unrelated
  questions are refused.
- **Warns** about destructive commands (`rm`, `dd`, `chmod -R`, force pushes, …).
- **Streams** answers as they are generated.
- **Few dependencies**: runs on the bash 3.2 that ships with macOS and needs only `curl` and `jq`.

## Requirements

- `bash` 3.2+, `curl`, `jq`
- [Ollama](https://ollama.com) running locally (`ollama serve`) with at least one model pulled:

```sh
brew install jq ollama
ollama pull gemma3:12b
```

## Install

```sh
git clone <this-repo> ~/work/gbwp
ln -s ~/work/gbwp/bin/shelp /usr/local/bin/shelp   # or any directory on your PATH
```

**zsh users:** add this to `~/.zshrc`, otherwise zsh expands `?` and `*` in your question before
`shelp` sees it (`zsh: no matches found`):

```zsh
alias shelp='noglob shelp'
```

## Usage

```text
shelp [options]                 start an interactive prompt
shelp [options] <question...>   ask one question
echo "<question>" | shelp       ask one question from stdin
```

### Interactive mode

Starts when `shelp` is run with no arguments in a terminal (or with `-i`).

| Input | Effect |
|-------|--------|
| any text | ask a question (earlier questions and answers are kept as context) |
| `/clear` | start a fresh conversation |
| `exit`, `quit`, `/bye`, `/exit`, `:q`, Ctrl-D | quit |
| ↑ / ↓ | recall earlier questions from this session |

If a request fails, an error is shown and the prompt stays open. The failed question is dropped from the context.

### One-shot mode

```sh
shelp find files larger than 100MB in my home dir
shelp -c delete all .DS_Store files recursively     # command only
shelp -s bash how do I loop over lines of a file    # answer for bash
echo "show my public ip" | shelp
shelp -m gemma4:26b explain set -euo pipefail       # use another model
```

## Options

| Flag | Environment variable | Default | Description |
|------|----------------------|---------|-------------|
| `-m MODEL` | `SHELP_MODEL` | `gemma3:12b` | Ollama model to use |
| `-s SHELL` | `SHELP_SHELL` | your login shell (`$SHELL`) | Target shell: `zsh` or `bash` |
| `-c` | — | off | Print only the command(s), no explanation |
| `-i` | — | on with no args in a terminal | Force interactive mode |
| `-h` | — | — | Show help |
| `-V` | — | — | Show version |
| — | `OLLAMA_HOST` | `http://127.0.0.1:11434` | Ollama server URL |

Flags override environment variables.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | success |
| `1` | invalid usage, empty question, or an error returned by Ollama (e.g. unknown model) |
| `2` | Ollama server not reachable |

## How it works

`shelp` sends a request to Ollama's `/api/chat` with a **system prompt** built from your shell and OS.
The system prompt:

1. lists what counts as on-topic (shell syntax, `.env` files, running scripts, CLI tools of any product,
   shell configuration),
2. says that product or file names don't make a question off-topic ("when in doubt, answer"),
3. asks for correct, existing commands and reminds the model that variables must be exported to reach
   child processes,
4. refuses only unrelated questions, with the exact message `shelp only answers zsh/bash questions.`

The reply streams to your terminal. In interactive mode each question and answer is added to the
conversation for follow-ups; `/clear` resets it to just the system prompt.

## Project layout

```text
bin/shelp            the command (single bash script)
test/shelp.bats      unit tests (bats, with a fake curl, no Ollama needed)
test/live-eval.sh    live check of the system prompt against a real Ollama
```

## Development

Run the unit tests (needs [bats](https://github.com/bats-core/bats-core): `brew install bats-core`):

```sh
bats test/
```

After changing the system prompt, run the live check. It sends 6 shell questions (which should be answered)
and 4 off-topic ones (which should be refused), and prints `PASS`/`FAIL` for each. It needs a running
Ollama and takes about a minute:

```sh
test/live-eval.sh bin/shelp
```

## Known limitations

- A small local model can still give wrong answers. Read commands before running them.
- The topic filter comes from the system prompt, so it is a strong hint rather than a hard guarantee.
- With `-c` the model sometimes still wraps the command in a code fence.
- Questions typed at the prompt are not saved after you quit.
