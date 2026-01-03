#!/bin/bash
#
# OzScan - Security Scanning Automation Tool
# Copyright (C) 2024 0zk3y
# License: GNU General Public License v3
#
# Integrates: Subfinder, HTTPX, Katana, Nuclei, SQLMap, DNSx, GF, WaybackURLs
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly VERSION="2.0.0"
readonly SCRIPT_NAME="OzScan"
readonly SQLMAP_LEVEL="${OZSCAN_SQLMAP_LEVEL:-2}"
readonly SQLMAP_RISK="${OZSCAN_SQLMAP_RISK:-1}"

#==============================================================================
# Utility Functions
#==============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "  ___       ____"
    echo " / _ \ ____/ ___|  ___ __ _ _ __"
    echo "| | | |_  /\___ \ / __/ _\` | '_ \\"
    echo "| |_| |/ /  ___) | (_| (_| | | | |"
    echo " \___//___||____/ \___\__,_|_| |_|"
    echo -e "${NC}"
    echo -e "${BLUE}Version: ${VERSION}${NC}"
    echo -e "${BLUE}Security Scanning Automation Tool${NC}"
    echo ""
}

print_separator() {
    echo -e "${BLUE}$(printf '=%.0s' {1..80})${NC}"
}

log_info() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[-]${NC} $1" >&2
}

log_progress() {
    echo -e "${CYAN}[*]${NC} $1"
}

show_help() {
    print_banner
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --version           Show version"
    echo "  -d, --domain DOMAIN     Target domain (non-interactive mode)"
    echo "  -t, --type TYPE         Scan type 1-5 (non-interactive mode)"
    echo "  -i, --install-only      Only install dependencies, don't scan"
    echo "  --sqlmap-level LEVEL    SQLMap level 1-5 (default: 2)"
    echo "  --sqlmap-risk RISK      SQLMap risk 1-3 (default: 1)"
    echo ""
    echo "Scan Types:"
    echo "  1  List subdomains only"
    echo "  2  Nuclei scan over provided URL endpoints"
    echo "  3  Nuclei scan over all endpoints of all subdomains"
    echo "  4  Nuclei + SQLMap over SQLi parameters (single domain)"
    echo "  5  Nuclei + SQLMap over SQLi parameters (domain + subdomains)"
    echo ""
    echo "Environment Variables:"
    echo "  OZSCAN_SQLMAP_LEVEL     Default SQLMap level (1-5)"
    echo "  OZSCAN_SQLMAP_RISK      Default SQLMap risk (1-3)"
    echo ""
    echo "Examples:"
    echo "  $0                              # Interactive mode"
    echo "  $0 -d example.com -t 1          # Subdomain scan"
    echo "  $0 --install-only               # Install tools only"
    echo ""
    echo "Report issues: https://github.com/0zk3y/OzScan/issues"
    echo "Twitter: @0zk3y"
}

show_version() {
    echo "${SCRIPT_NAME} v${VERSION}"
}

#==============================================================================
# Package Manager Detection and Installation
#==============================================================================

detect_package_manager() {
    if command -v apt &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

detect_aur_helper() {
    if command -v paru &>/dev/null; then
        echo "paru"
    elif command -v yay &>/dev/null; then
        echo "yay"
    elif command -v pikaur &>/dev/null; then
        echo "pikaur"
    elif command -v trizen &>/dev/null; then
        echo "trizen"
    else
        echo "none"
    fi
}

install_go_if_missing() {
    if command -v go &>/dev/null; then
        log_info "Go is already installed: $(go version)"
        return 0
    fi

    log_warn "Go is not installed. Installing..."
    local pkg_manager
    pkg_manager=$(detect_package_manager)

    case "$pkg_manager" in
        apt)
            apt update && apt install -y golang-go
            ;;
        dnf|yum)
            $pkg_manager install -y golang
            ;;
        pacman)
            pacman -Sy --noconfirm go
            ;;
        zypper)
            zypper install -y go
            ;;
        apk)
            apk add --no-cache go
            ;;
        brew)
            brew install go
            ;;
        *)
            log_error "Cannot auto-install Go. Please install manually."
            return 1
            ;;
    esac

    # Verify installation
    if ! command -v go &>/dev/null; then
        log_error "Go installation failed"
        return 1
    fi
    log_info "Go installed successfully"
}

