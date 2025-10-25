#!/bin/bash
# Validation script for updated Ansible cloud-init configuration

echo "=== Validating Updated Ansible Cloud-Init Configuration ==="

echo "1. Checking Ansible inventory syntax..."
ansible-inventory -i inventory.yml --list > /dev/null && echo "✅ Inventory syntax valid" || echo "❌ Inventory syntax error"

echo "2. Checking template syntax..."
# Create a temporary file to test template rendering
cat > /tmp/test-vars.yml << EOF
vm_config:
  vm_name: "test-vm"
  vm_hostname: "test-host"
  vm_static_ip: "192.168.122.99"
  vm_memory: 2048
  vm_vcpus: 2
  vm_packages: ["htop", "curl"]
EOF

# Test template rendering
python3 -c "
import yaml
from jinja2 import Template

# Load test variables
with open('/tmp/test-vars.yml', 'r') as f:
    vars_data = yaml.safe_load(f)

# Load and render template
with open('templates/user-data.j2', 'r') as f:
    template = Template(f.read())

try:
    result = template.render(vars_data)
    print('✅ Template syntax valid')
except Exception as e:
    print(f'❌ Template error: {e}')
" && rm -f /tmp/test-vars.yml

echo "3. Checking if required variables are defined in inventory..."
python3 -c "
import yaml
with open('inventory.yml', 'r') as f:
    inventory = yaml.safe_load(f)

required_vars = ['vm_static_ip', 'vm_hostname']
vms = inventory['all']['children']['vms']['hosts']

for vm_name, vm_config in vms.items():
    if 'gpu' not in vm_name:  # Skip GPU VMs for now
        missing = [var for var in required_vars if var not in vm_config]
        if missing:
            print(f'❌ {vm_name} missing: {missing}')
        else:
            print(f'✅ {vm_name} has all required variables')
"

echo "4. Checking file structure..."
FILES=(
    "templates/user-data.j2"
    "templates/meta-data.j2" 
    "templates/vm-config.xml.j2"
    "inventory.yml"
    "create-vm.yml"
    "group_vars/all.yml"
)

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

echo "5. Checking if cloud-init template uses new approach..."
if grep -q "DEPLOYMENT-TIME" templates/user-data.j2; then
    echo "✅ Template uses new deployment-time approach"
else
    echo "❌ Template may still use old approach"
fi

if grep -q "vm_static_ip" templates/user-data.j2; then
    echo "✅ Template supports static IP configuration"
else
    echo "❌ Template missing static IP support"
fi

echo ""
echo "=== Validation Complete ==="
echo "If all checks pass, the configuration is ready for the new workflow:"
echo "1. Build clean base image: make build-image"
echo "2. Deploy VM: make cloud-vm"
