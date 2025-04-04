#!/bin/bash

# Default values
DEFAULT_MODE="table"
DEFAULT_OUTPUT_FILE="README.md"

# --- Usage Instructions ---
usage() {
  cat << EOF
Usage: $0 <repository_list_path> [github_owner] [mode] [output_file]

Generates a Markdown file listing GitHub repositories with descriptions, last push date,
language (logo badge for common languages, text otherwise), and info badges
(stars, forks, license).

Arguments:
  repository_list_path  Path to a file containing a list of repositories, one per line (format: owner/repo). (Required)
  github_owner          Your GitHub username/organization name (used for the final link).
                        (Required, *unless* running inside a GitHub Action, where it can be auto-detected).
  mode                  Output format: 'table' (default) or 'list'. (Optional)
  output_file           Path to the output Markdown file (default: ${DEFAULT_OUTPUT_FILE}). (Optional)

Environment Variables:
  GITHUB_TOKEN          (Optional) A GitHub Personal Access Token (PAT) for authenticated API requests,
                        increasing rate limits. Use 'export GITHUB_TOKEN=your_token'.
  GITHUB_ACTIONS        (Set by GitHub Actions runner) If 'true', indicates script is running in an Action.
  GITHUB_REPOSITORY     (Set by GitHub Actions runner) Format 'owner/repo', used to auto-detect owner if needed.

Dependencies:
  curl, jq, date (GNU date for ISO 8601 parsing)
EOF
  exit 1
}

# --- Argument Parsing ---
REPOSITORY_LIST=$1
GITHUB_OWNER_ARG=$2
MODE=${3:-$DEFAULT_MODE}
OUTPUT_FILE=${4:-$DEFAULT_OUTPUT_FILE}
GITHUB_OWNER=""

# Check required repository_list_path argument
if [[ -z "$REPOSITORY_LIST" ]]; then
    echo "ERROR: Missing required argument: repository_list_path." >&2
    usage
fi