install_python_if_missing() {
    if command -v python3 &>/dev/null; then
        log_info "Python3 is already installed: $(python3 --version)"
        return 0
    fi

    log_warn "Python3 is not installed. Installing..."
    local pkg_manager
    pkg_manager=$(detect_package_manager)

    case "$pkg_manager" in
        apt)
            apt update && apt install -y python3 python3-pip
            ;;
        dnf|yum)
            $pkg_manager install -y python3 python3-pip
            ;;
        pacman)
            pacman -Sy --noconfirm python python-pip
            ;;
        zypper)
            zypper install -y python3 python3-pip
            ;;
        apk)
            apk add --no-cache python3 py3-pip
            ;;
        brew)
            brew install python3
            ;;
        *)
            log_error "Cannot auto-install Python3. Please install manually."
            return 1
            ;;
    esac

    if ! command -v python3 &>/dev/null; then
        log_error "Python3 installation failed"
        return 1
    fi
    log_info "Python3 installed successfully"
}

setup_go_path() {
    # Ensure GOPATH and GOBIN are set
    export GOPATH="${GOPATH:-$HOME/go}"
    export GOBIN="${GOBIN:-$GOPATH/bin}"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$GOBIN:"* ]]; then
        export PATH="$PATH:$GOBIN"
    fi

    # Create directories if they don't exist
    mkdir -p "$GOPATH" "$GOBIN"
}

install_tool() {
    local tool_name="$1"
    local go_package="$2"
    local alt_install="${3:-}"

    if command -v "$tool_name" &>/dev/null; then
        log_info "$tool_name is already installed"
        return 0
    fi

    log_progress "Installing $tool_name..."

    local pkg_manager
    pkg_manager=$(detect_package_manager)
    local aur_helper
    aur_helper=$(detect_aur_helper)

    # Try package manager first for common tools
    case "$tool_name" in
        sqlmap)
            case "$pkg_manager" in
                apt)
                    apt install -y sqlmap && return 0
                    ;;
                dnf|yum)
                    $pkg_manager install -y sqlmap && return 0
                    ;;
                pacman)
                    pacman -Sy --noconfirm sqlmap && return 0
                    ;;
                brew)
                    brew install sqlmap && return 0
                    ;;
            esac
            # Fallback to pip
            pip3 install --user sqlmap && return 0
            ;;
        nuclei|subfinder|httpx|katana|dnsx)
            # Check AUR for Arch-based systems
            if [[ "$pkg_manager" == "pacman" ]] && [[ "$aur_helper" != "none" ]]; then
                $aur_helper -S --noconfirm "${tool_name}-bin" 2>/dev/null && return 0
                $aur_helper -S --noconfirm "$tool_name" 2>/dev/null && return 0
            fi
            # Check brew
            if [[ "$pkg_manager" == "brew" ]]; then
                brew install "$tool_name" 2>/dev/null && return 0
            fi
            ;;
    esac

    # Fallback to Go install
    if [[ -n "$go_package" ]]; then
        setup_go_path
        if go install -v "${go_package}@latest"; then
            log_info "$tool_name installed via Go"
            return 0
        fi
    fi

    # Try alternative install method
    if [[ -n "$alt_install" ]]; then
        eval "$alt_install" && return 0
    fi

    log_error "Failed to install $tool_name"
    return 1
}

install_gf_patterns() {
    local gf_patterns_dir="$HOME/.gf"

    if [[ -d "$gf_patterns_dir" ]] && [[ -f "$gf_patterns_dir/sqli.json" ]]; then
        log_info "GF patterns already installed"
        return 0
    fi

    log_progress "Installing GF patterns..."
    mkdir -p "$gf_patterns_dir"

    # Clone tomnomnom's patterns
    local tmp_dir
    tmp_dir=$(mktemp -d)
    if git clone --depth=1 https://github.com/tomnomnom/gf.git "$tmp_dir/gf" 2>/dev/null; then
        cp -r "$tmp_dir/gf/examples/"* "$gf_patterns_dir/" 2>/dev/null || true
    fi

    # Clone additional patterns from 1ndianl33t
    if git clone --depth=1 https://github.com/1ndianl33t/Gf-Patterns.git "$tmp_dir/gf-patterns" 2>/dev/null; then
        cp -r "$tmp_dir/gf-patterns/"*.json "$gf_patterns_dir/" 2>/dev/null || true
    fi

    rm -rf "$tmp_dir"
    log_info "GF patterns installed to $gf_patterns_dir"
}

