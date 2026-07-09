# extract.jq — collapse a Codex rollout .jsonl into genuine human<->agent dialogue.
#
# Drops everything that is not signal for doc-tuning:
#   - tool calls, tool outputs, reasoning blocks, images (non-message payloads);
#   - injected/synthetic USER-role envelopes that Codex generates, not Anders:
#     the AGENTS.md/environment dump, goal-loop continuation prompts, delegation
#     envelopes, heartbeats, skill-injection wrappers, turn-aborted markers.
# These envelopes were ~94% of "user" bytes in large orchestration sessions and
# are pure noise for finding where Anders had to steer the agent.
#
# Assistant turns are kept but capped (their long outputs are mostly low-signal
# for alignment; their first ~1500 chars carry the question/assumption/plan).
# User turns are kept IN FULL — they are the signal.
#
# Usage: jq -r -f extract.jq <rollout.jsonl>
# Output: one physical line per turn — "<role>\t<text>" with newlines flattened.

def envelope($t):
  ($t | startswith("# AGENTS.md instructions for"))
  or ($t | startswith("<codex_internal_context"))
  or ($t | startswith("<turn_aborted"))
  or ($t | startswith("<turn_context"))
  or ($t | startswith("<codex_delegation"))
  or ($t | startswith("<heartbeat"))
  or ($t | startswith("<skill"))
  or ($t | startswith("<environment_context"))
  or ($t | startswith("<user_instructions"))
  or ($t | startswith("<user_action"));

select(.type == "response_item" and .payload.type == "message")
| .payload as $m
| (($m.content // [])
    | map(select(.type == "input_text" or .type == "output_text") | .text)
    | join("\n")) as $raw
| select($raw != "" and ($m.role == "user" or $m.role == "assistant"))
| ($raw | sub("^[[:space:]]+"; "")) as $t
# keep all assistant turns; drop synthetic/injected user-role envelopes
| select($m.role == "assistant" or (envelope($t) | not))
# cap assistant length; keep user turns whole
| (if $m.role == "assistant" and ($raw | length) > 1500
     then ($raw[0:1500] + " …[truncated]")
     else $raw end) as $text
# flatten every line-break form (\n, \r, U+2028, U+2029) so each message is
# exactly one physical line — keeps the output greppable and chunkable.
| "\($m.role)\t\($text | gsub("[\n\r]+"; " ⏎ "))"
