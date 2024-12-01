# install-xmpp-dino
this script installs the XMPP client Dino under an Ubuntu 24.04. If the script runs successful you will find the binary under dino/build/

It will download the source in version v0.4.4, and compiles it.

you only need to download the script install-dino.sh in a diretory, then open a terminal in this directory and run:
```Shell
sudo bash install-dino.sh
```

if all runs successful, after the above command you can run dino with the command:
```Shell
./dino/build/dino
```

hint:
you need perhaps a configured git in order to download the dino sources. To configure git you can write the following commnads:
```Shell
git config --global user.name "your Name"
git config --global user.email "your_email@example.com"
```

hint 2:
Dino is able to do Voicecalls and Videocalls with this installation. but your server (of your xmpp account) need to support this. i.e with a linked coturn server.
