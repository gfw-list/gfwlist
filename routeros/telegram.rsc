/log info "add telegram"
/ip firewall address-list remove [/ip firewall address-list find list=Telegram]
/ip firewall address-list                       
:do { add address=91.108.56.0/22 list=Telegram } on-error={}
:do { add address=91.108.4.0/22 list=Telegram } on-error={}
:do { add address=91.108.8.0/22 list=Telegram } on-error={}
:do { add address=91.108.16.0/22 list=Telegram } on-error={}
:do { add address=91.108.12.0/22 list=Telegram } on-error={}
:do { add address=149.154.160.0/20 list=Telegram } on-error={}
:do { add address=91.105.192.0/23 list=Telegram } on-error={}
:do { add address=91.108.20.0/22 list=Telegram } on-error={}
:do { add address=185.76.151.0/24 list=Telegram } on-error={}
