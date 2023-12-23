#!/bin/bash
set -e

if [ ! command -v docker &> /dev/null ]; then
    sudo dnf install moby-engine docker-compose -y    
    # moby/docker still uses old cgroups
    sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
    # sudo groupadd docker # no longer needed
    sudo usermod -aG docker ${USER}
    #sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0 # no longer needed?
    sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-masquerade
    sudo systemctl enable docker
    exit 0;
fi