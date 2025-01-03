:do {

    :local retryflag true;
    :local maxretry 3;
    :local delay 120s;
    :local url "https://antifilter.download/list/allyouneed.lst";
    :local listname "list-antifilter";

    :for retry from=1 to=$maxretry step=1 do={

        :if (retryflag) do={

            :set $retryflag false;
            :set $counter 0;

            :if (retry > 1) do={
                :delay $delay;
            };

            :do {
                /ip firewall address-list remove [find where list=($listname."-updated")];
            } on-error={};

            :do {
                /ip firewall address-list add list=($listname."-updated") address=antifilter.download comment="antifilter.download";
            } on-error={};

            :local filesize ([/tool fetch url=$url keep-result=no as-value]->"downloaded");
            :local chunksize 64512;
            :local start 0;
            :local end ($chunksize - 1);
            :local chunks ($filesize / ($chunksize / 1024));
            :local lastchunk ($filesize % ($chunksize / 1024));

            :if ($lastchunk > 0) do={
                :set $chunks ($chunks + 1);
            };

            :for chunk from=1 to=$chunks step=1 do={

                :local comparesize ([/tool fetch url=$url keep-result=no as-value]->"downloaded");

                :if ($comparesize = $filesize) do={
                    :set $data ([:tool fetch url=$url http-header-field="Range: bytes=$start-$end" output=user as-value]->"data");
                } else={
                    :set $data [:toarray ""];
                    :set $retryflag true;
                };

                :local regexp "^((25[0-5]|(2[0-4]|[01]?[0-9]?)[0-9])\\.){3}(25[0-5]|(2[0-4]|[01]?[0-9]?)[0-9])(\\/(3[0-2]|[0-2]?[0-9])){0,1}\$";

                :if ($start > 0) do={
                    :set $data [:pick $data ([:find $data "\n"]+1) [:len $data]];
                };
                
                :while ([:len $data] != 0) do={
                    :local line [:pick $data 0 [:find $data "\n"]];

                    :if ( $line ~ $regexp ) do={    
                        :do {
                            /ip firewall address-list add list=($listname."-updated") address=$line;
                            :set $counter ($counter + 1);
                        } on-error={};        
                    };

                    :set $data [:pick $data ([:find $data "\n"]+1) [:len $data]];

                };

                :set $start (($start-512) + $chunksize); 
                :set $end (($end-512) + $chunksize); 
            
            };
        
        };

    };

    :if ($counter > 0) do={
        :do {
            /ip firewall address-list remove [find where list=$listname];
        } on-error={};

        :do {
            :foreach address in=[/ip firewall address-list find list=($listname."-updated")] do={
                :do {
                    /ip firewall address-list set list=$listname $address;
                } on-error={};
            };
        } on-error={};
    };

} on-error={};
