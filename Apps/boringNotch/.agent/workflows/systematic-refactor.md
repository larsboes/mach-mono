---
description: Systematic Refactoring Workflow
---

# Systematic Refactoring Workflow

Use this workflow when performing structural changes that affect multiple files (e.g., changing dependency injection patterns, renaming core types, or migrating APIs) to avoid "whack-a-mole" error fixing.

1. **Analyze the Pattern**
   - Identify the root cause of the error (e.g., "All views using `@Bindable` with the new protocol need a specific pattern").
   - Define the "Before" and "After" code patterns.

2. **Search Globally**
   - **STOP** fixing individual files.
   - Use `grep_search` to find **ALL** occurrences of the affected pattern in the codebase.
   - Example: `grep_search(query="@Environment(\\.bindableSettings)", path=".")`

3. **Batch Execute**
   - Create a plan to update all identified files.
   - Apply the fix to **ALL** files in a single set of tool calls (or sequential calls if too many).
   - Do not wait for a build failure to tell you which file is next.
   - **Crucial:** If adding or removing files, use `ruby manage_xcode_files.rb` immediately. Do not rely on `xcodebuild` to catch missing file references.

4. **Verify**
   - Run the build only *after* the batch update is complete.
   - If errors persist, re-analyze to see if the pattern was misunderstood, rather than falling back to one-by-one fixes.
