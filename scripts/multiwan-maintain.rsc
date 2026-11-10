:do {
    :local conf {
        "primary"={interface="ether9"; distance=3; disabled="no"};
        "reserved"={interface="ether8"; distance=2; disabled="yes"};
        "testing"={from="primary"; distance=1; disabled="no"; dst="77.88.8.8/32"};
    };

    :foreach name,data in=$conf do={
        :do {
            :local comment "multiwan-$name";
            :local dst "0.0.0.0/0";
            :local dstval ($data->"dst");
            :if ([:typeof $dstval] = "str") do={ :set dst $dstval };

            :local iface "";
            :local fromval ($data->"from");
            :if ([:typeof $fromval] = "str") do={
                :local parent ($conf->$fromval);
                :set iface ($parent->"interface");
            } else={
                :set iface ($data->"interface");
            };

            :local dhcpids [/ip dhcp-client find interface=$iface];
            :local dhcpfound false;
            :local dhcpid "";
            
            :if ([:typeof $dhcpids] = "array") do={
                :if ([:len $dhcpids] > 0) do={
                    :set dhcpid [:pick $dhcpids 0];
                    :set dhcpfound true;
                }
            } else={
                :if ([:typeof $dhcpids] = "id") do={
                    :set dhcpid $dhcpids;
                    :set dhcpfound true;
                }
            };
            
            :if ($dhcpfound) do={
                :local newgw [/ip dhcp-client get $dhcpid gateway];
                :if ([:typeof $newgw] = "array") do={ :set newgw [:pick $newgw 0] };
                
                :if ([:typeof $newgw] = "ip") do={
                    :local routeid "";
                    :local routefound false;
                    
                    :foreach iterid in=[/ip route find] do={
                        :local routecomment [/ip route get $iterid comment];
                        :if ([:typeof $routecomment] = "str" and $routecomment = $comment) do={
                            :set routeid $iterid;
                            :set routefound true;
                        }
                    }
                    
                    :local routedist ($data->"distance");
                    :local routedis ($data->"disabled");

                    :if ($routefound) do={
                        /ip route set $routeid gateway=$newgw;
                    } else={
                        /ip route add dst-address=$dst gateway=$newgw distance=$routedist disabled=$routedis comment=$comment;
                    }
                }
            }
        } on-error={};
    };

    :do {
        :local fwcomment "drop request through multiwan-reserved";
        :local reservediface (($conf->"reserved")->"interface");
        :local testingdst (($conf->"testing")->"dst");

        :if ([:typeof $reservediface] = "str" and [:typeof $testingdst] = "str") do={
            :local fwids [/ip firewall filter find comment=$fwcomment];
            :local fwcount 0;
            
            :if ([:typeof $fwids] = "array") do={ :set fwcount [:len $fwids]; } else={ :if ([:typeof $fwids] = "id") do={ :set fwcount 1; }; };
            
            :if ($fwcount > 0) do={
                :local targetid $fwids;
                :if ([:typeof $fwids] = "array") do={ :set targetid [:pick $fwids 0]; };
                /ip firewall filter remove $targetid;
            }
            
            :local allids [/ip firewall filter find];
            :local firstid "";
            :if ([:typeof $allids] = "array" and [:len $allids] > 0) do={
                :set firstid [:pick $allids 0];
            } else={
                :if ([:typeof $allids] = "id") do={ :set firstid $allids; }
            };

            :if ($firstid != "") do={
                /ip firewall filter add chain=output action=drop out-interface=$reservediface dst-address=$testingdst comment=$fwcomment place-before=$firstid;
            } else={
                /ip firewall filter add chain=output action=drop out-interface=$reservediface dst-address=$testingdst comment=$fwcomment;
            }
        }
    } on-error={};

    :do {
        :local testingdst (($conf->"testing")->"dst");
        :if ([:typeof $testingdst] = "str") do={
            :local nwhost $testingdst;
            :local slashpos [:find $nwhost "/"];
            :if ([:typeof $slashpos] = "num") do={
                :set nwhost [:pick $nwhost 0 $slashpos];
            };

            :local nwcomment "disable (or enable) reserve route if primary route is alive (or dead)";
            :local nwid "";
            :local nwfound false;
            
            :foreach iterid in=[/tool netwatch find] do={
                :local currentcomment [/tool netwatch get $iterid comment];
                :if ([:typeof $currentcomment] = "str" and $currentcomment = $nwcomment) do={
                    :set nwid $iterid;
                    :set nwfound true;
                }
            };

            :local upcmd "/ip route disable [find comment=\"multiwan-reserved\"]; /ip ipsec active-peers kill-connections; /system leds disable [find where leds=\"sfp-sfpplus-led\"];";
            :local downcmd "/ip route enable [find comment=\"multiwan-reserved\"]; /ip ipsec active-peers kill-connections; /system leds enable [find where leds=\"sfp-sfpplus-led\"];";

            :if ($nwfound) do={
                :local nwdisabled [/tool netwatch get $nwid disabled];
                :if ($nwdisabled = true) do={
                    /tool netwatch set $nwid disabled=no;
                }
            } else={
                /tool netwatch add host=$nwhost interval=5s timeout=1s comment=$nwcomment up-script=$upcmd down-script=$downcmd;
            }
        }
    } on-error={};
} on-error={}