install_all_tools() {
    print_separator
    log_info "Installing/Verifying dependencies..."
    print_separator

    # Prerequisites
    install_go_if_missing || { log_error "Go is required"; exit 1; }
    install_python_if_missing || { log_error "Python is required"; exit 1; }
    setup_go_path

    # Security tools
    local tools_status=0

    install_tool "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder" || tools_status=1
    install_tool "httpx" "github.com/projectdiscovery/httpx/cmd/httpx" || tools_status=1
    install_tool "katana" "github.com/projectdiscovery/katana/cmd/katana" || tools_status=1
    install_tool "nuclei" "github.com/projectdiscovery/nuclei/v3/cmd/nuclei" || tools_status=1
    install_tool "dnsx" "github.com/projectdiscovery/dnsx/cmd/dnsx" || tools_status=1
    install_tool "gf" "github.com/tomnomnom/gf" || tools_status=1
    install_tool "waybackurls" "github.com/tomnomnom/waybackurls" || tools_status=1
    install_tool "sqlmap" "" "pip3 install --user sqlmap" || tools_status=1

    # Install GF patterns
    install_gf_patterns

    # Update nuclei templates
    if command -v nuclei &>/dev/null; then
        log_progress "Updating Nuclei templates..."
        nuclei -update-templates 2>/dev/null || log_warn "Could not update Nuclei templates"
    fi

    print_separator
    if [[ $tools_status -eq 0 ]]; then
        log_info "All tools installed successfully!"
    else
        log_warn "Some tools may not have installed correctly"
    fi
    print_separator

    return $tools_status
}

#==============================================================================
# Input Validation
#==============================================================================

