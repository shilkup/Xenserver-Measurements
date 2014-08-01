#!/usr/bin/sh
#############################################################################################################
#                                                                                                           #   
#   This script is designed to refine the following: CPU usage, Disk I/O usage, Network I/O, and Memory     #
#   usage. Read the following discription before using the file.                                            #
#                                                                                                           #
#   Copyright (C) 2014 Shilkumar Patel and Luihua Chen                                                      #
#                                                                                                           #
#   This program is free software; you can redistribute it and/or modify it under the terms of the GNU      #
#   General Public License as published by the Free Software Foundation; either version 3 of the License,   #
#   or (at your option) any later version.                                                                  #
#                                                                                                           #
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even  #
#   the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public # 
#   License for more details.                                                                               #
#                                                                                                           #
#   You should have received a copy of the GNU General Public License along with this program; if not,      # 
#   see <http://www.gnu.org/licenses>.                                                                      #
#############################################################################################################
#   Here is how it works:                                                                                    #
#       1) This file assumes that all the required log files are on in the same folder as this script.      #
#           You will see errors if any particular file does exist.                                          #
#       2) This file also assumes that if you changed anything in the parallel-1.0.sh then you have also    #
#           made changes in this file. Changes suchs as adding IP addresses or adding all commands for      #
#           lookbusy.                                                                                       #
#       3) This refinement script is very simple. It simply reads in the computed files, which were         #
#           recreated by parallel-1.0.sh script after running all the test, and puts the data in a very     #
#           originized manner.                                                                              #
#       Here is a sample of the output:                                                                     #
#           
#            Test1:  0++++++++++++++++++++++++++++++++++VM  1++++++++++++++++++++++++++++++++++   |   ++++++++++++++++++++++++++++++++++Dom0+++++++++++++++++++++++++++++++++++   |   ++++++++++++++++++++++++++++++++++PM+++++++++++++++++++++++++++++++++++++   |   
#                    :  CPU(%)     MEM(K)          IObi        IObo        BWTX(B)     BWRX(B)    |     CPU(%)     MEM(K)          IObi        IObo        BWTX(B)     BWRX(B)    |     CPU(%)     MEM(K)          IObi        IObo        BWTX(B)     BWRX(B)    |   
#                 c1:     1.90    105867.53         0.02         4.25         0.00         0.70   |       9.00    650027.33         0.00         0.00         0.00         0.00   |       3.02         0.00         0.12        40.17         0.00      1028.45   |   
#                c30:    29.70    106119.87         0.02         5.12         0.00         0.50   |       9.40    650134.67         0.00         0.00         0.00         0.00   |       8.43         0.00         0.08        40.83         0.00       809.63   |   
#                c60:    55.90    106541.67         0.02         7.52         0.00         0.50   |      12.40    650354.80         0.00         0.00         0.00         0.00   |      14.28         0.00         0.08        46.63         0.00       872.63   |   
#                c90:    62.30    106272.40         0.02         4.32         0.00         0.60   |      12.20    650085.47         0.00         0.00         0.00         0.00   |      11.63         0.00         0.08        36.57         0.00       885.00   |   
#                c99:    62.20    106338.40         0.02         4.12         0.00         0.50   |      13.20    650242.00         0.00         0.00         0.00         0.00   |      12.86         0.00         0.10        40.10         0.00       849.70   |   
#              d32KB:     1.50    106807.40         0.02        18.52         0.00         0.60   |       8.30    650499.20         0.00         0.00         0.00         0.00   |       2.89         0.00         0.08       114.70         0.00       916.63   |   
#              d64KB:     0.70    106758.80         0.02        22.98         0.00         0.60   |       9.00    650430.00         0.00         0.00         0.00         0.00   |       2.99         0.00         0.08       157.08         0.00      1019.10   |   
#              . . . . .
#              . . . . .
#                                                                                                           #
#   How to run: bash <name of this file> <number of tests> <suffix of the folder you want to run the test>  #
#                       i.e. bash refinedata-1.0.sh 5 14010101                                              #
#   Files associated with this script: None                                                                 # 
#                                                                                                           #
#   Bugs:                                                                                                   #
#       1) When VMs are listed the vm array using thier IP addresses, they should be listed in the order    #
#           they appear in XENTOP ignoring Dom0. Only then we can assure that all the information in the    #
#           final refined file is correctly placed.                                                         #
#       3) It is assumed that the first and second command line arguments are a number and a number only.   #
#       4) All the filenames listed should be updated if any filename is changed.                           #
#       5) The refinement code in this file assumes that the number of VMs in each PM are equal. Everytime  #
#           number of VMs for each PM are not the same, we lost few lines of information from the output    #
#           file of xenstat-1.pl.                                                                           #
#############################################################################################################

