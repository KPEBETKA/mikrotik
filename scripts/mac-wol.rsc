:local ip [/ip dns static get [find name=...] address];
:local mac [/ip dhcp-server lease get [find address=$ip] mac-address];

/ip arp remove [find address=$ip];
/ip arp add address=$ip mac-address=$mac interface=... comment="auto-created for ... wol";