#!/bin/bash

#  Get the list of VM names and store them in an array
vm_names=() # Initialize an empty array

vm_extracted_names=$(VBoxManage list vms | awk -F '"' '{print $2}')

# ANSI colour codes for terminal output
GREEN=$'\e[32m'  # 2 is the color code for green
NC=$'\e[0m'        # Reset color
RED=$'\e[31m'
GRAY=$'\e[0;37m]'
AMBER=$'\e[0;33m]'
BLUE=$'\e[0;34m]'

while IFS= read -r vm_name; do # reads input line by line, storing each line in the vm_name variable
	vm_names+=("$vm_name")  # Add each name to the array
done <<< "$vm_extracted_names" # takes the output of vm_extracted_names(list of vm names)and feeds it line by line to the while loop

vm_state() {
	vm=$1
	
	vm_status=$(VBoxManage showvminfo "$vm" | grep "State:" | awk '{if ($3 == "off") print $2,$3; else print $2}')

	case "$vm_status" in
		"running")
			echo -e "State of VM: [$vm] - ${GREEN}Running${NC}"
			;;
		"powered off")
			echo -e "State of VM: [$vm] - ${RED}Powered OFF${NC}"
			;;
		"stopped")
			echo -e "State of VM: [$vm] - ${AMBER}Stopped${NC}"
			;;
		"paused")
			echo -e "State of VM: [$vm] - ${GRAY}Paused${NC}"
			;;
		"saved")
			echo -e "State of VM: [$vm] - ${BLUE}Saved${NC}" 
			;;
	esac
	
}



echo "[=============== Virtual Machines ===============]"

for name in "${vm_names[@]}"; do
	vm_state "$name"
done