#NOTE: these are arrays so you can add as many VMs or PMs as you need
#   : Replace each IP address to IP addresses for your PMs and VMs
pm=( "XXX.XXX.XXX.YYY" ) # Physical machine's IP address, i.e pm=( "999.999.999.111" ).
pmname=( "YYY" ) # this are the number after the last period in IP address.
                 # NOTE: each number corresponds to an IP address above.
                    # NOTE: these are the last few digits of your PMs' IP address
vmALL=( "XXX.XXX.XXX.AAA" "XXX.XXX.XXX.97" "XXX.XXX.XXX.23" ) # Virtual machine's IP address
vmnameALL=( "AAA" "97" "23" )  # this is the name of the virtual machince that this script is running
                               # NOTE: these are the last few digits of your VMs' IP address
numVMsPerPm=3 # total number of VMs per PM
              # NOTE: here we assume that each PM has same number of VMs running
# NOTE NOTE NOTE: as you may have noticed that each element in testtypeCpuandDisk and lookbusyCommandCpuandDisk
#                   corresponds to each other. Therefore, it is very important to make sure they you do not 
#                   missmatch or miss any element when listing them. Same applied to the rest of the arrays.
testtypeCpuandDisk=( "c1" "c30" "c60" "c90" "c99" "d32KB" "d64KB" "d128KB" "d256KB" "d512KB" )
testtypeNet=( "bw200" "bw0.4" "bw0.2" "bw0.1" "bw0.05" )
testtypeMem=( "m32KB" "m5MB" "m10MB" "m20MB" "m50MB" )
testtypeAll=( "c1" "c30" "c60" "c90" "c99" "d32KB" "d64KB" "d128KB" "d256KB" "d512KB" "bw200" "bw0.4" "bw0.2" "bw0.1" "bw0.05" "m32KB" "m5MB" "m10MB" "m20MB" "m50MB" )

# checks if the user has provided number of tests, which is the first arguement, and suffix of the folder name, which is the second argument
if [[ -z $1 ]]; then
	echo "n of tests unset"
    echo "i.e. bash $0 1 14010101"
	exit
fi
if [[ -z $2 ]]; then
	echo "suffix of folder name unset"
    echo "i.e. bash $0 1 14010101"
	exit
fi

outputFolderName1=$2testResults # name of the output folder
outputRefineFileName=$2computeData
outRefine=$2refinedata

printHead="  CPU(%%)     MEM(K)          IObi        IObo        BWTX(B)     BWRX(B) "
printHeader1="++++++++++++++++++++++++++++++++++VM%3d++++++++++++++++++++++++++++++++++"
printHeader2="++++++++++++++++++++++++++++++++++Dom0+++++++++++++++++++++++++++++++++++"
printHeader3="++++++++++++++++++++++++++++++++++PM+++++++++++++++++++++++++++++++++++++"
i=0

# just removing any files with the same name
rm $outRefine.log;

