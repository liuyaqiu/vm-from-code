#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get the latest Packer version
get_latest_packer_version() {
    curl -s https://api.github.com/repos/hashicorp/packer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")'
}

# Function to install Packer
install_packer() {
    print_info "Installing HashiCorp Packer..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        i386|i686)
            ARCH="386"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Get latest version
    print_info "Fetching latest Packer version..."
    VERSION=$(get_latest_packer_version)
    if [ -z "$VERSION" ]; then
        print_warning "Could not fetch latest version, using fallback version 1.10.0"
        VERSION="v1.10.0"
    fi
    VERSION_NUMBER=${VERSION#v}  # Remove 'v' prefix
    
    print_info "Latest Packer version: $VERSION"
    
    # Download URL
    DOWNLOAD_URL="https://releases.hashicorp.com/packer/${VERSION_NUMBER}/packer_${VERSION_NUMBER}_${OS}_${ARCH}.zip"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    print_info "Downloading Packer from: $DOWNLOAD_URL"
    
    # Download Packer
    if command_exists curl; then
        curl -LO "$DOWNLOAD_URL"
    elif command_exists wget; then
        wget "$DOWNLOAD_URL"
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    # Extract Packer
    print_info "Extracting Packer..."
    unzip -q "packer_${VERSION_NUMBER}_${OS}_${ARCH}.zip"
    
    # Install Packer
    if [ -w "/usr/local/bin" ] || [ "$(id -u)" -eq 0 ]; then
        # Install globally if we have permissions
        sudo cp packer /usr/local/bin/
        sudo chmod +x /usr/local/bin/packer
        print_success "Packer installed globally to /usr/local/bin/packer"
    else
        # Install to user's local bin directory
        mkdir -p "$HOME/.local/bin"
        cp packer "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/packer"
        print_success "Packer installed to $HOME/.local/bin/packer"
        
        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            print_warning "Add $HOME/.local/bin to your PATH:"
            echo "  echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc"
            echo "  source ~/.bashrc"
        fi
    fi
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$TEMP_DIR"
    
    # Verify installation
    if command_exists packer; then
        INSTALLED_VERSION=$(packer version | head -n1)
        print_success "Packer installation verified: $INSTALLED_VERSION"
    else
        print_error "Packer installation verification failed"
        exit 1
    fi
}

# Function to install via package manager (if available)
install_via_package_manager() {
    if command_exists apt-get; then
        print_info "Installing Packer via apt package manager..."
        # Add HashiCorp repository
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update
        sudo apt-get install -y packer
        return 0
    elif command_exists yum; then
        print_info "Installing Packer via yum package manager..."
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        sudo yum install -y packer
        return 0
    elif command_exists dnf; then
        print_info "Installing Packer via dnf package manager..."
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
        sudo dnf install -y packer
        return 0
    elif command_exists brew; then
        print_info "Installing Packer via Homebrew..."
        brew install packer
        return 0
    else
        return 1
    fi
}

# Main installation logic
main() {
    print_info "HashiCorp Packer Installation Script"
    echo "======================================"
    
    # Check if Packer is already installed
    if command_exists packer; then
        CURRENT_VERSION=$(packer version | head -n1)
        print_success "Packer is already installed: $CURRENT_VERSION"
        
        # Ask if user wants to update
        read -p "Do you want to update to the latest version? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping current Packer installation."
            exit 0
        fi
    fi
    
    # Check for required dependencies
    if ! command_exists curl && ! command_exists wget; then
        print_error "Neither curl nor wget is available. Installing wget..."
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y wget
        elif command_exists yum; then
            sudo yum install -y wget
        elif command_exists dnf; then
            sudo dnf install -y wget
        else
            print_error "Could not install wget. Please install curl or wget manually."
            exit 1
        fi
    fi
    
    if ! command_exists unzip; then
        print_info "Installing unzip..."
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y unzip
        elif command_exists yum; then
            sudo yum install -y unzip
        elif command_exists dnf; then
            sudo dnf install -y unzip
        else
            print_error "Could not install unzip. Please install it manually."
            exit 1
        fi
    fi
    
    # Try package manager first, fall back to manual installation
    print_info "Attempting installation via package manager..."
    if install_via_package_manager; then
        print_success "Packer installed successfully via package manager!"
    else
        print_info "Package manager installation not available, using manual installation..."
        install_packer
    fi
    
    print_success "Packer installation completed!"
    print_info "You can now run: packer version"
}

# Check if script is run with sudo when not needed
if [ "$(id -u)" -eq 0 ] && [ "$1" != "--force-root" ]; then
    print_warning "This script doesn't need to be run as root."
    print_warning "Run without sudo for user installation, or with --force-root if you really want system-wide installation."
    exit 1
fi

# Run main function
main "$@"
