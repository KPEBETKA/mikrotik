:do {
    :local conf {
        "0xb16b00b"={address="..."; user="..."};
        "0xbada55"={address="..."; user="..."};
    };

    :foreach name,data in=$conf do={
        :local addr ($data->"address");
        :local user ($data->"user");

        :do {
            /system ssh-exec address=$addr user=$user command="\
                export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a; \
                apt-get update -qq; \
                apt-get -y -qq -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade; \
                dpkg -l 'linux-*' | sed '/^ii/!d;/'\"\$(uname -r | sed \"s/\\(.*\\)-\\([^0-9]\\+\\)/\\1/\")\"'/d;s/^[^ ]* [^ ]* \\([^ ]*\\).*/\\1/;/[0-9]/!d' | grep -E \"(image|headers|modules)\" | grep -v hwe | xargs -r apt-get -y -qq purge; \
                apt-get clean; \
                apt-get autoclean; \
                apt-get -y --purge autoremove";
        } on-error={};

        :do {
            /system ssh-exec address=$addr user=$user command="shutdown -r +1";
        } on-error={};
    };
} on-error={};