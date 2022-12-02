#!/bin/bash
#Make Sure GO Lang and other Tools Installed in installed over your Machine
echo "Please enter Domain Name"
read urlname
echo "You are setting Target as:" $urlname
echo "Checking if Binaries are installed or not"
if which sublist3r 2>&1 ; then
    echo "Subfinder found"
else
    echo "Subfinder not found, Trying to install subfinder (Make sure GO Lang is installed, else it will fail)"
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
fi
if which httpx 2>&1 ; then
    echo "httpx found"
else
    echo "httpx not found, Trying to install httpx (Make sure GO Lang is installed, else it will fail)"
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
fi
if which katana 2>&1 ; then
   echo "Katana found"
else
    echo "Katana not found, Trying to install Katana (Make sure GO Lang is installed, else it will fail)"
    go install github.com/projectdiscovery/katana/cmd/katana@latest
fi
if which nuclei >/dev/null; then
    echo "Nuclei found"
else
    echo "Nuclei not found, Trying to install Nuclei (Make sure GO Lang is installed, else it will fail)"
    echo "go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest"
fi
echo "====================================================================================================================================================="
echo "Developed by 0zk3y"
echo "For queries, contact @0zk3y on Twitter or raise an issue at https://github.com/0zk3y/VulnScan"
echo "====================================================================================================================================================="
echo "Running Scan on" $urlname
subfinder -d $urlname >> subdomains.txt; httpx --silent subdomains.txt >> alive_domains.txt; katana --silent alive_domains.txt >> endpoints.txt; nuclei -l endpoints.txt -o nuclei_output.txt
echo "====================================================================================================================================================="
echo "Scanning Completed, results are saved as below"
echo "Subfinder: subdomains.txt"
echo "httpx: alive_domains.txt"
echo "Katana: endpoints.txt"
echo "Nuclei: nuclei_output.txt"
echo "====================================================================================================================================================="
echo "Developed by 0zk3y"
echo "For queries, contact @0zk3y on Twitter or raise an issue at https://github.com/0zk3y/VulnScan"
echo "====================================================================================================================================================="