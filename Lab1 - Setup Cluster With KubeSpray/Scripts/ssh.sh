#!/bin/bash

TARGET_VM1="10.10.10.11"
TARGET_VM2="10.10.10.12"
SSH_USER="vagrant"
SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"


GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


print_status() {
    echo -e "${YELLOW}[*] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

print_status "Setting up SSH for Vagrant VMs with username 'vagrant'..."

if [ ! -d "$SSH_DIR" ]; then
    print_status "Creating SSH directory..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

if [ ! -f "$SSH_DIR/id_rsa" ]; then
    print_status "No SSH key found. Generating new SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N "" -C "$SSH_USER@$(hostname)"
    print_success "SSH key pair generated successfully!"
else
    print_status "Using existing SSH key at $SSH_DIR/id_rsa"
fi

print_status "Configuring SSH settings..."

if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d%H%M%S)"
fi

cat << EOF > "$CONFIG_FILE"


Host vm1
    HostName $TARGET_VM1
    User $SSH_USER
    IdentityFile $SSH_DIR/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60

Host vm2
    HostName $TARGET_VM2
    User $SSH_USER
    IdentityFile $SSH_DIR/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
EOF

chmod 600 "$CONFIG_FILE"
print_success "SSH config created at $CONFIG_FILE"


print_status "Locating Vagrant private key..."

INSECURE_KEY_LOCATIONS=(
    "$HOME/.vagrant.d/insecure_private_key"
    "/opt/vagrant/embedded/gems/gems/vagrant-*/keys/vagrant"
    "/usr/share/vagrant/keys/vagrant"
    "$(find $HOME -name "insecure_private_key" 2>/dev/null | head -1)"
)

VAGRANT_KEY=""
for key_location in "${INSECURE_KEY_LOCATIONS[@]}"; do
    if [ -f "$(eval echo $key_location)" ]; then
        VAGRANT_KEY="$(eval echo $key_location)"
        print_success "Found Vagrant key at $VAGRANT_KEY"
        break
    fi
done

if [ -z "$VAGRANT_KEY" ]; then
    print_status "No standard Vagrant key found. Looking in current directory..."
    
    VAGRANTFILE=$(find . -name Vagrantfile -type f 2>/dev/null | head -1)
    if [ -n "$VAGRANTFILE" ]; then
        VAGRANT_DIR=$(dirname "$VAGRANTFILE")
        print_status "Found Vagrantfile in $VAGRANT_DIR"
        
        
        if [ -d "$VAGRANT_DIR/.vagrant" ]; then
            MACHINE_KEY=$(find "$VAGRANT_DIR/.vagrant" -name "private_key" 2>/dev/null | head -1)
            if [ -n "$MACHINE_KEY" ]; then
                VAGRANT_KEY="$MACHINE_KEY"
                print_success "Found Vagrant machine key at $VAGRANT_KEY"
            fi
        fi
    fi
fi

if [ -n "$VAGRANT_KEY" ]; then
    sed -i "s|IdentityFile $SSH_DIR/id_rsa|IdentityFile $VAGRANT_KEY|g" "$CONFIG_FILE"
    chmod 600 "$VAGRANT_KEY" 2>/dev/null || print_status "Could not change permissions on key file (may need sudo)"
    
    print_status "Updated SSH config to use Vagrant key"
else
    print_status "No Vagrant private key found. You may need to manually specify the correct key."
fi


copy_ssh_key() {
    local vm=$1
    local ip=$2
    
    print_status "Setting up passwordless SSH to $vm ($ip)..."
    
    if [ -n "$VAGRANT_KEY" ]; then

        if ssh -i "$VAGRANT_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER@$ip" "echo 'Connection test'"; then
            print_success "Successfully connected to $vm using Vagrant key"
            

            cat "$SSH_DIR/id_rsa.pub" | ssh -i "$VAGRANT_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$ip" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

            if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$vm" "echo 'Connection to $vm with new key successful!'"; then
                print_success "Successfully configured passwordless SSH to $vm"

                sed -i "/Host $vm/,/Host/ s|IdentityFile $VAGRANT_KEY|IdentityFile $SSH_DIR/id_rsa|g" "$CONFIG_FILE"
            else
                print_status "Could not connect with new key. Keeping Vagrant key in config."
            fi
        else
            print_status "Could not connect to $vm using Vagrant key"
        fi
    else
        print_status "No Vagrant key found, cannot set up passwordless SSH to $vm"
    fi
}

copy_ssh_key "vm1" "$TARGET_VM1"
copy_ssh_key "vm2" "$TARGET_VM2"

print_status "Setup complete!"
echo "  Can connect to the VMs using:"
echo "  ssh vm1  (connects to $TARGET_VM1)"
echo "  ssh vm2  (connects to $TARGET_VM2)"

echo ""
echo "If connections fail, you may need to:"
echo "1. Find the correct Vagrant private key (often in ~/.vagrant.d/insecure_private_key)"
echo "2. Edit $CONFIG_FILE to use the correct key path"
echo "3. Or use 'vagrant ssh' from your Vagrantfile directory"
