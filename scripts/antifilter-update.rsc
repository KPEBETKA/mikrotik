:do {
    :local lists {
        {"listname"="antifilter"; "url"="https://antifilter.download/list/allyouneed.lst"}
        {"listname"="community"; "url"="https://community.antifilter.download/list/community.lst"}
        {"listname"="opencck"; "url"="https://iplist.opencck.org/?format=text&data=cidr4&site=...&site=...&site=..."}
    }

    :local maxretry 3
    :local delay 120
    :local chunksize 64512
    :local regexp "^((25[0-5]|(2[0-4]|[01]?[0-9]?)[0-9])\\.){3}(25[0-5]|(2[0-4]|[01]?[0-9]?)[0-9])(\\/(3[0-2]|[0-2]?[0-9])){0,1}\$"

    :foreach item in=$lists do={

        :local listname ("list-" . ($item->"listname"))
        :local url ($item->"url")

        :local hostname [:pick $url ([:find $url "//"]+2) [:len $url]]
        :if ([:typeof [:find $hostname "/"]] != "nil") do={ :set hostname [:pick $hostname 0 [:find $hostname "/"]] }
        :if ([:typeof [:find $hostname ":"]] != "nil") do={ :set hostname [:pick $hostname 0 [:find $hostname ":"]] }

        :if ([:len $hostname] > 0) do={

            :local retryflag true
            :local counter 0

            :for retry from=1 to=$maxretry step=1 do={
                :if ($retryflag) do={
                    :set retryflag false
                    :set counter 0

                    :if ($retry > 1) do={ :delay $delay }

                    :do { /ip firewall address-list remove [find where list=($listname."-updated")] } on-error={}
                    :do {
                        /ip firewall address-list add list=($listname."-updated") address=$hostname comment=$hostname
                    } on-error={}

                    :local rangeOK false
                    :do {
                        :local r [/tool fetch url=$url http-header-field="Range: bytes=0-0" output=user as-value]
                        :local d ($r->"data")
                        :if ([:len $d] = 1) do={ :set rangeOK true }
                    } on-error={}

                    :if ($rangeOK) do={
                        :local filesize ([/tool fetch url=$url keep-result=no as-value]->"downloaded")
                        :local start 0
                        :local end ($chunksize - 1)
                        :local carry ""

                        :while (((($start / 1024) < $filesize) && ($retryflag = false))) do={
                            :local comparesize ([/tool fetch url=$url keep-result=no as-value]->"downloaded")
                            :if ($comparesize = $filesize) do={
                                :local data ""
                                :set data ([/tool fetch url=$url http-header-field="Range: bytes=$start-$end" output=user as-value]->"data")

                                :if ([:len $carry] > 0) do={
                                    :set data ($carry . $data)
                                    :set carry ""
                                }

                                :while ([:len $data] != 0) do={
                                    :local nl [:find $data "\n"]
                                    :if ([:typeof $nl] = "nil") do={
                                        :set carry $data
                                        :set data ""
                                    } else={
                                        :local line [:pick $data 0 $nl]
                                        :set data [:pick $data ($nl + 1) [:len $data]]
                                        :if ($line ~ $regexp) do={
                                            :do {
                                                /ip firewall address-list add list=($listname."-updated") address=$line
                                                :set counter ($counter + 1)
                                            } on-error={}
                                        }
                                    }
                                }
                            } else={
                                :set retryflag true
                            }

                            :set start ($start + $chunksize)
                            :set end ($start + $chunksize - 1)
                        }

                        :if ($retryflag = false) do={
                            :if ([:len $carry] > 0) do={
                                :if ($carry ~ $regexp) do={
                                    :do {
                                        /ip firewall address-list add list=($listname."-updated") address=$carry
                                        :set counter ($counter + 1)
                                    } on-error={}
                                }
                            }
                        }
                    } else={
                        :local data ""
                        :do {
                            :set data ([/tool fetch url=$url output=user as-value]->"data")
                        } on-error={
                            :set retryflag true
                        }

                        :if ($retryflag = false) do={
                            :if (([:len $data] > 0) && ([:len $data] < $chunksize)) do={
                                :while ([:len $data] != 0) do={
                                    :local nl [:find $data "\n"]
                                    :local line ""
                                    :if ([:typeof $nl] = "nil") do={
                                        :set line $data
                                        :set data ""
                                    } else={
                                        :set line [:pick $data 0 $nl]
                                        :set data [:pick $data ($nl + 1) [:len $data]]
                                    }
                                    :if ($line ~ $regexp) do={
                                        :do {
                                            /ip firewall address-list add list=($listname."-updated") address=$line
                                            :set counter ($counter + 1)
                                        } on-error={}
                                    }
                                }
                            } else={
                                :set retryflag true
                            }
                        }
                    }
                }

                :if (($retryflag = false) && ($counter > 0)) do={ :break }
            }

            :if (($retryflag = false) && ($counter > 0)) do={
                :do { /ip firewall address-list remove [find where list=$listname] } on-error={}
                :do {
                    :foreach address in=[/ip firewall address-list find list=($listname."-updated")] do={
                        :do { /ip firewall address-list set $address list=$listname } on-error={}
                    }
                } on-error={}
            }
        }
    }
} on-error={}