#!/usr/bin/sh
#############################################################################################################
#																											#	
#	This script is designed to measure the following: CPU usage, Disk I/O usage, Network I/O, and Memory 	#
#	usage. Read the following discription before using the file.											#
#																											#
#	Copyright (C) 2014 Shilkumar Patel and Luihua Chen 														#
#																											#
#	This program is free software; you can redistribute it and/or modify it under the terms of the GNU 		#
#	General Public License as published by the Free Software Foundation; either version 3 of the License, 	#
#	or (at your option) any later version.																	#
#																											#
#	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even 	#
#	the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public	# 
#	License for more details. 																				#
#																											#
#	You should have received a copy of the GNU General Public License along with this program; if not,		# 
#	see <http://www.gnu.org/licenses>.																		#
#############################################################################################################
#	This script is designed to measure the following: CPU usage, Disk I/O usage, Network I/O, and Memory 	#
#	usage. Read the following discription before using the file.											#
#	Here is how it works:																					#
#		1) First it logs into all the VMs and PMs listed using SSH and create folders to save all the 		#
#			measured data and logs out of them. 															#
#		2) It then logs into all the VMs and PMs but this time all the VMs will run LOOKBUSY with the 		#
#			appropriate command, i.e. CPU-hungry loop. On the other hand, all the PMs runs few commands to 	#
#			gather valuable data, i.e one PM runs mpstat to gather the CPU usage of that PM. Other 			#
#			applications are listed here: top, vmstat, net.sh, and xenstat-1.pl. All of the measurements 	#
#			are running concurrently, which allows us to gather more accurate utilization information. 		#
#		3) While LOOKBUSY is running inside all the VMs, all the VMs are measuring memory usage using TOP 	#
#			and I/O usage using VMSTAT. All the measured information is saved into appropriate files and 	#
#			into the appropriate folders, which were created in the first step.								#
#		4) Since this script is designed to run the same tests multiple times, the user can define the 		#
#			total number of tests using the first command line arguement, i.e. bash parallel-1.0.sh 5 		#
#		5) After all the tests are completed, our refinement code, which is after the measurement code, 	#
#			will refine the collected information into one file per each VM or PM. 							#
#		6) Once this is done, we SSH into all the VMs and PMs to transfer those refined files onto the 		#
#			machine which is running is this parallel script. We later use another refinement script to 	#
#			collect all the data from all the PMs and the associated VMs with them into one file. 			#
#																											#
#	NOTE NOTE NOTE NOTE: If you change anything in this file, please make sure to make those changes in the #
#		refinedata1.0.sh file or your refinement file wont be correct at all.								#
#																											#	
#	How to run this file: bash <name of this file> <number of tests> 										#
#						i.e. bash paralleltest-1.0.sh 5 													#
#	Files associated with this script: 																		#
#			1) refinedata-1.0.sh (required if you wish to simplify your data and make it very easy to read) #
#			2) xenstat-1.pl (this file is modified from the original file we found online)			 		#
#			3) net.sh (this file is modified from the original file we found online)						#
#	NOTE: We recommend to use the files provided by us, which will take away all the stress on your part 	#
#			they are modified to fit out code. 																# 
#																											#
#	Bugs: 																									#
#		1) Since this files forks many parallel processes, sometimes some processes dont tend to complete. 	#
#			We have yet to find the reasons to why this is happening. 										#
#			In this situation, we have to kill the process using pkill or kill and by doing so we run that 	#
#			particular test again, whether it may be CPU usage test or memory usage test. 					#
#			Every time we have to kill a process the corresponding measurements are not completed in the 	#
#			VMs or PMs. Therefore it is essential that it runs the last experiment again. 					#
#		2) When VMs are listed the vm array using thier IP addresses, they should be listed in the order 	#
#			they appear in XENTOP ignoring Dom0. Only then we can assure that all the information in the 	#
#			final refined file is correctly placed.  														#
#		3) It is assumed that the first command line argument is a number and a number only. 				#
#		4) All the filenames listed should be updated if any filename is changed. 							#
#		5) The refinement code in this file assumes that the number of VMs in each PM are equal. Everytime 	#
#			number of VMs for each PM are not the same, we lost few lines of information from the output 	#
#			file of xenstat-1.pl. 																			#
#############################################################################################################