while [ $i -lt $1 ]
do
    y=0
    while [ $y -lt ${#pm[@]} ];
    do
        echo " "
        # coping VM names corresponding to appropriate PM from vmnameALL
        # NOTE: Here we see why we use exactly same number of VMs per PM. If you have different number of 
        # VMs per different PMs then you need to modify few lines.
        vmname=( "${vmnameALL[@]:$((y * $numVMsPerPm)):$numVMsPerPm}" )
        vm=( "${vmALL[@]:$((y * $numVMsPerPm)):$numVMsPerPm}" )

        echo "Test $i of $1: Refining PM (${pm[$y]}), and VMs (${vm[@]}): $(date)"
    
        {
        printf "\n\n%17s:%3d" "Test"$((i+1));
        f=0
        # printing headers
        while [ $f -lt ${#vm[@]} ];
        do
            printf "$printHeader1" $((f+1));
            printf "   |   ";
            f=$((f+1))
        done
        # printing headers
        printf "$printHeader2";
        printf "   |   ";
        printf "$printHeader3";
        printf "   |   ";

        printf "\n%21s" ":";
        f=0
        # printing headers
        while [ $f -lt ${#vm[@]} ];
        do
            printf "$printHead"; 
            printf "   |   ";
            f=$((f+1))
        done
        # printing headers
        printf "$printHead";
        printf "   |   ";
        printf "$printHead";
        printf "   |   ";
        f=0;a=0;
        while [ $a -lt ${#testtypeAll[@]} ];
        do
            # printing which test it is running, i.e c1, c90, d32KB, etc
            printf "\n%19s: " ${testtypeAll[$a]};
            b=0;g=0;vmMemTotal=0;q=0;
            while [ $b -le ${#vm[@]} ];
            do
                # here we are looking for Dom0
                # If Dom0 is found then save the appropriate information else its a VM and save it as VM info
                # the calculations we used here (e=$((3 * 13 * h))) are due to different field on the file.
                # you will see that the computed data file has a long horizontal list for all the VMs and Dom0. 
                # In order to get the appropriate field, we have to move to the left as we gather information about differnt VMs and Dom0
                dom0Location=$(awk -v d=$((5)) -v e=$((3 + 13 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)             
                if [[ $g == 0 && "$dom0Location" == "Dom-0" ]]; then
                    dom0Cpu=$(awk -v d=$((6 + 9 * a)) -v e=$((2 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    dom0IOBi=$(awk -v d=$((6 + 9 * a)) -v e=$((4 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    dom0IOBo=$(awk -v d=$((6 + 9 * a)) -v e=$((5 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    dom0BWTx=$(awk -v d=$((6 + 9 * a)) -v e=$((6 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    dom0BWRx=$(awk -v d=$((6 + 9 * a)) -v e=$((7 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    dom0Mem=$(awk -v d=$((8 + 9 * a)) -v e=$((2)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    g=$((g+1))
                else
                    vmCpu=$(awk -v d=$((6 + 9 * a)) -v e=$((2 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    vmIOBi=$(awk -v d=$((1 + a)) -v e=$((3)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${vmname[$q]}-io.log)
                    vmIOBo=$(awk -v d=$((1 + a)) -v e=$((5)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${vmname[$q]}-io.log)
                    vmBWTx=$(awk -v d=$((6 + 9 * a)) -v e=$((6 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    vmBWRx=$(awk -v d=$((6 + 9 * a)) -v e=$((7 + 7 * b)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
                    vmMem=$(awk -v d=$((3 + 2 * a)) -v e=$((2)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${vmname[$q]}.log)
                    # here I am removing the last three characters of vmMem, i.e. 2323.34 then equals to 2323
                    vmMemInteger=${vmMem:0:-3}
                    # This calculation is to calculate total memory used by all the VMs
                    vmMemTotal=`expr "$vmMemTotal" + "$vmMemInteger"`
                    printf "%8.2f" $vmCpu;
                    printf "%13.2f" $vmMem;
                    printf "%13.2f" $vmIOBi;
                    printf "%13.2f" $vmIOBo;
                    printf "%13.2f" $vmBWTx;
                    printf "%13.2f" $vmBWRx;
                    printf "   |   ";
                    q=$((q+1))
                fi
                b=$((b+1))
            done
            pmCpu=$(awk -v d=$((7 + 9 * a)) -v e=$((2)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
            pmIOBi=$(awk -v d=$((9 + 9 * a)) -v e=$((3)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
            pmIOBo=$(awk -v d=$((9 + 9 * a)) -v e=$((5)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
            pmBWTx=$(awk -v d=$((10 + 9 * a)) -v e=$((5)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
            pmBWRx=$(awk -v d=$((10 + 9 * a)) -v e=$((3)) 'FNR==d {print $e}' ${outputRefineFileName}${i}-${pmname[$y]}.log)
            # here I am removing the last three characters of dom0Mem, i.e. 2323.34 then equals to 2323
            dom0MemInteger=${dom0Mem:0:-3}
            # This is adding total memory used by all VMs and Dom0, which we are using as total physical memory used
            pmMem=`expr "$dom0MemInteger" + "$vmMemTotal"`
            printf "%8.2f" $dom0Cpu;
            printf "%13.2f" $dom0Mem;
            printf "%13.2f" $dom0IOBi;
            printf "%13.2f" $dom0IOBo;
            printf "%13.2f" $dom0BWTx;
            printf "%13.2f" $dom0BWRx;
            printf "   |   ";
            printf "%8.2f" $pmCpu;
            printf "%13.2f" $pmMem;
            printf "%13.2f" $pmIOBi;
            printf "%13.2f" $pmIOBo;
            printf "%13.2f" $pmBWTx;
            printf "%13.2f" $pmBWRx;
            printf "   |   ";
            a=$((a+1)) 
        done
        printf "\n";
        # All the output is directed to this file
        } >> $outRefine.log
        echo "Test $i of $1: Refine PM (${pm[$y]}), and VMs (${vm[@]}) is done: $(date)"
        y=$((y+1))
    done
    i=$((i+1))
done
echo " "
