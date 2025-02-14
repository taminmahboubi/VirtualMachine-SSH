#!/bin/bash

#  Get the list of VM names and store them in an array
vm_names=() # Initialize an empty array

vm_extracted_names=$(VBoxManage list vms | awk -F '"' '{print $2}')

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

# vm_start() {

#     stopped=true
            
#     while $stopped; do
#         echo -e "${BOLD}START${NORMAL} Virtual Machine [${YELLOW}${BOLD}$name${NORMAL}${NC}]?: ${BOLD}(yes/no)${NORMAL}"
#         read start_vm
#         if [ "$start_vm" == "yes" ]; then
#             VBoxManage startvm "$name" --type headless >/dev/null 2>&1
#             echo -e "[$name] - ${GREEN}${BOLD}Started..${NORMAL}${NC}"
#             echo -e "[$name] - ${GREEN}${BOLD}Running ${NC}(${GREEN}ON${NC})${NORMAL}"
#             stopped=false
#             break
#         elif [ "$start_vm" == "no" ]; then
#             break
#         else
#             echo -e "invalid input! Please Enter '${BOLD}yes${NORMAL}' or '${BOLD}no${NORMAL}'"
#             continue
#         fi
#     done

# }

# vm_stop() {
    
#     running=true

#     while $running; do
#         echo -e "${BOLD}STOP${NORMAL} Vactive_node_ids=$(pgrep -a ssh | awk '$2 == "ssh" {print $1}')OLD}Power Off${NORMAL}${NC}"
#             running=false
#             break
#         elif [ "$stop_vm" == "no" ]; then
#             break
#         else
#             echo -e "invalid input! Please Enter '${BOLD}yes${NORMAL}' or '${BOLD}no${NORMAL}'" 
#             continue
#         fi
#     done

# }


# start_or_stop() {
#     for name in "${vm_names[@]}"; do
#         current_status=$(VBoxManage showvminfo "$name" | grep "State:" | awk '{if ($3 == "off") print $2,$3; else print $2}')
#         if [ "$current_status" == "running" ]; then
#             vm_stop
#         elif [ ! "$current_status" == "running" ]; then
#             vm_start
#         fi
#     done
# }



check_ssh() { 
    # Initialize arrays
    active_node_ids=()
    active_node_names=()

    # Get active SSH process IDs and names
    active_ids=$(pgrep -a ssh | awk '$2 == "ssh" {print $1}')
    active_names=$(pgrep -a ssh | awk '$2 == "ssh" {split($3, parts, "@"); print parts[1]}')
    num_active_nodes=$(pgrep -a ssh | awk '$2 == "ssh" {print $1, $3}' | wc -l)

    # Convert process IDs to strings
    while read -r active_id; do
        active_node_ids+=("$active_id")
    done <<< "$active_ids"

    # Convert node names
    while read -r active_name; do
        active_node_names+=("$active_name")
    done <<< "$active_names"

    # Create an Associative Array
    declare -A ssh_id_name

    # Store 'id' and 'node' into the Associative Array
    for ((i=0; i<num_active_nodes; i++)); do
        ssh_id_name["${active_node_ids[i]}"]="${active_node_names[i]}"
    done

    # Print the Associative Array
    for id in "${!ssh_id_name[@]}"; do
        echo "$id -> ${ssh_id_name[$id]}"
    done

}

echo -e "[=============== Virtual Machines ===============]\n"

for name in "${vm_names[@]}"; do
	vm_state "$name"
done




check_ssh



# echo ""
# echo -e "[======== Power ${GREEN}ON${NC}/${RED}OFF${NC} Virtual Machines? ========]\n"
# start_or_stop
# echo 