validate_domain() {
    local domain="$1"

    # Check if empty
    if [[ -z "$domain" ]]; then
        log_error "Domain cannot be empty"
        return 1
    fi

    # Check for dangerous characters (command injection prevention)
    if [[ "$domain" =~ [[:space:]\;\|\&\$\`\(\)\{\}\[\]\<\>\!\#] ]]; then
        log_error "Domain contains invalid characters"
        return 1
    fi

    # Check for directory traversal
    if [[ "$domain" == *".."* ]] || [[ "$domain" == "/"* ]]; then
        log_error "Invalid domain format (path traversal detected)"
        return 1
    fi

    # Basic domain format validation
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$ ]]; then
        log_warn "Domain format may be invalid: $domain"
    fi

    return 0
}

validate_option() {
    local option="$1"

    if [[ ! "$option" =~ ^[1-5]$ ]]; then
        log_error "Invalid option. Please select 1-5"
        return 1
    fi
    return 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges"
        log_info "Please run: sudo $0"
        exit 1
    fi
}

#==============================================================================
# Scanning Functions
#==============================================================================

setup_output_dir() {
    local domain="$1"
    local output_dir="${domain}_scan_$(date +%Y%m%d_%H%M%S)"

    mkdir -p "$output_dir"
    cd "$output_dir" || exit 1

    echo "$output_dir"
}

run_subdomain_scan() {
    local domain="$1"

    log_progress "Running subdomain enumeration on $domain..."

    if ! subfinder --silent -d "$domain" -o subdomains.txt 2>/dev/null; then
        log_warn "Subfinder encountered issues, results may be incomplete"
    fi

    local count=0
    if [[ -f subdomains.txt ]]; then
        count=$(wc -l < subdomains.txt)
    fi

    log_info "Found $count subdomains"
}

run_httpx_probe() {
    local input_file="$1"
    local output_file="${2:-alive.txt}"

    if [[ ! -s "$input_file" ]]; then
        log_warn "No input for HTTPX (empty file: $input_file)"
        return 1
    fi

    log_progress "Probing for alive hosts..."
    httpx -l "$input_file" -silent -o "$output_file" 2>/dev/null || true

    local count=0
    if [[ -f "$output_file" ]]; then
        count=$(wc -l < "$output_file")
    fi

    log_info "Found $count alive hosts"
}

resolve_ips() {
    local input_file="$1"
    local output_file="${2:-ips.txt}"

    if [[ ! -s "$input_file" ]]; then
        log_warn "No subdomains to resolve"
        return 1
    fi

    log_progress "Resolving IP addresses..."

    # Use dnsx if available, fallback to getent
    if command -v dnsx &>/dev/null; then
        dnsx -l "$input_file" -silent -a -resp-only -o "$output_file" 2>/dev/null || true
    else
        while IFS= read -r subdomain; do
            getent hosts "$subdomain" 2>/dev/null | awk '{print $1}' >> "$output_file"
        done < "$input_file"
    fi

    # Deduplicate
    if [[ -f "$output_file" ]]; then
        sort -u "$output_file" -o "$output_file"
        local count
        count=$(wc -l < "$output_file")
        log_info "Resolved $count unique IPs"
    fi
}

run_katana_crawl() {
    local target="$1"
    local output_file="${2:-endpoints.txt}"
    local is_list="${3:-false}"

    log_progress "Crawling for endpoints..."

    if [[ "$is_list" == "true" ]]; then
        if [[ ! -s "$target" ]]; then
            log_warn "No targets for Katana"
            return 1
        fi
        katana -list "$target" -silent -o "$output_file" 2>/dev/null || true
    else
        katana -u "$target" -silent -o "$output_file" 2>/dev/null || true
    fi

    local count=0
    if [[ -f "$output_file" ]]; then
        count=$(wc -l < "$output_file")
    fi

    log_info "Found $count endpoints"
}

run_wayback_urls() {
    local domain="$1"
    local output_file="${2:-wayback_urls.txt}"

    log_progress "Fetching Wayback Machine URLs..."

    echo "$domain" | waybackurls > "$output_file" 2>/dev/null || true

    local count=0
    if [[ -f "$output_file" ]]; then
        count=$(wc -l < "$output_file")
    fi

    log_info "Found $count archived URLs"
}

run_gf_sqli() {
    local input_file="$1"
    local output_file="${2:-sqli_params.txt}"

    if [[ ! -s "$input_file" ]]; then
        log_warn "No URLs for SQLi pattern matching"
        return 1
    fi

    log_progress "Extracting potential SQLi parameters..."

    gf sqli < "$input_file" > "$output_file" 2>/dev/null || true

    local count=0
    if [[ -f "$output_file" ]]; then
        count=$(wc -l < "$output_file")
    fi

    log_info "Found $count potential SQLi parameters"
}

run_nuclei_scan() {
    local input_file="$1"
    local output_file="${2:-nuclei_results.txt}"

    if [[ ! -s "$input_file" ]]; then
        log_warn "No targets for Nuclei scan"
        return 1
    fi

    log_progress "Running Nuclei vulnerability scan..."

    nuclei -l "$input_file" -o "$output_file" 2>/dev/null || true

    local count=0
    if [[ -f "$output_file" ]]; then
        count=$(wc -l < "$output_file")
    fi

    log_info "Nuclei found $count results"
}

run_sqlmap_scan() {
    local input_file="$1"
    local level="${2:-$SQLMAP_LEVEL}"
    local risk="${3:-$SQLMAP_RISK}"

    if [[ ! -s "$input_file" ]]; then
        log_warn "No SQLi parameters for SQLMap"
        return 1
    fi

    local param_count
    param_count=$(wc -l < "$input_file")

    log_warn "SQLMap will test $param_count URLs with level=$level, risk=$risk"
    log_warn "This may take a long time and could be intrusive!"

    log_progress "Running SQLMap..."

    sqlmap -m "$input_file" --batch --level "$level" --risk "$risk" \
           --output-dir="./sqlmap_output" 2>/dev/null || true

    log_info "SQLMap results saved to ./sqlmap_output/"
}

print_results() {
    local domain="$1"
    local output_dir
    output_dir=$(pwd)

    print_separator
    log_info "Scan completed for: $domain"
    print_separator
    echo ""
    echo "Results saved in: $output_dir"
    echo ""

    echo "Files generated:"
    for file in *.txt; do
        if [[ -f "$file" ]]; then
            local lines
            lines=$(wc -l < "$file" 2>/dev/null || echo "0")
            printf "  %-25s %s lines\n" "$file" "$lines"
        fi
    done

    if [[ -d "sqlmap_output" ]]; then
        echo "  sqlmap_output/          (SQLMap results directory)"
    fi

    echo ""
    print_separator
    echo -e "${CYAN}Developed by 0zk3y${NC}"
    echo "Issues/PRs: https://github.com/0zk3y/OzScan"
    echo "Twitter: @0zk3y"
    print_separator
}

#==============================================================================
# Scan Type Implementations
#==============================================================================

scan_type_1() {
    local domain="$1"

    log_info "Scan Type 1: Subdomain Enumeration"
    print_separator

    run_subdomain_scan "$domain"
    run_httpx_probe "subdomains.txt" "alive.txt"
    resolve_ips "subdomains.txt" "ips.txt"

    print_results "$domain"
}

scan_type_2() {
    local domain="$1"

    log_info "Scan Type 2: Nuclei Scan on URL Endpoints"
    print_separator

    run_katana_crawl "https://$domain" "endpoints.txt"
    run_nuclei_scan "endpoints.txt" "nuclei_results.txt"

    print_results "$domain"
}

scan_type_3() {
    local domain="$1"

    log_info "Scan Type 3: Full Subdomain + Nuclei Scan"
    print_separator

    run_subdomain_scan "$domain"
    run_httpx_probe "subdomains.txt" "alive.txt"
    run_katana_crawl "alive.txt" "endpoints.txt" "true"
    run_nuclei_scan "endpoints.txt" "nuclei_results.txt"

    print_results "$domain"
}

scan_type_4() {
    local domain="$1"
    local sqlmap_level="${2:-$SQLMAP_LEVEL}"
    local sqlmap_risk="${3:-$SQLMAP_RISK}"

    log_info "Scan Type 4: Nuclei + SQLMap (Single Domain)"
    print_separator

    run_subdomain_scan "$domain"
    run_httpx_probe "subdomains.txt" "alive.txt"
    run_katana_crawl "alive.txt" "endpoints.txt" "true"
    run_wayback_urls "$domain" "wayback_urls.txt"

    # Combine URLs for SQLi testing
    cat endpoints.txt wayback_urls.txt 2>/dev/null | sort -u > all_urls.txt

    run_gf_sqli "all_urls.txt" "sqli_params.txt"
    run_nuclei_scan "endpoints.txt" "nuclei_results.txt"
    run_sqlmap_scan "sqli_params.txt" "$sqlmap_level" "$sqlmap_risk"

    print_results "$domain"
}

scan_type_5() {
    local domain="$1"
    local sqlmap_level="${2:-$SQLMAP_LEVEL}"
    local sqlmap_risk="${3:-$SQLMAP_RISK}"

    log_info "Scan Type 5: Full Nuclei + SQLMap (All Subdomains)"
    print_separator

    run_subdomain_scan "$domain"
    run_httpx_probe "subdomains.txt" "alive.txt"
    run_katana_crawl "alive.txt" "endpoints.txt" "true"

    # Get wayback URLs for all subdomains
    log_progress "Fetching Wayback URLs for all subdomains..."
    touch wayback_urls.txt
    while IFS= read -r subdomain; do
        echo "$subdomain" | waybackurls >> wayback_urls.txt 2>/dev/null || true
    done < subdomains.txt

    # Combine and dedupe
    cat endpoints.txt wayback_urls.txt 2>/dev/null | sort -u > all_urls.txt

    run_gf_sqli "all_urls.txt" "sqli_params.txt"
    run_nuclei_scan "endpoints.txt" "nuclei_results.txt"
    run_sqlmap_scan "sqli_params.txt" "$sqlmap_level" "$sqlmap_risk"

    print_results "$domain"
}

#==============================================================================
# Main
#==============================================================================

main() {
    local domain=""
    local scan_type=""
    local install_only=false
    local sqlmap_level="$SQLMAP_LEVEL"
    local sqlmap_risk="$SQLMAP_RISK"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            -t|--type)
                scan_type="$2"
                shift 2
                ;;
            -i|--install-only)
                install_only=true
                shift
                ;;
            --sqlmap-level)
                sqlmap_level="$2"
                shift 2
                ;;
            --sqlmap-risk)
                sqlmap_risk="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check root
    check_root

    # Print banner
    print_banner

    # Install tools
    install_all_tools || exit 1

    # Exit if install-only mode
    if [[ "$install_only" == true ]]; then
        log_info "Installation complete. Exiting."
        exit 0
    fi

    # Interactive mode if domain not provided
    if [[ -z "$domain" ]]; then
        echo ""
        echo -n "Enter target domain: "
        read -r domain
    fi

    # Validate domain
    validate_domain "$domain" || exit 1

    # Interactive mode if scan type not provided
    if [[ -z "$scan_type" ]]; then
        echo ""
        echo "Select scan type:"
        echo "  1. Subdomain enumeration only"
        echo "  2. Nuclei scan on URL endpoints"
        echo "  3. Full subdomain + Nuclei scan"
        echo "  4. Nuclei + SQLMap (single domain)"
        echo "  5. Nuclei + SQLMap (all subdomains)"
        echo ""
        echo -n "Enter option [1-5]: "
        read -r scan_type
    fi

    # Validate option
    validate_option "$scan_type" || exit 1

    # Setup output directory
    print_separator
    log_info "Target: $domain"
    log_info "Scan Type: $scan_type"
    print_separator

    local output_dir
    output_dir=$(setup_output_dir "$domain")
    log_info "Output directory: $output_dir"

    # Run selected scan
    case "$scan_type" in
        1) scan_type_1 "$domain" ;;
        2) scan_type_2 "$domain" ;;
        3) scan_type_3 "$domain" ;;
        4) scan_type_4 "$domain" "$sqlmap_level" "$sqlmap_risk" ;;
        5) scan_type_5 "$domain" "$sqlmap_level" "$sqlmap_risk" ;;
    esac

    exit 0
}

# Run main function
main "$@"
