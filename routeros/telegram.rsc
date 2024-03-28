/log info "add telegram"
/ip firewall address-list remove [/ip firewall address-list find list=Telegram]
/ip firewall address-list                       
:do { add address=5.28.195.205/32 list=Telegram } on-error={}
:do { add address=5.28.195.163/32 list=Telegram } on-error={}
:do { add address=37.77.184.0/21 list=Telegram } on-error={}
:do { add address=91.105.192.0/23 list=Telegram } on-error={}
:do { add address=91.108.0.0/16 list=Telegram } on-error={}
:do { add address=95.161.64.0/20 list=Telegram } on-error={}
:do { add address=109.239.140.0/24 list=Telegram } on-error={}
:do { add address=149.154.160.0/20 list=Telegram } on-error={}
:do { add address=185.76.151.0/24 list=Telegram } on-error={}
