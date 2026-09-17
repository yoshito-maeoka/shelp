#!/usr/bin/env bats
# Tests stub `curl` so no Ollama server is needed.

setup() {
  SHELP="$BATS_TEST_DIRNAME/../bin/shelp"
  STUB_DIR="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUB_DIR"
  export PAYLOAD_FILE="$BATS_TEST_TMPDIR/payload.json"
  export STUB_RESPONSE='{"message":{"content":"ls -la"},"done":false}
{"message":{"content":""},"done":true}'
  export STUB_SERVER_UP=1

  cat >"$STUB_DIR/curl" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    */api/version) [[ "$STUB_SERVER_UP" == 1 ]]; exit ;;
    */api/chat) cat >"$PAYLOAD_FILE"; printf '%s\n' "$STUB_RESPONSE"; exit 0 ;;
  esac
done
exit 1
EOF
  chmod +x "$STUB_DIR/curl"
  export PATH="$STUB_DIR:$PATH"
  export OLLAMA_HOST="http://stub:11434"
  unset SHELP_MODEL SHELP_SHELL
}

@test "prints streamed answer" {
  run "$SHELP" "list files"
  [ "$status" -eq 0 ]
  [ "$output" = "ls -la" ]
}

@test "sends question, model and system prompt in payload" {
  run "$SHELP" -m test-model -s zsh "how to loop over files"
  [ "$status" -eq 0 ]
  [ "$(jq -r .model "$PAYLOAD_FILE")" = "test-model" ]
  [ "$(jq -r '.messages[1].content' "$PAYLOAD_FILE")" = "how to loop over files" ]
  jq -r '.messages[0].content' "$PAYLOAD_FILE" | grep -q "ONLY questions about zsh"
}

@test "reads question from stdin" {
  run bash -c "echo 'find big files' | '$SHELP'"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.messages[1].content' "$PAYLOAD_FILE")" = "find big files" ]
}

@test "-c asks for command-only output" {
  run "$SHELP" -c "count lines"
  [ "$status" -eq 0 ]
  jq -r '.messages[0].content' "$PAYLOAD_FILE" | grep -q "Output ONLY the command"
}

@test "uses SHELP_MODEL from environment" {
  SHELP_MODEL=env-model run "$SHELP" "q"
  [ "$(jq -r .model "$PAYLOAD_FILE")" = "env-model" ]
}

@test "rejects unsupported shell" {
  run "$SHELP" -s fish "q"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported shell 'fish'"* ]]
}

@test "fails with usage when question is empty" {
  run "$SHELP" "   " </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "rejects unknown option" {
  run "$SHELP" -x "q"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option -x"* ]]
}

@test "reports unreachable server" {
  STUB_SERVER_UP=0 run "$SHELP" "q"
  [ "$status" -eq 2 ]
  [[ "$output" == *"cannot reach Ollama"* ]]
}

@test "surfaces ollama error" {
  STUB_RESPONSE='{"error":"model \"nope\" not found"}' run "$SHELP" -m nope "q"
  [ "$status" -ne 0 ]
  [[ "$output" == *'ollama error: model "nope" not found'* ]]
}

@test "prints help and version" {
  run "$SHELP" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: shelp"* ]]
  run "$SHELP" -V
  [[ "$output" == shelp\ * ]]
}

@test "interactive: answers each question and exits on Ctrl-D" {
  run bash -c "printf 'list files\n' | '$SHELP' -i"
  [ "$status" -eq 0 ]
  [[ "$output" == *"shelp> "* ]]
  [[ "$output" == *"ls -la"* ]]
}

@test "interactive: keeps conversation history for follow-ups" {
  run bash -c "printf 'list files\nand hidden ones?\n' | '$SHELP' -i"
  [ "$status" -eq 0 ]
  [ "$(jq '.messages | length' "$PAYLOAD_FILE")" -eq 4 ]
  [ "$(jq -r '.messages[2].role' "$PAYLOAD_FILE")" = "assistant" ]
  [ "$(jq -r '.messages[2].content' "$PAYLOAD_FILE")" = "ls -la" ]
  [ "$(jq -r '.messages[3].content' "$PAYLOAD_FILE")" = "and hidden ones?" ]
}

@test "interactive: /clear resets history" {
  run bash -c "printf 'list files\n/clear\nshow date\n' | '$SHELP' -i"
  [ "$status" -eq 0 ]
  [ "$(jq '.messages | length' "$PAYLOAD_FILE")" -eq 2 ]
  [ "$(jq -r '.messages[1].content' "$PAYLOAD_FILE")" = "show date" ]
}

@test "interactive: exit stops before sending further questions" {
  run bash -c "printf 'exit\nlist files\n' | '$SHELP' -i"
  [ "$status" -eq 0 ]
  [ ! -f "$PAYLOAD_FILE" ]
}

@test "interactive: failed request does not end the session" {
  STUB_RESPONSE='{"error":"boom"}' run bash -c "printf 'q1\nq2\n' | '$SHELP' -i"
  [ "$status" -eq 0 ]
  [[ "$output" == *"request failed"* ]]
  [ "$(jq '.messages | length' "$PAYLOAD_FILE")" -eq 2 ]
}

@test "system prompt treats product/file names as on-topic and answers when in doubt" {
  run "$SHELP" "how can I read .env and exec this ./setup-keycloak-client.sh ?"
  [ "$status" -eq 0 ]
  local system
  system="$(jq -r '.messages[0].content' "$PAYLOAD_FILE")"
  [[ "$system" == *"does NOT make a question off-topic"* ]]
  [[ "$system" == *"When in doubt, answer."* ]]
  [[ "$system" == *"set -a; source .env; set +a"* ]]
}
