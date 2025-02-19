#!/bin/bash

#  Get the list of VM names and store them in an array
vm_names=() # Initialize an empty array

vm_extracted_names=$(VBoxManage list vms | awk -F '"' '{print $2}')

# Get IP addresses of VM's(Bridged Networking)
vm_ips=()

# Number of VM's
num_of_vms=$(VBoxManage list vms | wc -l)
# Number of active VM's
active_vms=$(VBoxManage list runningvms | wc -l)

# Initialize arrays
active_node_ids=()
active_node_names=()
active_node_ips=()

# Get active SSH process IDs and names
num_active_nodes=$(pgrep -a ssh | awk '$2 == "ssh" {print $1, $3}' | wc -l)
active_ids=$(pgrep -a ssh | awk '$2 == "ssh" {print $1}')
active_names=$(pgrep -a ssh | awk '$2 == "ssh" {split($3, parts, "@"); print parts[1]}')
active_ips=$(pgrep -a ssh | awk '$2 == "ssh" {split($3, parts, "@"); print parts[2]}')


# ANSI colour codes for terminal output
BOLD=$'\e[1m'
NORMAL=$'\e[0m'  # To reset back to normal text
GREEN=$'\e[32m'  # 2 is the color code for green
NC=$'\e[0m'        # Reset color
RED=$'\e[31m'
GRAY=$'\e[0;37m'
AMBER=$'\e[0;33m'
BLUE=$'\e[0;34m'
YELLOW=$'\e[0;33m'
HI_YELLOW=$'\e[0;93m'
BHI_YELLOW=$'\e[1;93m'

while IFS= read -r vm_name; do # reads input line by line, storing each line in the vm_name variable
	vm_names+=("$vm_name")  # Add each name to the array
done <<< "$vm_extracted_names" # takes the output of vm_extracted_names(list of vm names)and feeds it line by line to the while loop

vm_state() {
	vm=$1
	
	vm_status=$(VBoxManage showvminfo "$vm" | grep "State:" | awk '{if ($3 == "off") print $2,$3; else print $2}')

	case "$vm_status" in
		"running")
			echo -e "State of VM: [$vm] - ${GREEN}${BOLD}Running ${NC}(${GREEN}ON${NC})${NORMAL}"
			;;
		"powered off")
			echo -e "State of VM: [$vm] - ${RED}${BOLD}Powered OFF${NORMAL}${NC}"
			;;
		"stopped")
			echo -e "State of VM: [$vm] - ${AMBER}${BOLD}Stopped${NORMAL}${NC}"
			;;
		"paused")
			echo -e "State of VM: [$vm] - ${GRAY}${BOLD}Paused${NORMAL}${NC}"
			;;
		"saved")
			echo -e "State of VM: [$vm] - ${BLUE}${BOLD}Saved${NORMAL}${NC}" 
			;;
	esac
	
}

vm_start() {

    stopped=true
            
    while $stopped; do
        echo -e "${BOLD}START${NORMAL} Virtual Machine [${YELLOW}${BOLD}$name${NORMAL}${NC}]?: ${BOLD}(yes/no)${NORMAL}"
        read start_vm
        if [ "$start_vm" == "yes" ]; then
            VBoxManage startvm "$name" --type headless >/dev/null 2>&1
            echo -e "[$name] - ${GREEN}${BOLD}Started..${NORMAL}${NC}"
            echo -e "[$name] - ${GREEN}${BOLD}Running ${NC}(${GREEN}ON${NC})${NORMAL}"
            stopped=false
            break
        elif [ "$start_vm" == "no" ]; then
            break
        else
            echo -e "invalid input! Please Enter '${BOLD}yes${NORMAL}' or '${BOLD}no${NORMAL}'"
            continue
        fi
    done

}

