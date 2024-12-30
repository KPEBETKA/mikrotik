:do {

    :local conf {
        "default"={interface="ether9" ; comment="domru"} ;
        "reserved"={interface="ether8" ; comment="mts"} ;
        "testing"={interface="ether9" ; comment="test"} ;
    };

    :foreach gateway,data in=$conf do={

        :local newgw [/ip dhcp-client get [find interface=($data->"interface")] gateway];
        :local routegw [/ip route get [find comment=($data->"comment")] gateway ];

        :if ($newgw != $routegw) do={
            /ip route set [find comment=($data->"comment")] gateway=$newgw;
        };

    };

} on-error={};