# Check if running inside GitHub Actions
if [[ "$GITHUB_ACTIONS" == "true" ]]; then
    echo "INFO: Detected running inside a GitHub Action."
    if [[ -z "$GITHUB_OWNER_ARG" ]]; then
        echo "INFO: github_owner argument not provided, attempting auto-detection..."
        if [[ -n "$GITHUB_REPOSITORY" && "$GITHUB_REPOSITORY" == */* ]]; then
            GITHUB_OWNER="${GITHUB_REPOSITORY%/*}"
            echo "INFO: Auto-detected GitHub owner as '$GITHUB_OWNER' from GITHUB_REPOSITORY."
        else
            echo "ERROR: Running in GitHub Action, github_owner not provided, and could not parse GITHUB_REPOSITORY ('$GITHUB_REPOSITORY')." >&2
            exit 1
        fi
    else
        GITHUB_OWNER="$GITHUB_OWNER_ARG"
        echo "INFO: Using provided github_owner argument: '$GITHUB_OWNER'."
    fi
else
    if [[ -z "$GITHUB_OWNER_ARG" ]]; then
        echo "ERROR: Not running in GitHub Action and github_owner argument is required but not provided." >&2
        usage
    fi
    GITHUB_OWNER="$GITHUB_OWNER_ARG"
fi

if [[ -z "$GITHUB_OWNER" ]]; then
    echo "ERROR: Could not determine GitHub Owner." >&2
    exit 1
fi

# Validate mode
if [[ "$MODE" != "table" && "$MODE" != "list" ]]; then
    echo "ERROR: Invalid mode '$MODE'. Must be 'table' or 'list'." >&2
    usage
fi

# (Dependencies are curl, jq, date)
if ! command -v curl &> /dev/null; then echo "ERROR: curl required." >&2; exit 1; fi
if ! command -v jq &> /dev/null; then echo "ERROR: jq required." >&2; exit 1; fi
if ! command -v date &> /dev/null; then echo "ERROR: date required." >&2; exit 1; fi

if [[ ! -f "$REPOSITORY_LIST" ]]; then echo "ERROR: File '$REPOSITORY_LIST' not found." >&2; exit 1; fi
if [[ ! -r "$REPOSITORY_LIST" ]]; then echo "ERROR: File '$REPOSITORY_LIST' not readable." >&2; exit 1; fi

# Helper function to get language badge or text
# Arguments: language_name
get_language_output() {
    local language="$1"
    local language_output # either badge HTML or text name
    local lang_lower # Language name in lowercase
    local badge_height=20 # Consistent height for badges

    lang_lower=$(echo "$language" | tr '[:upper:]' '[:lower:]') # Convert to lowercase

    # Use case statement for mapping common languages to badges
    # Format: https://img.shields.io/badge/LanguageName-Color?style=flat&logo=LogoName&logoColor=white
    case "$lang_lower" in
        python)
            language_output="<img src=\"https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white\" alt=\"Python\" height=\"$badge_height\"/>"
            ;;
        javascript)
            language_output="<img src=\"https://img.shields.io/badge/JavaScript-F7DF1E?style=flat&logo=javascript&logoColor=black\" alt=\"JavaScript\" height=\"$badge_height\"/>"
            ;;
        typescript)
             language_output="<img src=\"https://img.shields.io/badge/TypeScript-3178C6?style=flat&logo=typescript&logoColor=white\" alt=\"TypeScript\" height=\"$badge_height\"/>"
             ;;
        html|html5)
            language_output="<img src=\"https://img.shields.io/badge/HTML5-E34F26?style=flat&logo=html5&logoColor=white\" alt=\"HTML5\" height=\"$badge_height\"/>"
            ;;
        css|css3)
            language_output="<img src=\"https://img.shields.io/badge/CSS3-1572B6?style=flat&logo=css3&logoColor=white\" alt=\"CSS3\" height=\"$badge_height\"/>"
            ;;
        scss)
             language_output="<img src=\"https://img.shields.io/badge/SCSS-CC6699?style=flat&logo=sass&logoColor=white\" alt=\"SCSS\" height=\"$badge_height\"/>"
             ;;
        shell|bash)
             language_output="<img src=\"https://img.shields.io/badge/Shell-4EAA25?style=flat&logo=gnubash&logoColor=white\" alt=\"Shell\" height=\"$badge_height\"/>"
             ;;
        ruby)
             language_output="<img src=\"https://img.shields.io/badge/Ruby-CC342D?style=flat&logo=ruby&logoColor=white\" alt=\"Ruby\" height=\"$badge_height\"/>"
             ;;
        rust)
             language_output="<img src=\"https://img.shields.io/badge/Rust-DEA584?style=flat&logo=rust&logoColor=black\" alt=\"Rust\" height=\"$badge_height\"/>"
             ;;
        java)
             language_output="<img src=\"https://img.shields.io/badge/Java-007396?style=flat&logo=openjdk&logoColor=white\" alt=\"Java\" height=\"$badge_height\"/>"
             ;;
        php)
             language_output="<img src=\"https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white\" alt=\"PHP\" height=\"$badge_height\"/>"
             ;;
        go)
             language_output="<img src=\"https://img.shields.io/badge/Go-00ADD8?style=flat&logo=go&logoColor=white\" alt=\"Go\" height=\"$badge_height\"/>"
             ;;
        markdown)
             language_output="<img src=\"https://img.shields.io/badge/Markdown-083958?style=flat&logo=markdown&logoColor=white\" alt=\"Markdown\" height=\"$badge_height\"/>"
             ;;
        c)
             language_output="<img src=\"https://img.shields.io/badge/C-A8B9CC?style=flat&logo=c&logoColor=black\" alt=\"C\" height=\"$badge_height\"/>"
             ;;
        lua)
             language_output="<img src=\"https://img.shields.io/badge/Lua-2C2D72?style=flat&logo=lua&logoColor=white\" alt=\"Lua\" height=\"$badge_height\"/>"
             ;;
        swift)
             language_output="<img src=\"https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white\" alt=\"Swift\" height=\"$badge_height\"/>"
             ;;
        kotlin)
             language_output="<img src=\"https://img.shields.io/badge/Kotlin-7F52B2?style=flat&logo=kotlin&logoColor=white\" alt=\"Kotlin\" height=\"$badge_height\"/>"
             ;;
        scala)
             language_output="<img src=\"https://img.shields.io/badge/Scala-DC322F?style=flat&logo=scala&logoColor=white\" alt=\"Scala\" height=\"$badge_height\"/>"
             ;;
        haskell)
             language_output="<img src=\"https://img.shields.io/badge/Haskell-5D4F85?style=flat&logo=haskell&logoColor=white\" alt=\"Haskell\" height=\"$badge_height\"/>"
             ;;
        csharp)
             language_output="<img src=\"https://img.shields.io/badge/C%23-239120?style=flat&logo=csharp&logoColor=white\" alt=\"C#\" height=\"$badge_height\"/>"
             ;;
        typescriptreact)
             language_output="<img src=\"https://img.shields.io/badge/TypeScript%20React-3178C6?style=flat&logo=typescript&logoColor=white\" alt=\"TypeScript React\" height=\"$badge_height\"/>"
             ;;
        # Add more languages and badges here as needed
        *)
            # fallback: display language name as text
            if [[ "$language" == "N/A" || -z "$language" || "$language" == "null" ]]; then
                 language_output="N/A"
            else
                 language_output="$language"
            fi
            ;;
    esac
    echo "$language_output"
}

# Function to generate list item
# Arguments: index, repo_name, description, language, output_target
generate_repo_list() {
    local index="$1" # Index is kept but not displayed by default
    local repo_name="$2"
    local description="$3"
    local language="$4"
    local output_target="$5"

    local repo_base_name=$(basename "$repo_name")
    local repo_hyperlink="<a href=\"https://github.com/$repo_name\">$repo_name</a>"

    # Get language badge/text using helper function
    local language_output
    language_output=$(get_language_output "$language")

    # Other badges (fixed height for consistency)
    local badge_height=20
    local stars_badge="<a href=\"https://github.com/$repo_name/stargazers\"><img alt=\"Stars\" src=\"https://img.shields.io/github/stars/$repo_name?style=flat\" height=\"$badge_height\"/></a>"
    local forks_badge="<a href=\"https://github.com/$repo_name/network/members\"><img alt=\"Forks\" src=\"https://img.shields.io/github/forks/$repo_name?style=flat\" height=\"$badge_height\"/></a>"
    local license_badge="<a href=\"https://github.com/$repo_name\"><img alt=\"License\" src=\"https://img.shields.io/github/license/$repo_name?style=flat\" height=\"$badge_height\"/></a>"


    # Output format for list item
    printf "## %s\n" "$repo_base_name" >> "$output_target"
    printf -- "- URL: %s\n" "$repo_hyperlink" >> "$output_target"
    printf -- "- Description: %s\n" "$description" >> "$output_target"
    printf -- "- %s %s %s %s\n\n" "$language_output" "$stars_badge" "$forks_badge" "$license_badge" >> "$output_target"
}

# Function to generate table row
# Arguments: index, repo_name, description, language, pushed_at_iso, output_target
generate_repo_table() {
    local index="$1"
    local repo_name="$2"
    local description="$3"
    local language="$4"
    local pushed_at_iso="$5"
    local output_target="$6"

    local repo_base_name=$(basename "$repo_name")
    local repo_hyperlink="<a href=\"https://github.com/$repo_name\">$repo_base_name</a>"
    local badge_height=20 # Consistent height for badges

    # Get language badge/text using helper function
    local language_output
    language_output=$(get_language_output "$language")

    local stars_badge="<a href=\"https://github.com/$repo_name/stargazers\"><img alt=\"Stars\" src=\"https://img.shields.io/github/stars/$repo_name?style=flat\" height=\"$badge_height\"/></a>"
    local forks_badge="<a href=\"https://github.com/$repo_name/network/members\"><img alt=\"Forks\" src=\"https://img.shields.io/github/forks/$repo_name?style=flat\" height=\"$badge_height\"/></a>"
    local license_badge="<a href=\"https://github.com/$repo_name\"><img alt=\"License\" src=\"https://img.shields.io/github/license/$repo_name?style=flat\" height=\"$badge_height\"/></a>"

    # Format the pushed_at date (YYYY-MM-DD)
    local pushed_at_formatted="N/A"
    if [[ -n "$pushed_at_iso" && "$pushed_at_iso" != "null" ]]; then
        pushed_at_formatted=$(date -d "$pushed_at_iso" +'%Y-%m-%d' 2>/dev/null || echo "Invalid Date")
        if [[ "$pushed_at_formatted" == "Invalid Date" ]]; then
             pushed_at_formatted="${pushed_at_iso%%T*}"
        fi
    fi

    # Add header in the first run (only if index is 1)
    if [[ "$index" -eq 1 ]]; then
        # Updated header - removed ID column
        printf "\n| Repository   | Description                                | Last Push  | Language | Stars | Forks | License |\n" >> "$output_target"
        printf "| :----------- | :----------------------------------------- | :--------- | :------- | :---- | :---- | :------ |\n" >> "$output_target"
    fi

    # Escape pipe characters within the description
    local safe_description="${description//|/\\|}"

    # Print the table row - removed index/$index
    printf "| %s | %s | %s | %s | %s | %s | %s |\n" \
        "$repo_hyperlink" \
        "$safe_description" \
        "$pushed_at_formatted" \
        "$language_output" \
        "$stars_badge" \
        "$forks_badge" \
        "$license_badge" \
        >> "$output_target"
}


# Prepare curl options
CURL_OPTS=(-s -L -w '\n%{http_code}')
AUTH_HEADER=()
if [[ -n "$GITHUB_TOKEN" ]]; then
  echo "INFO: Using GITHUB_TOKEN for authenticated requests."
  AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
else
  echo "INFO: Making unauthenticated requests (rate limits apply)."
fi

# Start output file
echo "INFO: Creating/overwriting output file: $OUTPUT_FILE"
printf "<h1 align=\"center\">Repositories Landscape 💎</h1>\n" > "$OUTPUT_FILE"
printf "<p align=\"center\">Welcome to the %s repositories landscape 👋</p>\n\n" "$GITHUB_OWNER" >> "$OUTPUT_FILE"
printf "If you want to create your own repository landscape similar to this, please follow this [**guide**](./create-repo-landscape.md) 📖\n\n" >> "$OUTPUT_FILE"

# Initialize counters
index=1
processed_count=0
error_count=0

# Read the repository list file line by line
while IFS= read -r repo_name || [[ -n "$repo_name" ]]; do
    repo_name=$(echo "$repo_name" | xargs)
    if [[ -z "$repo_name" || "$repo_name" == \#* ]]; then continue; fi
    if ! [[ "$repo_name" =~ ^[^/]+/[^/]+$ ]]; then
        echo "WARN: Skipping invalid repository format on line $index: '$repo_name'." >&2
        ((error_count++)); continue
    fi

    echo "INFO: Processing repo #$index: $repo_name..."
    api_url="https://api.github.com/repos/$repo_name"
    http_response=$(curl "${CURL_OPTS[@]}" "${AUTH_HEADER[@]}" "$api_url")
    http_code=$(printf "%s" "$http_response" | tail -n1)
    response_body=$(printf "%s" "$http_response" | sed '$ d')

    if [[ "$http_code" -ne 200 ]]; then
        echo "ERROR: Failed to fetch data for '$repo_name'. HTTP Status: $http_code." >&2
        error_message=$(echo "$response_body" | jq -r '.message // "No specific error message found."')
        echo "       Error details: $error_message" >&2
        ((error_count++))
        if [[ "$http_code" -eq 403 || "$http_code" -eq 429 ]]; then
            echo "WARN: Rate limit likely hit. Sleeping for 5 seconds..." >&2; sleep 5
        fi
        sleep 1; continue
    fi

    # Extract needed fields: description, language, and pushed_at
    data_line=$(echo "$response_body" | jq -e -r '[.description // "N/A", .language // "N/A", .pushed_at // ""] | @tsv')
    jq_exit_code=$?

    if [[ $jq_exit_code -ne 0 && $jq_exit_code -ne 4 ]]; then
        # jq failed for a reason other than null output (exit code 4 is ok)
        echo "ERROR: Failed to parse JSON data for '$repo_name' with jq." >&2
        ((error_count++)); sleep 1; continue
    fi

    # Read tab-separated values into variables
    IFS=$'\t' read -r description language pushed_at_iso <<< "$data_line"

    # Generate output based on mode
    if [[ "$MODE" == "table" ]]; then
        # Pass the extracted language text to the table function
        generate_repo_table "$index" "$repo_name" "$description" "$language" "$pushed_at_iso" "$OUTPUT_FILE"
    else
        # Pass the extracted language text to the list function
        generate_repo_list "$index" "$repo_name" "$description" "$language" "$OUTPUT_FILE"
    fi

    ((processed_count++))
    ((index++))
    sleep 1 # Be nice to the GitHub API

done < "$REPOSITORY_LIST"

# Add footer link
printf "\nFor a full list of repositories, click [**here**](https://github.com/${GITHUB_OWNER}?tab=repositories&q=&type=&language=&sort=stargazers).\n" >> "$OUTPUT_FILE"

echo "----------------------------------------"
echo "Script finished."
echo "Processed repositories: $processed_count"
echo "Errors/Skipped lines: $error_count"
echo "Output written to: $OUTPUT_FILE"
echo "----------------------------------------"

exit 0
