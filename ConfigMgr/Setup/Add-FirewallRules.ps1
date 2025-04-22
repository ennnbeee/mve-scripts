netsh advfirewall firewall add rule name=”SQL Server” dir=in action=allow protocol=TCP localport=1433
netsh advfirewall firewall add rule name=”SQL Admin Connection” dir=in action=allow protocol=TCP localport=1434
netsh advfirewall firewall add rule name=”SQL Service Broker” dir=in action=allow protocol=TCP localport=4022
netsh advfirewall firewall add rule name=”SQL Debugger/RPC” dir=in action=allow protocol=TCP localport=135
netsh advfirewall firewall add rule name=”Analysis Services” dir=in action=allow protocol=TCP localport=2383
netsh advfirewall firewall add rule name=”SQL Browser” dir=in action=allow protocol=TCP localport=2382
netsh advfirewall firewall add rule name=”HTTP” dir=in action=allow protocol=TCP localport=80
netsh advfirewall firewall add rule name=”SSL” dir=in action=allow protocol=TCP localport=443
netsh advfirewall firewall add rule name=”SQL Browser” dir=in action=allow protocol=TCP localport=1434
netsh advfirewall firewall add rule name=”ICMP Allow incoming V4 echo request” protocol=icmpv4:8,any dir=in action=allow