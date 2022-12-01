#!/bin/bash
#Make Sure GO Lang in installed over your Machine
echo "Please enter Domain Name"
read urlname
echo "You are setting Target as:" $urlname
echo "Checking if Binaries are installed or not"
if which nuclei >/dev/null; then
    echo "Nuclei found"
else
    echo "Nuclei not found"
fi
if which katana 2>&1 ; then
    echo "Katana found"
else
    echo "Katana not found"
fi
if which httpx 2>&1 ; then
    echo "httpx found"
else
    echo "httpx not found"
fi
if which sublist3r 2>&1 ; then
    echo "Sublist3r found"
else
    echo "Sublist3r not found"
fi
echo "====================================================================================================================================="
echo "Developed by Raziq"
echo "====================================================================================================================================="
echo "Running Scan on" $urlname
subfinder -d $urlname >> subdomains.txt; httpx --silent subdomains.txt >> alive_domains.txt; katana --silent alive_domains.txt >> endpoints.txt; nuclei -l endpoints.txt -o nuclei_output.txt
