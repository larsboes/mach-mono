---
name: save-context
description: Save session context before ending a conversation. Updates CLAUDE.md with learnings and creates a session summary for resuming work later.
disable-model-invocation: true
argument-hint: [optional-notes]
---

# Save Context Before Ending Session

You are about to preserve context from this session so the next session can pick up seamlessly.

## Steps

### 1. Update CLAUDE.md
Use `/claude-md-management:revise-claude-md` to update the project CLAUDE.md with any learnings, patterns discovered, or decisions made during this session.

### 2. Create Session Summary
Use `/summarize-conversation` to generate a structured summary of what was accomplished, what's in progress, and what's next.

### 3. Save Summary File
Save the summary to `.ai-docs/sessions/` using the format `YYYY-MM-DD-summary.md`. If multiple sessions happen on the same day, append `-2`, `-3`, etc.

The summary should include:
- **Completed**: What was finished this session
- **In Progress**: What was started but not completed
- **Next Steps**: What should be done next session
- **Key Decisions**: Any architectural or design decisions made
- **Blockers**: Anything that's stuck or needs input

### 4. Print Resume Prompt
After saving, print this for the user to copy:

```
Resuming work on boring.notch. Read these for context:
- CLAUDE.md
- PLAN.md
- .ai-docs/sessions/ (latest summary)
Then tell me where we left off and what's next.
```

$ARGUMENTS
