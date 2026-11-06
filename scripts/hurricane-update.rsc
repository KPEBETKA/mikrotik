:do {

    :local listname "list-hurricane";
    :local delay 120s;
    :local counter 0;

    :local api "https://bgp.he.net/super-lg/report/api/v1/prefixes/originated/";

    local asnlist {
        "...";
        "...";
    };

    :foreach asn in=$asnlist do={

        :local retryflag true;
        :local maxretry 3;

        :for retry from=1 to=$maxretry step=1 do={

            :if (retryflag) do={

                :set $retryflag false;

                :if (retry > 1) do={
                    :delay $delay;
                };

                :do {
                    /ip firewall address-list remove [find where list=($listname."-updated-".$asn)];
                } on-error={};

                :local filesize ([/tool fetch url=($api.$asn) keep-result=no as-value]->"downloaded");
                :local chunksize 64512;
                :local start 0;
                :local end ($chunksize - 1);
                :local chunks ($filesize / ($chunksize / 1024));
                :local lastchunk ($filesize % ($chunksize / 1024));
                :if ($filesize=0 || $lastchunk > 0) do={
                    :set chunks ($chunks + 1);
                };

                :local data "";
                :for chunk from=1 to=$chunks step=1 do={

                    :local comparefilesize ([/tool fetch url=($api.$asn) keep-result=no as-value]->"downloaded");
                    :if ($comparefilesize = $filesize) do={
                        :set data ($data . ([/tool fetch url=($api.$asn) http-header-field="Range: bytes=$start-$end" as-value output=user]->"data"));
                        :set start ($start + $chunksize);
                        :set end ($end + $chunksize);
                    } else={
                        :set $data "";
                        :set $retryflag true;
                    };

                };

                :global prefixes "";
                :set prefixes [:pick $data ([:find $data "[" -1] + 1) [:find $data "]" -1]];
                [:parse ":global prefixes; set prefixes [:toarray {$prefixes}]"];

                :local prefix "";
                :local regexp "^((25[0-5]|(2[0-4]|[01]?[0-9]?)[0-9])\\.){3}(25[0-5]|(2[0-4]|[01]?[0-9]?)[0-9])(\\/(3[0-2]|[0-2]?[0-9])){0,1}\$";

                :foreach prefix in=($prefixes->0) do={

                    :if ( $prefix ~ $regexp ) do={    
                        :do {
                            /ip firewall address-list add list=($listname."-updated-".$asn) address=$prefix;
                            :set $counter ($counter + 1);
                        } on-error={};        
                    };
                
                };

                :set prefixes;

            };

        };

    };

    :if ($counter > 0) do={

        :do {
            /ip firewall address-list remove [find where list=$listname];
        } on-error={};

        :foreach asn in=$asnlist do={

            :do {
                :foreach address in=[/ip firewall address-list find list=($listname."-updated-".$asn)] do={
                    :do {
                        /ip firewall address-list set list=$listname $address;
                    } on-error={};
                };
            } on-error={};

        };

    };

} on-error={};