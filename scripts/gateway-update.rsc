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
} on-error={}