#!/usr/bin/sh

# checks if the user has provided number of tests, which is the first arguement
if [[ -z $1 ]]; then
	echo "n of tests unset"
	echo "i.e. bash $0 1"
	exit
fi

compilerForRefineData=bash # compiler for .sh files
refineDateFileName=refinedata-1.0.sh # name of the refinement script which is used at the end to put all the data together
outputFileName=refinedata.log # name of the outfile file name
perlFileName=xenstat-1.pl # name of the perl file, which measures all the information regarding the VMs and Dom0 for each PM
bashNetFileName=net.sh # name of the file, which measures the net RXbytes and TXbytes
nullOutputPath=/dev/null # this is used to redirect output, this will ignore all the output
username=root # you can change the username if its different
# NOTE: we had one password and one username for all the machinces therefore we only have one field to save the password and one field to save the username
# if you have different passwords for each machince then you should have different fields to save each passwords and each username
# and also modify the code
password="" # you can write your password between the quotations
TIME_TMP=`date +%y%m%d%k%M%S` 
TIME=${TIME_TMP// /0}
outputFolderName1=$TIME"testResults" # name of the output folder
outputRefineFileName=$TIME"computeData"
echo " "
echo "Folder prefix: $TIME"
echo " "

#NOTE: these are arrays so you can add as many VMs or PMs as you need
#   : Replace each IP address to IP addresses for your PMs and VMs
pm=( "XXX.XXX.XXX.119" ) # Physical machine's IP address, i.e pm=( "999.999.999.111" ).
pmname=( "119" ) # this are the number after the last period in IP address.
                 # NOTE: each number corresponds to an IP address above.
vm=( "XXX.XXX.XXX.175" "XXX.XXX.XXX.97" "XXX.XXX.XXX.23" ) # Virtual machine's IP address
vmname=( "175" "97" "23" )  # this is the name of the virtual machince that this script is running
                            # NOTE: these are the last few digits of your VMs' IP address
vmTotalNumber=3 # total number of VMs per PM
                # NOTE: here we assume that each PM has same number of VMs running
shkc=no # Strict Host Key Checking for SSHPASS

delay=1 # delay between each sample (in seconds)
duration=$((1*60)) # the length of time you want to measure the each experiment in seconds
iterations=$((duration/delay)) # number of iterations
child_status=0

initialWait=5s 
afterlookbusyWait=5s
afterlookbusyWaitMemory=1m
waitBeforeRefineData=10s
waitBeforeMoreTests=10s
# the following addtion is done assuming that both, initialWait and afterlookbusyWait, are in seconds. 
waitExtra=$((${initialWait%?}+${afterlookbusyWait%?}+10))

#${afterlookbusyWaitMemory%?} <-- this is used to remove the last character from a string 
# in our case we are taking out "s" or "m" or "h"
# the following few lines are calculating extra wait time (in seconds) when we run the memory experiment using LOOKBUSY
if [ "${afterlookbusyWaitMemory: -1}" == "m" ]
then
	waitExtraMem=$((${initialWait%?}+${afterlookbusyWaitMemory%?}*60+10))
elif [ "${afterlookbusyWaitMemory: -1}" == "h" ]
then
	waitExtraMem=$((${initialWait%?}+${afterlookbusyWaitMemory%?}*60*60+10))
else
	waitExtraMem=$((${initialWait%?}+${afterlookbusyWaitMemory%?}+10))
fi

lookbusyPathAll=("lookbusy-1.4/lookbusy" "ping XXX.XXX.XXX.XXX" ) # this array contains the path to LOOKBUSY and the PING command. NOTE: You need to replace the X's with the IP address you want to ping from
lookbusyFileName=lookbusy 
# the following are the parameters for each tests, which are required when using LOOKBUSY
# testtypeCpuandDisk, testtypeNet, and testtypeMem contains information regarding each test. These names are used when the outputs of these experiments are saved.
# i.e if we run lookbusy-1.4/lookbusy $lookbusyCommandCpuandDisk[3], which means are running 90% CPU (-c 90), 
# 		and the output of that experiment is save in the following file: 
#		xenstat$testtypeCpuandDisk[3]-$pmname[0].log, which is xenstatc90-119.log
# NOTE NOTE NOTE: as you may have noticed that each element in testtypeCpuandDisk and lookbusyCommandCpuandDisk 
#					corresponds to each other. Therefore, it is very important to make sure they you do not 
#					missmatch or miss any element when listing them. Same applied to the rest of the arrays.
testtypeCpuandDisk=( "c1" "c30" "c60" "c90" "c99" "d32KB" "d64KB" "d128KB" "d256KB" "d512KB" )
lookbusyCommandCpuandDisk=( "-c 1" "-c 30" "-c 60" "-c 90" "-c 99" "-c 0 -d 32KB" "-c 0 -d 64KB" "-c 0 -d 128KB" "-c 0 -d 256KB" "-c 0 -d 512KB" )
testtypeNet=( "bw200" "bw0.4" "bw0.2" "bw0.1" "bw0.05" )
lookbusyCommandNet=( "-i 200" "-s 65507 -i 0.4" "-s 65507 -i 0.2" "-s 65507 -i 0.1" "-s 65507 -i 0.05" )
testtypeMem=( "m32KB" "m5MB" "m10MB" "m20MB" "m50MB" )
lookbusyCommandMem=( "-c 0 -m 32KB" "-c 0 -m 5MB" "-c 0 -m 10MB" "-c 0 -m 20MB" "-c 0 -m 50MB"  )
# this arrary contains all the elements from the following arrays:testtypeCpuandDisk, testtypeNet, and testtypeMem
testtypeAll=( "c1" "c30" "c60" "c90" "c99" "d32KB" "d64KB" "d128KB" "d256KB" "d512KB" "bw200" "bw0.4" "bw0.2" "bw0.1" "bw0.05" "m32KB" "m5MB" "m10MB" "m20MB" "m50MB" )
declare -a child_idvm
declare -a child_idpm

# logging into each VM and each PM to create folders for the total number of tests, where each file with data will be stored
y=0
while [ $y -lt ${#vm[@]} ]
do
	echo "Creating directories in ${vm[$y]}: $(date)"
	(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${vm[$y]} /bin/bash <<-EOF
		x=0
		while [ \$x -lt $1 ]
		do
			mkdir ${outputFolderName1}\$x
			x=\$((x+1))
		done
		exit
	EOF
	#) > vmout-${vm[$y]}.log &
	) > $nullOutputPath &

	wait
	y=$((y+1))
done

y=0
while [ $y -lt ${#pm[@]} ]
do
	echo "Creating directories in ${pm[$y]}: $(date)"
	(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${pm[$y]} /bin/bash <<-EOF
		x=0
		while [ \$x -lt $1 ]
		do
			mkdir ${outputFolderName1}\$x
			x=\$((x+1))
		done
		exit
	EOF
	#) > pmout-${pm[$y]}.log &
	) > $nullOutputPath &
	wait
	y=$((y+1))
done
echo " "

i=0

while [ $i -lt $1 ]
do
	outputFolderName=${outputFolderName1}${i}/
	count=1
	# coping lookbusy path from the array lookbusyPathAll, which is lookbusy-1.4/lookbusy in our case
	lookbusyPath=("${lookbusyPathAll[@]:0:1}")
	testtype=("${testtypeCpuandDisk[@]}")
	lookbusyCommand=("${lookbusyCommandCpuandDisk[@])}")
	echo "+++++++++++Starting test $((i+1)) of $1: $(date)+++++++++++"
	echo " "
	echo "Starting the measurements for CPU and DISK I/O: $(date)"
	
	# The following code is desidned to SSH into all the VMs and PMs and run the appropriate application to measure the required data.
	# LOOKBUSY, TOP, and VMSTAT are the two application running inside each VM while xenstat-1.pl, MPSTAT, TOP, VMSTAT, and net.sh are running inside each PM
	# NOTE: After starting LOOKBUSY, we wait for few seconds (afterlookbusyWait) just so we know that LOOKBUSY is stablize. After the wait, we start all the measurements in parallel.
	# We use & to fork child processes, as we know they run in parallel
	# We use $! to get the pid of that particular child process
	x=0
	while [ $x -lt ${#lookbusyCommand[@]} ]
	do
		child_status=0
		y=0
		while [ $y -lt ${#vm[@]} ]
		do
			(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${vm[$y]} /bin/bash <<-EOF
				sleep $initialWait # wait time before starting lookbusy
				$lookbusyPath ${lookbusyCommand[$x]} > $nullOutputPath &
				lookbusy_id=\$!
				sleep $afterlookbusyWait # wait time while lookbusy stablize 
				top -b -d $delay -n $iterations | awk -F"\t" '/Mem/ {print}' > $outputFolderName${count}topMem${testtype[$x]}-${vmname[$y]}.log & top_id=\$!
				vmstat $delay $iterations > ${outputFolderName}${count}vmstat${testtype[$x]}-${vmname[$y]}.log & vmstat_id=\$!
				sleep $((${duration}+5))s
				pkill $lookbusyFileName
				kill \$top_id
				kill \$vmstat_id
				exit
			EOF
			#) >> vmout-${vm[$y]}.log & child_idvm[$y]=$!
			) > $nullOutputPath & child_idvm[$y]=$!
			echo "Running: ${testtype[$x]} on ${vm[$y]}: $(date)"
			y=$((y+1))
		done
		
		y=0
		while [ $y -lt ${#pm[@]} ]
		do
			(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${pm[$y]} /bin/bash <<-EOF
				sleep $initialWait # wait time before starting lookbusy in VMs
				sleep $afterlookbusyWait # wait time while lookbusy stablize  in VMs
				perl $perlFileName x $delay $iterations > ${outputFolderName}${count}xenstat${testtype[$x]}-${pmname[$y]}.log & xen_id=\$!
				mpstat $delay $iterations | awk 'NR <= 3 {next} NR > $iterations+3 {exit} {print (100.00 - \$11)}' > ${outputFolderName}${count}mpstat${testtype[$x]}-${pmname[$y]}.log & mpstat_id=\$!
				top -b -d $delay -n $iterations | awk -F"\t" '/Mem/ {print}' > ${outputFolderName}${count}topMem${testtype[$x]}-${pmname[$y]}.log & top_id=\$!
				vmstat $delay $iterations > ${outputFolderName}${count}vmstat${testtype[$x]}-${pmname[$y]}.log & vmstat_id=\$!
				sh $bashNetFileName -s $delay -c $iterations > ${outputFolderName}${count}netstat${testtype[$x]}-${pmname[$y]}.log & net_id=\$!

				sleep $((${duration}+5))s
				kill \$xen_id
				kill \$mpstat_id
				kill \$top_id
				kill \$vmstat_id
				kill \$net_id
				exit
			EOF
			#) >> pmout-${pm[$y]}.log & child_idpm[$y]=$!
			) > $nullOutputPath & child_idpm[$y]=$!
			echo "Running: ${testtype[$x]} on ${pm[$y]}: $(date)"
			y=$((y+1))
		done
		# sleep until the measuring time is complete
		sleep $((${duration}+${waitExtra}))s
		
		# here we check to see if all the child processes have completed or not; 
		# if they are not, then we kill the process, which means we run the same experiment again to get data. 
		# We used $? to get the return status of kill, which mean its 0 if the kill successed else something else if it failed
		y=0
		while [ $y -lt ${#vm[@]} ]
		do
			kill ${child_idvm[$y]}; if [ $? -eq 0 ]; then child_status=1; fi #i have used $? to check the exit code for kill function. 0 means kill is sucessfull
			y=$((y+1))
		done
		y=0
		while [ $y -lt ${#pm[@]} ]
		do
			kill ${child_idpm[$y]}; if [ $? -eq 0 ]; then child_status=1; fi
			y=$((y+1))
		done
		
		echo " "
		# only run the next experiment if no child process(es) is/were forced to kill else run the same the experiment
		if [ ${child_status} -eq 0 ]; then count=$((count+1));x=$((x+1)); fi
		sleep $initialWait
		
	done

	echo "Ending the measurements for CPU and DISK I/O: $(date)"
	echo " "
	sleep $initialWait
	echo "Starting the measurements for NETWORK I/O: $(date)"
	echo " "

	# coping lookbusy path from the array lookbusyPathAll, which is ping XXX.XXX.XXX.XXX in our case
	# NOTE: Since these are network I/O experiments, its not using LOOKBUSY at all but its using PING.
	lookbusyPath=("${lookbusyPathAll[@]:1:1}")
	testtype=("${testtypeNet[@]}")
	lookbusyCommand=("${lookbusyCommandNet[@]}")
	child_status=0
	x=0
	while [ $x -lt ${#lookbusyCommand[@]} ]
	do
		child_status=0
		y=0
		while [ $y -lt ${#vm[@]} ]
		do
			(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${vm[$y]} /bin/bash <<-EOF
				sleep $initialWait
				$lookbusyPath ${lookbusyCommand[$x]} > $nullOutputPath &
				lookbusy_id=\$!
				sleep $afterlookbusyWait
				top -b -d $delay -n $iterations | awk -F"\t" '/Mem/ {print}' > $outputFolderName${count}topMem${testtype[$x]}-${vmname[$y]}.log & top_id=\$!
				vmstat $delay $iterations > ${outputFolderName}${count}vmstat${testtype[$x]}-${vmname[$y]}.log & vmstat_id=\$!
				sleep $((${duration}+5))s
				pkill ping #error fixed
				kill \$top_id
				kill \$vmstat_id
				exit
			EOF
			#) >> vmout-${vm[$y]}.log & child_idvm[$y]=$!
			) > $nullOutputPath & child_idvm[$y]=$!
			echo "Running: ${testtype[$x]} on ${vm[$y]}: $(date)"
			y=$((y+1))
		done

		y=0
		while [ $y -lt ${#pm[@]} ]
		do
			(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${pm[$y]} /bin/bash <<-EOF
				sleep $initialWait
				sleep $afterlookbusyWait
				perl $perlFileName x $delay $iterations > ${outputFolderName}${count}xenstat${testtype[$x]}-${pmname[$y]}.log & xen_id=\$!
				mpstat $delay $iterations | awk 'NR <= 3 {next} NR > $iterations+3 {exit} {print (100.00 - \$11)}' > ${outputFolderName}${count}mpstat${testtype[$x]}-${pmname[$y]}.log & mpstat_id=\$!
				top -b -d $delay -n $iterations | awk -F"\t" '/Mem/ {print}' > ${outputFolderName}${count}topMem${testtype[$x]}-${pmname[$y]}.log & top_id=\$!
				vmstat $delay $iterations > ${outputFolderName}${count}vmstat${testtype[$x]}-${pmname[$y]}.log & vmstat_id=\$!
				sh $bashNetFileName -s $delay -c $iterations > ${outputFolderName}${count}netstat${testtype[$x]}-${pmname[$y]}.log & net_id=\$!

				sleep $((${duration}+5))s
				kill \$xen_id
				kill \$mpstat_id
				kill \$top_id
				kill \$vmstat_id
				kill \$net_id
				exit
			EOF
			#) >> pmout-${pm[$y]}.log & child_idpm[$y]=$!
			) > $nullOutputPath & child_idpm[$y]=$!
			echo "Running: ${testtype[$x]} on ${pm[$y]}: $(date)"
			y=$((y+1))
		done
		sleep $((${duration}+${waitExtra}))s
		y=0
		while [ $y -lt ${#vm[@]} ]
		do
			kill ${child_idvm[$y]}; if [ $? -eq 0 ]; then child_status=1; fi #i have used $? to check the exit code for kill function. 0 means kill is sucessfull
			y=$((y+1))
		done
		y=0
		while [ $y -lt ${#pm[@]} ]
		do
			kill ${child_idpm[$y]}; if [ $? -eq 0 ]; then child_status=1; fi
			y=$((y+1))
		done
		echo " "
		if [ ${child_status} -eq 0 ]; then count=$((count+1));x=$((x+1)); fi
		sleep $initialWait
	done

	echo "Ending the measurements for NETWORK I/O: $(date)"
	echo " "
	sleep $initialWait
	echo "Starting the measurements for MEMORY: $(date)"
	echo " "
	lookbusyPath=( "${lookbusyPathAll[@]:0:1}" )
	testtype=("${testtypeMem[@]}")
	lookbusyCommand=("${lookbusyCommandMem[@]}")
	child_status=0
	x=0
	while [ $x -lt ${#lookbusyCommand[@]} ]
	do
		child_status=0
		y=0
		while [ $y -lt ${#vm[@]} ]
		do
			(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${vm[$y]} /bin/bash <<-EOF
				sleep $initialWait
				$lookbusyPath ${lookbusyCommand[$x]} > $nullOutputPath &
				lookbusy_id=\$!
				sleep $afterlookbusyWaitMemory
				top -b -d $delay -n $iterations | awk -F"\t" '/Mem/ {print}' > $outputFolderName${count}topMem${testtype[$x]}-${vmname[$y]}.log & top_id=\$!
				vmstat $delay $iterations > ${outputFolderName}${count}vmstat${testtype[$x]}-${vmname[$y]}.log & vmstat_id=\$!
				sleep $((${duration}+5))s
				pkill $lookbusyFileName
				kill \$top_id
				exit
			EOF
			#) >> vmout-${vm[$y]}.log & child_idvm[$y]=$!
			) > $nullOutputPath & child_idvm[$y]=$!
			echo "Running: ${testtype[$x]} on ${vm[$y]}: $(date)"
			y=$((y+1))
		done

		y=0
		while [ $y -lt ${#pm[@]} ]
		do
			(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${pm[$y]} /bin/bash <<-EOF
				sleep $initialWait
				sleep $afterlookbusyWaitMemory
				perl $perlFileName x $delay $iterations > ${outputFolderName}${count}xenstat${testtype[$x]}-${pmname[$y]}.log & xen_id=\$!
				mpstat $delay $iterations | awk 'NR <= 3 {next} NR > $iterations+3 {exit} {print (100.00 - \$11)}' > ${outputFolderName}${count}mpstat${testtype[$x]}-${pmname[$y]}.log & mpstat_id=\$!
				top -b -d $delay -n $iterations | awk -F"\t" '/Mem/ {print}' > ${outputFolderName}${count}topMem${testtype[$x]}-${pmname[$y]}.log & top_id=\$!
				vmstat $delay $iterations > ${outputFolderName}${count}vmstat${testtype[$x]}-${pmname[$y]}.log & vmstat_id=\$!
				sh $bashNetFileName -s $delay -c $iterations > ${outputFolderName}${count}netstat${testtype[$x]}-${pmname[$y]}.log & net_id=\$!

				sleep $((${duration}+5))s
				kill \$xen_id
				kill \$mpstat_id
				kill \$top_id
				kill \$vmstat_id
				kill \$net_id
				exit
			EOF
			#) >> pmout-${pm[$y]}.log & child_idpm[$y]=$!
			) > $nullOutputPath & child_idpm[$y]=$!
			echo "Running: ${testtype[$x]} on ${pm[$y]}: $(date)"
			y=$((y+1))
		done
		sleep $((${duration}+${waitExtraMem}))s
		y=0
		while [ $y -lt ${#vm[@]} ]
		do
			kill ${child_idvm[$y]}; if [ $? -eq 0 ]; then child_status=1; fi
			y=$((y+1))
		done
		y=0
		while [ $y -lt ${#pm[@]} ]
		do
			kill ${child_idpm[$y]}; if [ $? -eq 0 ]; then child_status=1; fi
			y=$((y+1))
		done

		echo " "
		if [ ${child_status} -eq 0 ]; then count=$((count+1));x=$((x+1)); fi
		sleep $waitBeforeMoreTests
	done
	echo "Ending the measurements for MEMORY: $(date)"
	echo " "
	echo "+++++++++++Ending test $((i+1)) of $1: $(date)+++++++++++"
	echo " "
	i=$((i+1))
done
sleep $waitBeforeRefineData

# This is where the refinement section of this script begins
# Again, it SSHs into all the VMs and PMs to rather all the information from different files into one file per VM and one file per PM.
# NOTE: that the following code is designed assuming the following things: each PM has exactly same number of VMs in it and the maximum number of VMs can be no more than 4.
# some minor modifications are needed to fix the issue
i=0
while [ $i -lt $1 ]
do
	outputFolderName=${outputFolderName1}${i}/
	y=0
	while [ $y -lt ${#pm[@]} ]
	do	
		(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${pm[$y]} /bin/bash <<-EOF
			testtype1=(${testtypeAll[@]})
			count=1;x=0;
			echo "Test analysis begins on $(date)" > ${outputRefineFileName}${i}-${pmname[$y]}.log
			while [ \$x -lt \${#testtype1[@]} ]
			do
				echo "------------------------------------------------------------------------------" >> ${outputRefineFileName}${i}-${pmname[$y]}.log
				echo "\${count}\${testtype1[\$x]}":"" >> ${outputRefineFileName}${i}-${pmname[$y]}.log
				echo "------------------------------------------------------------------------------" >> ${outputRefineFileName}${i}-${pmname[$y]}.log
				vmCPUHeader=\$(awk 'FNR==4+${#vm[@]}-1 {print}' ${outputFolderName}\${count}xenstat\${testtype1[\$x]}-${pmname[$y]}.log)
				vmCPU=\$(awk 'NR <= 4+${vmTotalNumber}-1 {next} {total1 += \$3;total2 += \$4;total3 += \$5;total4 += \$6;total5 += \$7;total6 += \$8;total7 = 0;total8 += \$10;total9 += \$11;total10 += \$12;total11 += \$13;total12 += \$14;total13 += \$15;total14 = 0;total15 += \$17;total16 += \$18;total17 += \$19;total18 += \$20;total19 += \$21;total20 += \$22;total21 = 0;total22 += \$24;total23 += \$25;total24 += \$26;total25 += \$27;total26 += \$28;total27 += \$29;total28 = 0;total29 += \$31;total30 += \$32;total31 += \$33;total32 += \$34;total33 += \$35;total34 += \$36;count++} END {printf "   %8.1f%12.1f%12.1f%12.1f%12.1f%12.1f        |%8.1f%12.1f%12.1f%12.1f%12.1f%12.1f        |%8.1f%12.1f%12.1f%12.1f%12.1f%12.1f        |%8.1f%12.1f%12.1f%12.1f%12.1f%12.1f        |%8.1f%12.1f%12.1f%12.1f%12.1f%12.1f        \n",total1/count,total2/count,total3/count,total4/count,total5/count,total6/count,total8/count,total9/count,total10/count,total11/count,total12/count,total13/count,total15/count,total16/count,total17/count,total18/count,total19/count,total20/count,total22/count,total23/count,total24/count,total25/count,total26/count,total27/count,total29/count,total30/count,total31/count,total32/count,total33/count,total34/count}' ${outputFolderName}\${count}xenstat\${testtype1[\$x]}-${pmname[$y]}.log)
				echo \$vmCPUHeader >> ${outputRefineFileName}${i}-${pmname[$y]}.log
				echo "VmXenStat: \$vmCPU" >> ${outputRefineFileName}${i}-${pmname[$y]}.log

				pmMpStat=\$(awk '{total1 += \$1;count++} END {printf "PmMpStat: %0.2f %%", total1/count}' ${outputFolderName}\${count}mpstat\${testtype1[\$x]}-${pmname[$y]}.log)
				echo \$pmMpStat >> ${outputRefineFileName}${i}-${pmname[$y]}.log

				pmtopMemUsed=\$(awk '{total1 += substr(\$4,1,length(\$4)-1);count++} END {printf "PmTopUsedMem: %0.2f", total1/count}' ${outputFolderName}\${count}topMem\${testtype1[\$x]}-${pmname[$y]}.log)
				echo \${pmtopMemUsed} >> ${outputRefineFileName}${i}-${pmname[$y]}.log

				pmVmStat=\$(awk '{if(substr(\$1,1,5) != "procs" && substr(\$1,1,1) != "r") {total1 += \$9;total2 += \$10;count++}} END {printf "PmVmStat(IO): bi: %0.2f bo: %0.2f\n", total1/count, total2/count}' ${outputFolderName}\${count}vmstat\${testtype1[\$x]}-${pmname[$y]}.log)
				echo \$pmVmStat >> ${outputRefineFileName}${i}-${pmname[$y]}.log

				pmNet=\$(awk 'NR <= 1 {next} {total1 += \$3; total2 += \$6;count++} END {printf "PmNet: RXbytes: %0.2f\tTXbytes: %0.2f\n", total1/count,total2/count}' ${outputFolderName}\${count}netstat\${testtype1[\$x]}-${pmname[$y]}.log)
				echo \$pmNet >> ${outputRefineFileName}${i}-${pmname[$y]}.log

				count=\$((count+1))
				x=\$((x+1))
			done
			echo " "
			echo "------------------------------------------------------------------------------" >> ${outputRefineFileName}${i}-${pmname[$y]}.log
			echo "Test analysis ended on $(date)" >> ${outputRefineFileName}${i}-${pmname[$y]}.log
			exit
		EOF
		) > $nullOutputPath
		echo "Running: analysis on ${pm[$y]}: $(date)"
		y=$((y+1))
	done
	y=0
	while [ $y -lt ${#vm[@]} ]
	do
		(sshpass -p $password ssh -t -t -o StrictHostKeyChecking=$shkc ${username}@${vm[$y]} /bin/bash <<-EOF
			testtype1=(${testtypeAll[@]})
			count=1;x=0;
			echo "Test analysis begins on $(date)" > ${outputRefineFileName}${i}-${vmname[$y]}.log
			while [ \$x -lt \${#testtype1[@]} ]
			do
				echo "------------------------------------------------------------------------------" >> ${outputRefineFileName}${i}-${vmname[$y]}.log
				pmtopMemUsed=\$(awk '{total1 += substr(\$4,1,length(\$4)-1);count++} END {printf "PmTopUsedMem: %0.2f", total1/count}' ${outputFolderName}\${count}topMem\${testtype1[\$x]}-${vmname[$y]}.log)
				echo \${count}\${testtype1[\$x]}":"\$pmtopMemUsed >> ${outputRefineFileName}${i}-${vmname[$y]}.log
				
				pmVmStat=\$(awk '{if(substr(\$1,1,5) != "procs" && substr(\$1,1,1) != "r") {total1 += \$9;total2 += \$10;count++}} END {printf "vmVmStat(IO): bi: %0.2f bo: %0.2f\n", total1/count, total2/count}' ${outputFolderName}\${count}vmstat\${testtype1[\$x]}-${vmname[$y]}.log)
				echo \$pmVmStat >> ${outputRefineFileName}${i}-${vmname[$y]}-io.log
count=\$((count+1))
				x=\$((x+1))
			done
			echo " "
			echo "------------------------------------------------------------------------------" >> ${outputRefineFileName}${i}-${vmname[$y]}.log
			echo "Test analysis ended on $(date)" >> ${outputRefineFileName}${i}-${vmname[$y]}.log
			exit
		EOF
		) > $nullOutputPath
		echo "Running: analysis on ${vm[$y]}: $(date)"
		y=$((y+1))
	done

	echo " "
	i=$((i+1))
done

sleep 5s
y=0
while [ $y -lt ${#vm[@]} ]
do
	(sshpass -p $password sftp -o StrictHostKeyChecking=$shkc ${username}@${vm[$y]} /bin/bash <<-EOF
		mget ${outputRefineFileName}*.log
		exit
	EOF
	) > $nullOutputPath
	echo "Retreiving computed data files from ${vm[$i]}: $(date)"
	y=$((y+1))
done

y=0
while [ $y -lt ${#pm[@]} ]
do
	(sshpass -p $password sftp -o StrictHostKeyChecking=$shkc ${username}@${pm[$y]} /bin/bash <<-EOF
		mget ${outputRefineFileName}*.log
		exit
	EOF
	) > $nullOutputPath
	echo "Retreiving computed data files from ${pm[$y]}: $(date)"
	y=$((y+1))
done
echo "ALL Measurements completed: $(date)"
sleep 5s
echo "Starting the refine data process: $(date)"
$compilerForRefineData $refineDateFileName $1 $TIME
echo "Ending the refine data process: $(date)"
