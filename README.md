# VulnScan

This tool uses multiple tools and Saves their Output to a text file. It integrates various tools like HTTPX, Katana, Nuclei, etc.

Note: Use with caution. You are responsible for your actions. Developers assume no liability and are not responsible for any misuse or damage.

Running the Program:

```sh
git clone https://github.com/0zk3y/VulnScan
```

```sh
cd VulnScan
```

```sh
sudo sh VulnScan
```

Note: This tool is very slow as it runs Tools like SQLMap and Nuclei over all URLs it finds, hence takes a lot of patience. Results may be falsepositives you will have to validate that yourself. Also this tool will generate a lot of Duplicates so please remove them using ```aws``` or ```uniq``` command.