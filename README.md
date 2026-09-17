# shelp

Ask a local [Ollama](https://ollama.com) model **zsh/bash questions only**. Anything off-topic is refused.

### Interactive (default)

```text
$ shelp
shelp 0.2.0 — zsh questions via gemma3:12b. /clear resets, exit or Ctrl-D quits.
shelp> how do I list files sorted by size?
ls -lS ...
shelp> now only the top 5
ls -lS | head -n 5 ...
shelp> exit
```

The shell-only instructions are sent automatically, and follow-up questions keep the
conversation's context. Commands: `/clear` (reset context), `exit` / `/bye` / Ctrl-D (quit).
Arrow keys and line editing work.

### One-shot

```sh
$ shelp find files larger than 100MB in my home dir
$ shelp -c delete all .DS_Store files recursively   # command only
$ echo "how do I loop over lines of a file" | shelp -s bash
```

## Install

Requires `bash`, `curl`, `jq` and a running `ollama serve`.

```sh
ln -s "$PWD/bin/shelp" /usr/local/bin/shelp   # or any dir on your PATH
```

## Options

| Flag | Env | Default |
|------|-----|---------|
| `-m MODEL` | `SHELP_MODEL` | `gemma3:12b` |
| `-s zsh\|bash` | `SHELP_SHELL` | your login shell |
| `-c` (command only) | — | off |
| `-i` (force interactive) | — | on when run with no args in a terminal |
| — | `OLLAMA_HOST` | `http://127.0.0.1:11434` |

Tip (zsh): use `noglob` so `?` and `*` in questions aren't expanded:

```zsh
alias shelp='noglob shelp'
```

## Test

```sh
bats test/
```

Live check of the system prompt (needs a running Ollama, takes ~1 min):

```sh
test/live-eval.sh bin/shelp
```
