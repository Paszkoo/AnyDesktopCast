# AnyDesktopCast
nginx server listening for RTMP protocol stream then converting it to HLS for web player app

# Desire of the project
There is not any free-ware application for trasmitting and receiving video better than 1080p 30Hz i.e. miraCast only support FHD 30Hz
I wanted to transmit 4k 120Hz via my private local network cause i have nice PC but i dont have any blue-ray or something like it.
So i wanted to stream my desktop to TV with LGwebOS (look LG_webOS_app).

## nginx server config
/Linux-server/plik_konfiguracyjny_nginx.txt - nginx config file /etc/nginx/nginx.conf
configured to listen for RTMP transmission and then converting it to HLS via rtmp-relay.sh

## rtmp-relay.sh
shell script which converts RTMP to HLS via ffmpeg library
also got some code for changing quality of video and basic error handler
