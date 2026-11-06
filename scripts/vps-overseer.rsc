:do {

    :local conf {
        "vpn"={address="..."; user="..."};
        "npv"={address="..."; user="..."};
    };

    :foreach vps,data in=$conf do={

        :do {

            /system ssh-exec address=($data->"address") user=($data->"user") command="sudo apt-get clean; sudo apt-get autoclean; sudo apt-get --purge autoremove -y";
            /system ssh-exec address=($data->"address") user=($data->"user") command="sudo apt update; sudo apt upgrade -y";
            /system ssh-exec address=($data->"address") user=($data->"user") command="sudo shutdown -r now";

        } on-error={};

    };

} on-error={};