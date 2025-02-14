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
GRAY=$'\e[0;37m]'
AMBER=$'\e[0;33m]'
BLUE=$'\e[0;34m]'
YELLOW=$'\e[0;33m'

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

vm_start() {
    
    for name in "${vm_names[@]}"; do
        while [ ! "$vm_status" == "running" ]; do
            echo -e "Do you want to ${BOLD}START${NORMAL} the Virtual Machine ${YELLOW}[$name]${NC}? (yes/no)"
            read start_vm
            if [ "$start_vm" == "yes" ]; then
                VBoxManage startvm "$name" --type headless >/dev/null 2>&1
                echo -e "[$name] - ${GREEN}Started..${NC}"
                echo -e "[$name] - ${GREEN}Running${NC}"
                break
            elif [ "$start_vm" == "no" ]; then
                break
            else
                echo "invalid input. Please Enter 'yes' or 'no'" 
                continue
            fi
        done
    done

}

vm_stop() {
   

    for name in "${vm_names[@]}"; do
        while [ "$vm_status" == "running" ]; do
            echo -e "Do you want to ${BOLD}STOP${NORMAL} the Virtual Machine ${YELLOW}[$name]${NC}? (yes/no)"
            read stop_vm
            if [ "$stop_vm" == "yes" ]; then
                VBoxManage controlvm "$name" poweroff >/dev/null 2>&1
                echo -e "[$name] - ${AMBER}Shutting Down.. ${NC}"
                echo -e "[$name] - ${RED}Power Off${NC}"
                break
            elif [ "$stop_vm" == "no" ]; then
                break
            else
                echo "invalid input. Please Enter 'yes' or 'no'" 
                continue
            fi
        done
    done

}


echo "[=============== Virtual Machines ===============]"

for name in "${vm_names[@]}"; do
	vm_state "$name"
done



vm_start

echo "[===============================================]"
vm_stop 