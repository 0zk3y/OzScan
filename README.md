# OzScan

This tool uses multiple tools and Saves their Output to a text file. It integrates various tools like HTTPX, Katana, Nuclei, etc.

## Note: Use with caution. You are responsible for your actions. Developers assume no liability and are not responsible for any misuse or damage.

Running the Program:

```sh
git clone https://github.com/0zk3y/OzScan
cd OzScan
sudo chmod +x OzScan.sh
sudo sh OzScan.sh
```

### Note: This tool is very slow as it runs Tools like SQLMap and Nuclei over all URLs it finds, hence takes a lot of patience. Results may be falsepositives you will have to validate that yourself. Also this tool will generate a lot of Duplicates so please remove them using ```awk``` or ```uniq``` command. A New version of this tool is under development which will be a lot faster and won't try to find repeating vulnerabilities over same endpoints. I am aware of issue related to HTTPX and I'll check on it soon.

Huge Shoutout to Developers of the Tools which are used in Backend:

Nuclei- https://github.com/projectdiscovery/nuclei

Subfinder- https://github.com/projectdiscovery/subfinder

HTTPX- https://github.com/projectdiscovery/httpx

Katana- https://github.com/projectdiscovery/katana

sqlMap- https://github.com/sqlmapproject/sqlmap

WaybackURLs- https://github.com/tomnomnom/waybackurls

GF- https://github.com/tomnomnom/gf


In Progress:

XSS Detection using kxss