vm_stop() {
    
    running=true

    while $running; do
        echo -e "${BOLD}STOP${NORMAL} the Virtual Machine ${YELLOW}[$name]${NC}? (yes/no)"
        read stop_vm
        if [ "$stop_vm" == "yes" ]; then
            VBoxManage controlvm "$name" poweroff >/dev/null 2>&1
            echo -e "[$name] - ${RED}Shutting Down..${NC}"
            echo -e "[$name] - ${AMBER}Power Off${NC}"
            running=false
            break
        elif [ "$stop_vm" == "no" ]; then
            break
        else
            echo -e "invalid input! Please Enter '${BOLD}yes${NORMAL}' or '${BOLD}no${NORMAL}'" 
            continue
        fi
    done

}


start_or_stop_vm() {
    for name in "${vm_names[@]}"; do
        current_status=$(VBoxManage showvminfo "$name" | grep "State:" | awk '{if ($3 == "off") print $2,$3; else print $2}')
        if [ "$current_status" == "running" ]; then
            vm_stop
        elif [ ! "$current_status" == "running" ]; then
            vm_start
        fi
    done
}




check_ssh() { 

    # Convert process IDs to strings
    while IFS= read -r active_id; do
        active_node_ids+=("$active_id")
    done <<< "$active_ids"

    # Convert node names
    while IFS= read -r active_name; do
        active_node_names+=("$active_name")
    done <<< "$active_names"


    # Convert node ips
    while IFS= read -r active_ip; do
        active_node_ips+=("$active_ip")
    done <<< "$active_ips"


    # Create an Associative Array for ACTIVE ID & Name
    declare -A ssh_id_name

    # Store 'id' and 'node' into the Associative Array
    for ((i=0; i<num_active_nodes; i++)); do
        ssh_id_name["${active_node_ids[i]}"]="${active_node_names[i]}"
    done

    # Create an Associative Array for Name and IP
    declare -gA ssh_name_ip

    # Store 'name' and 'ip' in the Associative Array
    for ((i=0;i<num_active_nodes; i++)); do
        ssh_name_ip["${active_node_names[i]}"]="${active_node_ips[i]}"
    done

   
    # Create an Associative Array for Name -> ID
    declare -gA ssh_name_id

    for ((i=0;i<num_active_nodes; i++)); do
        ssh_name_id["${active_node_names[i]}"]="${active_node_ids[i]}"
    done



    for i in "${vm_names[@]}"; do
        match_found=false
        for active in "${active_node_names[@]}"; do
            if [[ "$i" == "$active" ]]; then
                match_found=true
                break
            fi
        done
        if $match_found; then
            echo -e "[$i]: ${GREEN}SSH Active${NC}"
        else
            echo -e "[$i]: ${RED}SSH Inactive${NC}"
        fi
    done

    start_or_stop_ssh

}

id_to_name() {
    local current_id="$1"

    for id in "${!ssh_id_name[@]}"; do
        if [ "$id" == "$current_id" ]; then
            echo "${ssh_id_name[$id]}"     # Return the matching name
            return
        fi
    done

    echo "[Name] Not found"   # If no match is found
}



 name_to_ip() {
    local current_id="$1"

    for id in "${!nodes_ips[@]}"; do
        if [ "$id" == "$current_id" ]; then
            echo "${nodes_ips[$id]}"     # Return the matching name
            return
        fi
    done

    echo "[Name] Not found"   # If no match is found

}


start_or_stop_ssh() {

    for i in "${vm_names[@]}"; do
        
        is_active=false
        
        current_status=$(VBoxManage showvminfo "$i" | grep "State:" | awk '{if ($3 == "off") print $2,$3; else print $2}')
        if [ "$current_status" == "running" ]; then
            
            for key in "${!nodes_ips[@]}"; do  # Loop through keys of associative array

                if [[ "$i" == "$key" ]]; then
                    if printf "%s\n" "${active_node_names[@]}" | grep -qx "$key"; then    # if i is in active_node_names  
                        stop_ssh "${ssh_name_id[$key]}"
                        break

                    else
                        start_ssh "$i" "${nodes_ips[$i]}"
                        break
                    fi        
                fi
            done

        elif [ ! "$current_status" == "running" ]; then
            echo -e "${BHI_YELLOW}Virtual Machine [${NC}$i${BHI_YELLOW}] is not running, cannot establish SSH connection!${NC}"
        fi
    done
}

