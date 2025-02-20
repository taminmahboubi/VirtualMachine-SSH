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
BHI_YELLOW=$'\e[1;93m'  # Background High Intensity
BHI_RED=$'\e[41m'
BHI_GREEN=$'\e[42m'

while IFS= read -r vm_name; do # reads input line by line, storing each line in the vm_name variable
	vm_names+=("$vm_name")  # Add each name to the array
done <<< "$vm_extracted_names" # takes the output of vm_extracted_names(list of vm names)and feeds it line by line to the while loop

stop_update=false  # Global control variable

vm_state() {
    vm=$1

    vm_status=$(VBoxManage showvminfo "$vm" | grep "State:" | awk '{if ($3 == "off") print $2,$3; else print $2}')


    case "$vm_status" in
        "running")
            echo -e "[$vm] - ${BHI_GREEN}Running (ON)${NC}"
            ;;
        "powered off")
            echo -e "[$vm] - ${BHI_RED}Powered OFF ${NC}"
            ;;
        "stopped")
            echo -e "[$vm] - ${AMBER}${BOLD}Stopped${NORMAL}${NC}"
            ;;
        "paused")
            echo -e "[$vm] - ${GRAY}${BOLD}Paused${NORMAL}${NC}"
            ;;
        "saved")
            echo -e "[$vm] - ${BLUE}${BOLD}Saved${NORMAL}${NC}" 
            ;;
        "aborted")
            echo -e "[$vm] - ${BHI_RED}ABORTED${NC}" 
            ;;
    esac

}


state_transition() {
    local current_vm="$1"
    local current_state="$2"
    local middle_state="$3"
    local final_state="$4"

    local loading_frames=("." ".." "...")
    
    # Show current state for 1 second
    echo -ne "\r[$current_vm] - $current_state   "
    sleep 0.1
    
    # Animate middle state for 3 seconds
    for ((i=0; i<3; i++)); do
        for frame in "${loading_frames[@]}"; do
            echo -ne "\r[$current_vm] - $middle_state$frame   "
            sleep 0.1
        done
    done

    # Display final state
    echo -e "\r[$current_vm] - $final_state      "
}

list_vms() {
    for name in "${vm_names[@]}"; do
        
        vm_state "$name" 
        
    done
}


yes_no_menu() {
    local prompt="$1"
    local yes_cmd="$2"
    local no_cmd="$3"
    local options=("Yes" "No")
    local selected=0  # Start with "Yes" selected

    echo -e "\n$prompt"  # Print the question
    tput civis  # Hide cursor

    while true; do
        echo -ne "\r"  # Move to the start of the line
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -ne "\e[7m ${options[$i]} \e[0m "  # Full-line highlight
            else
                echo -ne " ${options[$i]}  "
            fi
        done

        read -rsn1 key  # Read single key input
        case "$key" in
            $'\x1b') read -rsn2 key
                [[ $key == "[A" || $key == "[D" ]] && selected=0  # Up/Left -> "Yes"
                [[ $key == "[B" || $key == "[C" ]] && selected=1  # Down/Right -> "No"
                ;;
            "")  # Enter key
                echo  # Move to a new line after selection
                [[ $selected -eq 0 ]] && eval "$yes_cmd" || eval "$no_cmd"
                return
                ;;
        esac
    done

    tput cnorm  # Show cursor again

}


vm_start() {
    prompt="${BOLD}START${NORMAL} Virtual Machine [${YELLOW}${BOLD}$name${NORMAL}${NC}]?"
    yes_no_menu "$prompt" \
    'VBoxManage startvm "$name" --type headless >/dev/null 2>&1 && stopped=false && break' \
    'break'


    #state_transition "$name" "${AMBER}Power Off${NC}" "${GREEN}${BOLD}Started${NORMAL}${NC}" "${GREEN}${BOLD}Running ${NC}(${GREEN}ON${NC})${NORMAL}"
}



vm_stop() {

    prompt="${BOLD}STOP${NORMAL} the Virtual Machine ${YELLOW}[$name]${NC}?"
    
    yes_no_menu "$prompt" \
    'VBoxManage controlvm "$name" poweroff >/dev/null 2>&1 && break' \
    'break'


    #state_transition "$name" "${GREEN}${BOLD}Running ${NC}${NORMAL}" "${RED}Shutting Down${NC}" "${AMBER}Power Off${NC}"

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

    prompt="do you want to open SSH session for [$ssh_name]?"

    yes_no_menu "$prompt" \
    'ssh "$ssh_name"@"$ssh_ip" -f -N && ssh=false && break' \
    'break'

}

stop_ssh() {
    ssh_id=$1
    local no_ssh=true
    idToName=$(id_to_name "$ssh_id")  

    prompt="do you want to STOP SSH session for [$idToName]?"

    yes_no_menu "$prompt" \
    'kill "$ssh_id" && no_ssh=false' \
    'break' 

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

    # Store the IP addresses
    for node in "${vm_names[@]}"; do
        for key in "${!nodes_ips[@]}"; do
            if [ "$node" == "$key" ]; then
                vm_ips+=("${nodes_ips[$key]}")
            fi
        done
    done

    # echo "mac addresses:"
    # for ip in ${!mac_ips[@]}; do
    #     echo "$ip -> ${mac_ips[$ip]}"
    # done

    # echo "Ip addresses:"
    # for ip in ${!nodes_ips[@]}; do
    #     echo "$ip -> ${nodes_ips[$ip]}"
    # done

}




wait_for_ips() {
        
    tput civis  # Hide cursor

    found=false  # Condition flag
    node_count=${#nodes_ips[@]} 
    progress_total=$num_of_vms    # Total steps (editable)
    ip_text="[IP Addresses]"  # Editable IP header text

    while true; do

        if [[ "$found" == "true" ]]; then
            echo -ne "\e[32m$ip_text${NC} - [${RED}$node_count${NC}/$progress_total]- ${GREEN}Found! ${NC}    \e[0m\n"  # Overwrite animation with "Found Done"
            tput cnorm  # Show cursor again
            break  # Stop the animation
        fi

        for dots in "." ".." "..." "    "; do
            echo -ne "\e[32m$ip_text${NC} - [${RED}$node_count${NC}/$progress_total] - ${RED}Finding$dots${NC} \e[0m\r"  # Keep animating
            sleep 0.3

            # Simulate progress updating 
            if [[ "$node_count" == "$progress_total" ]]; then
                found=true  # Set flag to stop animation
                break
            else
                for node in "${!nodes_ips[@]}"; do
                    echo -ne "                                                                          ${GRAY}| Trying to find [$node] |${NC}"
                done
            fi  
        done

    done

}

# function to convert MAC addresses to uppercase, for matching
to_upper() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}


# Start of Application -----------------------------------------------------------------------------------------------------------

echo -e "[=============== Virtual Machines ===============]\n"

list_vms


echo -e "[======== Power ${GREEN}ON${NC}/${RED}OFF${NC} Virtual Machines? ========]\n"

start_or_stop_vm
get_ip_address
wait_for_ips

echo -e "[=============== Active SSH Connections ===============]\n"
check_ssh





