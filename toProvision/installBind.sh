sudo apt install bind9

options {
    directory "/var/cache/bind";
    forwarders {
      8.8.8.8;
    };
    dnssec-validation auto;
    listen-on-v6 { any; };
    recursion yes;
    listen-on port 53 {192.168.100.1;};
    allow-query {any;};
};




sudo systemctl restart bind9
