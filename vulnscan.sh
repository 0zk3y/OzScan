#!/bin/bash
#Make Sure GO Lang and other Tools Installed in installed over your Machine
if [ $(id -u) -ne 0 ]; then echo "Please run the script as Root"; exit 1; fi
echo "Please enter Domain Name you want to scan:"
read urlname
echo "You are setting Target as:" $urlname
echo "Please select what type of Scan do you want"
echo "1. List Subdomains Only"
echo "2. Vulnerability Scan with Nuclei over provided URL"
echo "3. Vulnerability Scan with Nuclei over all Endpoints of All Subdomains"
echo "4. Vulnerability Scan with Nuclei and SQLMap over SQLi Parameters over Domain"
echo "5. Vulnerability Scan with Nuclei and SQLMap over SQLi Parameters over Domain and all subdomains"
read option
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
    go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
fi
if which sqlmap >/dev/null; then
    echo "SQLMap found"
else
    echo "SQLMap not found, Trying to install SQLmap (Make sure Python is installed, else it will fail)"
    pip install --upgrade sqlmap
fi
if which gf >/dev/null; then
    echo "gf found"
else
    echo "gf not found, Trying to install gf (Make sure GO Lang is installed, else it will fail)"
   go get -u github.com/tomnomnom/gf
fi
if which waybackurls >/dev/null; then
    echo "waybackurls found"
else
    echo "waybackurls not found, Trying to install waybackurls (Make sure GO Lang is installed, else it will fail)"
    go get -u github.com/tomnomnom/waybackurls
fi
if [ "$option" -eq "1" ]; then
echo "Running Scan on" $urlname
subfinder -d $urlname >> subdomains.txt
fi
echo "====================================================================================================================================================="
echo "Scanning Completed, results are saved as below"
echo "Subfinder: subdomains.txt"
echo "====================================================================================================================================================="
exit 1
echo "====================================================================================================================================================="
if [ "$option" -eq "2" ]; then
echo "Running Scan on" $urlname
katana --silent $urlname >> endpoints.txt; nuclei -l endpoints.txt -o nuclei_output.txt
echo "====================================================================================================================================================="
echo "Scanning Completed, results are saved as below"
echo "Katana: endpoints.txt"
echo "Nuclei: nuclei_output.txt"
echo "====================================================================================================================================================="
exit 1
echo "====================================================================================================================================================="
if [ "$option" -eq "3" ]; then
echo "Running Scan on" $urlname
subfinder -d $urlname >> subdomains.txt; httpx --silent subdomains.txt >> alive_domains.txt; katana --silent alive_domains.txt >> endpoints.txt; nuclei -l endpoints.txt -o nuclei_output.txt
echo "====================================================================================================================================================="
echo "Scanning Completed, results are saved as below"
echo "Subfinder: subdomains.txt"
echo "httpx: alive_domains.txt"
echo "Katana: endpoints.txt"
echo "Nuclei: nuclei_output.txt"
echo "====================================================================================================================================================="
exit 1
echo "====================================================================================================================================================="
if [ "$option" -eq "4" ]; then
echo "Running Scan on" $urlname
katana --silent $urlname >> endpoints.txt; waybackurls $urlname >> all_urls.txt ; echo $urlname | sudo gf sqli >> sqli; nuclei -l endpoints.txt -o nuclei_output.txt; sqlmap -m sqli --batch --level 5 --risk 3
echo "====================================================================================================================================================="
echo "Scanning Completed, results are saved as below"
echo "Katana: endpoints.txt"
echo "Nuclei: nuclei_output.txt"
echo "WaybackUrls: all_urls.txt"
echo "gf: sqli"
echo "sqlmap check in your /home/YOURUSERNAME/.local/share/sqlmap/output/"$urlname
echo "====================================================================================================================================================="
exit 1
echo "====================================================================================================================================================="
if [ "$option" -eq "5" ]; then
echo "Running Scan on" $urlname
subfinder -d $urlname >> subdomains.txt; httpx --silent subdomains.txt >> alive_domains.txt; katana --silent alive_domains.txt >> endpoints.txt; waybackurls >> all_urls.txt ; $urlname | sudo gf sqli >> sqli | nuclei -l endpoints.txt -o nuclei_output.txt; sqlmap -m sqli --batch --level 5 --risk 3
echo "====================================================================================================================================================="
echo "Scanning Completed, results are saved as below"
echo "Subfinder: subdomains.txt"
echo "httpx: alive_domains.txt"
echo "Katana: endpoints.txt"
echo "Nuclei: nuclei_output.txt"
echo "WaybackUrls: all_urls.txt"
echo "gf: sqli"
echo "sqlmap check in your /home/YOURUSERNAME/.local/share/sqlmap/output/"$urlname
echo "====================================================================================================================================================="
exit 1
echo "====================================================================================================================================================="
if [ "$option" -ne "1" ] || [ "$option" -ne "2" ] || [ "$option" -ne "3" ] || [ "$option" -ne "4" ] || [ "$option" -ne "5" ]; then
    echo "Please select a valid option"
    exit 1
