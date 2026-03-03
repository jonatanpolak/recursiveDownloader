#!/bin/bash
# WSDL/Schema Downloader

set -euo pipefail

# wget parameters:
# -T 60: timeout of 60 sec
# -nv: non verbose
# -nc: skip downloads that would download to existing files
# --secure-protocol=TLSv1_2: use TLSv1.2 (modern security)
# --no-check-certificate: for development/internal servers
# --timeout=60: connection timeout
wget_params="-T 60 -nv -nc --secure-protocol=TLSv1_2 --no-check-certificate --timeout=60"

# ANSI colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

output_dir="output"

function help() {
    echo "Usage: $0 <WSDL_URL>"
    echo ""
    echo "Downloads a WSDL file and all its dependent XSD schemas."
    echo ""
    echo "Example:"
    echo "  $0 https://graphical.weather.gov/xml/SOAP_server/ndfdXMLserver.php?wsdl"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -o, --output   Output directory (default: output)"
    echo "  -v, --verbose  Verbose output"
}

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function download() {
    local url="$1"
    local output_path="$2"

    # Extract filename from URL
    local filename
    filename=$(basename "$url")

    if [[ -z "$filename" ]]; then
        log_error "Empty filename for URL: $url"
        return 1
    fi

    # Skip if file already exists
    if [[ -f "$output_path/$filename" ]]; then
        log_info "Skipping (already exists): $filename"
        return 0
    fi

    log_info "Downloading: $filename"

    # Download with wget
    if wget $wget_params -O "$output_path/$filename" "$url" 2>/dev/null; then
        log_info "Downloaded: $filename"
        return 0
    else
        log_error "Failed to download: $url"
        return 1
    fi
}

# Extract all schemaLocation values from an XML file (handles various namespace prefixes)
function extract_schema_locations() {
    local file="$1"

    # Use grep with various patterns to catch different namespace prefixes
    # Handles: schemaLocation, WL5G3N*:schemaLocation, xsd:schemaLocation, etc.
    grep -oE 'schemaLocation=["'\'']([^"'\'']+)["'\'']' "$file" 2>/dev/null | \
        sed -E 's/schemaLocation=["'\'']([^"'\'']+)["'\'']/\1/g' | \
        grep -v '^$' || true
}

# Check if URL is absolute (starts with http:// or https://)
function is_absolute_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]]
}

# Resolve relative URL against base URL
function resolve_url() {
    local base_url="$1"
    local relative_url="$2"

    # If already absolute, return as-is
    if is_absolute_url "$relative_url"; then
        echo "$relative_url"
        return
    fi

    # Decode URL-encoded characters for path manipulation
    local decoded_base
    decoded_base=$(printf '%s' "$base_url" | sed 's/%2F/\//g')

    # Get the base directory
    local base_dir
    base_dir=$(dirname "$decoded_base")

    # Handle relative paths starting with /
    if [[ "$relative_url" == /* ]]; then
        # Extract scheme and host from base URL
        local scheme_host
        scheme_host=$(echo "$decoded_base" | sed -E 's^(https?://[^/]+).*^\1^')
        echo "$scheme_host$relative_url"
    else
        # Relative path - combine base dir with relative path
        echo "$base_dir/$relative_url"
    fi
}

# Recursively download all dependencies
function download_dependencies() {
    local file="$1"
    local base_url="$2"
    local depth="${3:-0}"

    # Prevent infinite recursion
    if [[ $depth -gt 10 ]]; then
        log_warn "Max recursion depth reached for: $file"
        return
    fi

    local schema_locations
    schema_locations=$(extract_schema_locations "$file")

    if [[ -z "$schema_locations" ]]; then
        log_info "No more dependencies for: $file"
        return
    fi

    for schema_url in $schema_locations; do
        # Decode URL-encoded characters
        local decoded_url
        decoded_url=$(printf '%s' "$schema_url" | sed 's/%2F/\//g; s/%3A/:/g')

        # Resolve against base URL
        local resolved_url
        resolved_url=$(resolve_url "$base_url" "$decoded_url")

        # Download the schema
        if download "$resolved_url" "$output_dir"; then
            local filename
            filename=$(basename "$resolved_url")
            # Recursively process the downloaded file
            download_dependencies "$output_dir/$filename" "$resolved_url" $((depth + 1))
        fi
    done
}

# Main execution
function main() {
    local verbose=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                help
                exit 0
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                help
                exit 1
                ;;
            *)
                if [[ -z "${wsdl_url:-}" ]]; then
                    wsdl_url="$1"
                else
                    log_error "Multiple WSDL URLs provided"
                    help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Check if URL was provided
    if [[ -z "${wsdl_url:-}" ]]; then
        log_error "WSDL URL is required"
        help
        exit 1
    fi

    log_info "WSDL Fetcher - Starting download"
    log_info "URL: $wsdl_url"
    log_info "Output directory: $output_dir"
    echo ""

    # Create output directory
    mkdir -p "$output_dir"

    # Extract server path from URL
    local server_path
    server_path=$(dirname "$wsdl_url")

    # Download the main WSDL file
    download "$wsdl_url" "$output_dir"

    # Get the filename
    local filename
    filename=$(basename "$wsdl_url")

    # Process dependencies
    if [[ -f "$output_dir/$filename" ]]; then
        download_dependencies "$output_dir/$filename" "$wsdl_url" 0
    fi

    echo ""
    log_info "Download complete!"
    log_info "Files saved to: $output_dir/"
    ls -la "$output_dir/"
}

# Run main function
main "$@"