start_ssh() {
    ssh_name=$1
    ssh_ip=$2
    local no_ssh=true


    while $no_ssh; do
        echo -e "do you want to open SSH session for [$ssh_name]? (yes/no)"
        read ssh_start
        if [ "$ssh_start" == "yes" ];then
            ssh "$ssh_name"@"$ssh_ip" -f -N
            no_ssh=false
        elif [ "$ssh_start" == "no" ]; then
            break
        else
            echo -e "invalid input! Please Enter '${BOLD}yes${NORMAL}' or '${BOLD}no${NORMAL}'" 
            continue
        fi
    done

}

stop_ssh() {
    ssh_id=$1
    local no_ssh=true
    idToName=$(id_to_name "$ssh_id")   


    while $no_ssh; do
        echo -e "do you want to STOP SSH session for [$idToName]? (yes/no)"
        read ssh_stop
        if [ "$ssh_stop" == "yes" ];then
            kill "$ssh_id"
            no_ssh=false
        elif [ "$ssh_stop" == "no" ]; then
            break
        else
            echo -e "invalid input! Please Enter '${BOLD}yes${NORMAL}' or '${BOLD}no${NORMAL}'" 
            continue
        fi
    done

}


get_ip_address() {

    # Extract Node Names with MAC Addresses
    local extracted_node_mac=$(VBoxManage list vms | awk -F '"' '{print $2}' | xargs -I {} sh -c 'echo "{} $(VBoxManage showvminfo "{}" | grep "MAC" | awk "{print \$4}" | tr -d ",")"')

    declare -A nodes_macs

    # Store VM Names and MACs in Associative Array
    while read -r node mac; do
        nodes_macs["$node"]="$mac"
    done <<< "$extracted_node_mac"


    # Extract MAC Addresses with Associated IP Addresses
    local extracted_mac_ip=$(arp -a | awk '{print $2,$4}' | tr -d '():')

    declare -A mac_ips

    # Store IPs and MACs in Associative Array
    while read -r ip mac; do
        mac_ips["$mac"]="$ip"  # Fix: Store MAC as key, IP as value
    done <<< "$extracted_mac_ip"


    # Associative array for Node Names with IP addresses
    declare -gA nodes_ips

    # Match Nodes (MAC) with IPs
    for node in "${!nodes_macs[@]}"; do
        node_mac=$(to_upper "${nodes_macs[$node]}")
        node_ip="${mac_ips[$node_mac]}"

        if [[ -n "$node_ip" ]]; then  # Only store if there's a match
            nodes_ips["$node"]="$node_ip"
        fi
    done


    for thing in "${!nodes_ips[@]}"; do
        echo "key: '$thing'  value: '${nodes_ips[$thing]}'"
    done
    
    for other in "${!ssh_id_name[@]}"; do
        echo "key: $other  value: ${ssh_id_name[$other]}"
    done
    
    # Store the IP addresses
    for node in "${vm_names[@]}"; do
        for key in "${!nodes_ips[@]}"; do
            if [ "$node" == "$key" ]; then
                vm_ips+=("${nodes_ips[$key]}")
            fi
        done
    done




}

wait_for_ips() {
    echo "IPs: ${AMBER}Loading...${NC}"
    local count_vms=${#vm_ips[@]}

    while [ "$count_vms" -lt "$num_of_vms" ]; do
        echo "IPs retried: $count_vms out of $num_of_vms"
        sleep 10   # wait for 1 second before checking again
    done

    echo "IPs: ${GREEN}Loaded!${NC}"
}

# function to convert MAC addresses to uppercase, for matching
to_upper() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}


# Start of Application -----------------------------------------------------------------------------------------------------------

echo -e "[=============== Virtual Machines ===============]\n"

for name in "${vm_names[@]}"; do
	vm_state "$name"
done

echo ""


echo -e "[======== Power ${GREEN}ON${NC}/${RED}OFF${NC} Virtual Machines? ========]\n"
start_or_stop_vm
get_ip_address
wait_for_ips
echo -e "[=============== Active SSH Connections ===============]\n"
check_ssh





