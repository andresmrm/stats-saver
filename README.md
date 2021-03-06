# Stats-Saver
Used to monitor bandwidth use, specially for a router using OpenWRT.

## Requirements

- Lua

## Installation

Place `stats-saver.lua` in a folder in your CGI folder.
In my OpenWRT it is `/www/cgi-bin/stats/`.
I recommend to rename the file to `index.html` so it will run when you open `http://<your-router-ip>/cgi-bin/stats`
The script also needs permission to execute, like with `chmod 655 index.html`.
It's important to place the script in a new folder (like the `stats` I'm using) because it will create files there.

## Configuration

If you want to monitor the `br-lan` interface, it should find it automatically.
If not, you may need to add your interface name in the `possible_interfaces` array, in the beginning of the source file.

The QUOTA variables are used to calculate your monthly quota, for example. They are in GB.

## Run

Considering you placed the file as I said, add these lines to your crontab:

    * * * * * /usr/bin/lua /www/cgi-bin/stats/index.html save
    0 0 1 * * /usr/bin/lua /www/cgi-bin/stats/index.html mark

(You can open it with `crontab -e`)

They will monitor the interface each minute. And reset quota each month. Well, let's hope so...

## Use

Open `http://<your-router-ip>/cgi-bin/stats` with a browser.
