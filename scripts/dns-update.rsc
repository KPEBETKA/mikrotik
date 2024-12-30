:do {

    :global lastip;

    :local curip;
    :set curip [:resolve myip.opendns.com server=208.67.222.222];

    :local host "api.cloudflare.com";
    :local zone "...";
    :local token "...";
    :local records {
        "example.net"={"...";};
        "*.example.net"={"...";};
    };

    :if ($curip != $lastip) do={

        :do {

            :foreach name,id in=$records do={

                /tool fetch mode=https \
                    http-method=put \
                    url="https://$host/client/v4/zones/$zone/dns_records/$id" \
                    http-header-field="content-type: application/json,Authorization: Bearer $token" \
                    http-data="{\"type\":\"A\",\"name\":\"$name\",\"content\":\"$curip\"}" \
                    output=none;

            };

            :set lastip $curip;

        } on-error={};

    };

} on-error={};
