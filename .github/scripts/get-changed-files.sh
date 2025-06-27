#!/bin/bash

# Get changed files using git diff
if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
  # For pull requests, compare against the base branch
  BASE_SHA="$PR_BASE_SHA"
  HEAD_SHA="$PR_HEAD_SHA"
  CHANGED_FILES=$(git diff --name-only $BASE_SHA..$HEAD_SHA)
else
  # For push events, compare against previous commit
  CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
fi

echo "Changed files:"
echo "$CHANGED_FILES"

# Filter for JSON files in policyDefinitions directory
JSON_FILES=$(echo "$CHANGED_FILES" | grep '^policyDefinitions/.*\.json$' || true)

echo "Changed JSON files in policyDefinitions:"
echo "$JSON_FILES"

# Export as space-separated string for compatibility with existing code
ALL_CHANGED_FILES=$(echo "$CHANGED_FILES" | tr '\n' ' ')
JSON_FILES_LIST=$(echo "$JSON_FILES" | tr '\n' ' ')

echo "all_changed_files=$ALL_CHANGED_FILES" >> $GITHUB_OUTPUT
echo "json_files=$JSON_FILES_LIST" >> $GITHUB_OUTPUT
echo "json_files_count=$(echo "$JSON_FILES" | grep -c . || echo "0")" >> $GITHUB_OUTPUT