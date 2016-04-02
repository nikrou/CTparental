#!/bin/bash
# CTparental.sh
#
# par Guillaume MARSAT
# Corrections orthographiques par Pierre-Edouard TESSIER
# une partie du code est tirée du script alcasar-bl.sh créé par Franck BOUIJOUX et Richard REY
# présente dans le code du projet alcasar en version 2.6.1 ; web page http://www.alcasar.net/

# This script is distributed under the Gnu General Public License (GPL)
DIR_CONF="/usr/local/etc/CTparental"
#chargement des locales.
set -a
source gettext.sh
set +a
export TEXTDOMAINDIR="$DIR_CONF/locale"
export TEXTDOMAIN=${LANG:0:2}
. /usr/bin/gettext.sh



if [ ! $UID -le 499 ]; then # considère comme root tous les utilisateurs avec un uid inferieur ou egale a 499,ce qui permet à apt-get,urpmi,yum... de lancer le script sans erreur.
	gettext 'It root of the need to run this script.'
	echo ""
	exit 1
fi

if  [ "$(groups "$(whoami)" | grep -c -E "( ctoff$)|( ctoff )")" -eq 0 ];then
  export https_proxy=http://127.0.0.1:8080
  export HTTPS_PROXY=http://127.0.0.1:8080
  export http_proxy=http://127.0.0.1:8080
  export HTTP_PROXY=http://127.0.0.1:8080
else
  unset https_proxy
  unset HTTPS_PROXY
  unset http_proxy
  unset HTTP_PROXY
fi

noinstalldep="0"
nomanuel="0"
for arg in "$@" ; do
	case $arg in
		-nodep )
			noinstalldep="1"
		;;
		-nomanuel )
			nomanuel="1"
		;;
		-dirhtml )
			narg=$(( "$narg" +1 ))
			DIRhtmlPersonaliser=${ARGS[$narg]}
			if [ ! -d "$DIRhtmlPersonaliser" ];then
				gettext 'Invalid directory path!'
				exit 0
			fi	
		;;
	esac
done
pause () {   # fonction pause pour debugage
      MESSAGE="$*"
      choi=""
      MESSAGE=${MESSAGE:=$(gettext "continue to press a button:")}
      echo  "$MESSAGE"
      while (true); do
         read choi
         case $choi in
         * )
         break
         ;;
      esac
      done
}
SED="/bin/sed -i"
FILE_CONF="$DIR_CONF/CTparental.conf"
FILE_GCTOFFCONF="$DIR_CONF/GCToff.conf"
FILE_HCOMPT="$DIR_CONF/CThourscompteur"
FILE_HCONF="$DIR_CONF/CThours.conf"
if [ ! -f $FILE_CONF ] ; then
mkdir -p $DIR_CONF
mkdir -p /usr/local/share/CTparental/
cat << EOF > $FILE_CONF
LASTUPDATE=0
DNSMASQ=BLACK
AUTOUPDATE=OFF
HOURSCONNECT=OFF
GCTOFF=OFF
SAFEGOOGLE=ON
SAFEYOUTUBE=ON
SAFEBING=ON
SAFEDUCK=ON
# Parfeux minimal.
IPRULES=OFF
EOF

fi
FILTRAGEISOFF="$(cat < $FILE_CONF | grep -c "DNSMASQ=OFF" )"



## imports du plugin de la distributions si il existe
if [ -f "${DIR_CONF}/dist.conf" ];then . "${DIR_CONF}/dist.conf"; fi

tempDIR="/tmp/alcasar"
tempDIRRamfs="/tmp/alcasarRamfs"
if [ ! -d $tempDIRRamfs ]; then mkdir "${tempDIRRamfs}"; fi
RougeD="\033[1;31m"
BleuD="\033[1;36m"
#VertD="\033[1;32m"
Fcolor="\033[0m"
COMMONFILEGS="common-auth"
GESTIONNAIREDESESSIONS=" login gdm lightdm slim kdm xdm lxdm gdm3 "
FILEPAMTIMECONF="/etc/security/time.conf"
DIRPAM="/etc/pam.d/"
DAYS=${DAYS:="$(gettext "monday") $(gettext "tuesday") $(gettext "wednesday") $(gettext "thursday") $(gettext "friday") $(gettext "saturday") $(gettext "sunday") "}
DAYS=( $DAYS )
DAYSPAM=( Mo Tu We Th Fr Sa Su )
DAYSCRON=( mon tue wed thu fri sat sun )
PROXYport=${PROXYport:="8888"}
E2GUport=${E2GUport:="8080"}
PROXYuser=${PROXYuser:="privoxy"}
#### DEPENDANCES par DEFAULT #####
DEPENDANCES=${DEPENDANCES:=" console-data e2guardian dnsmasq lighttpd php5-cgi libnotify-bin notification-daemon iptables-persistent rsyslog privoxy openssl libnss3-tools whiptail "}
#### PACKETS EN CONFLI par DEFAULT #####
CONFLICTS=${CONFLICTS:=" dansguardian mini-httpd apache2 firewalld "}

#### COMMANDES de services par DEFAULT #####
CMDSERVICE=${CMDSERVICE:="service "}
CRONstart=${CRONstart:="$CMDSERVICE cron start "}
CRONstop=${CRONstop:="$CMDSERVICE cron stop "}
CRONrestart=${CRONrestart:="$CMDSERVICE cron restart "}
LIGHTTPDstart=${LIGHTTPDstart:="$CMDSERVICE lighttpd start "}
LIGHTTPDstop=${LIGHTTPDstop:="$CMDSERVICE lighttpd stop "}
LIGHTTPDrestart=${LIGHTTPDrestart:="$CMDSERVICE lighttpd restart "}
DNSMASQstart=${DNSMASQstart:="$CMDSERVICE dnsmasq start "}
DNSMASQstop=${DNSMASQstop:="$CMDSERVICE dnsmasq stop "}
DNSMASQrestart=${DNSMASQrestart:="$CMDSERVICE dnsmasq restart "}
NWMANAGERstop=${NWMANAGERstop:="$CMDSERVICE network-manager stop"}
NWMANAGERstart=${NWMANAGERstart:="$CMDSERVICE network-manager start"}
NWMANAGERrestart=${NWMANAGERrestart:="$CMDSERVICE network-manager restart"}
IPTABLESsave=${IPTABLESsave:="$CMDSERVICE iptables-persistent save"}
E2GUARDIANrestart=${E2GUARDIANrestart:="$CMDSERVICE e2guardian restart"}
PRIVOXYrestart=${PRIVOXYrestart:="$CMDSERVICE privoxy restart"}
#### LOCALISATION du fichier PID lighttpd par default ####
LIGHTTPpidfile=${LIGHTTPpidfile:="/var/run/lighttpd.pid"}

#### LOCALISATION du fichier de chargement de modules ####
FILEMODULESLOAD=${MODULESLOAD:="/etc/modules-load.d/modules.conf"}

RSYSLOGCTPARENTAL=${RSYSLOGCTPARENTAL:="/etc/rsyslog.d/iptables.conf"}

#### COMMANDES D'ACTIVATION DES SERVICES AU DEMARAGE DU PC ####
ENCRON=${ENCRON:=""}
ENLIGHTTPD=${ENLIGHTTPD:=""}
ENDNSMASQ=${ENDNSMASQ:=""}
ENNWMANAGER=${ENNWMANAGER:=""}
ENIPTABLESSAVE=${ENIPTABLESSAVE:=""}
#### UID MINIMUM pour les UTILISATEUR
UIDMINUSER=${UIDMINUSER:=1000}

FILESYSCTL=${FILESYSCTL:="/etc/sysctl.conf"}
DIRE2G=${DIRE2G:="/etc/e2guardian/"}
DIRE2GLANG=${DIRE2GLANG:="/usr/share/e2guardian/languages/"}
NEWTEMPLETE2G=${NEWTEMPLETE2G:=/usr/local/share/CTparental/confe2guardian}
FILEConfe2gu=${FILEConfe2gu:=$DIRE2G"e2guardian.conf"}
FILEConfe2guf1=${FILEConfe2guf1:=$DIRE2G"e2guardianf1.conf"}
DNSMASQCONF=${DNSMASQCONF:="/etc/dnsmasq.conf"}
MAINCONFHTTPD=${MAINCONFHTTPD:="/etc/lighttpd/lighttpd.conf"}
DIRCONFENABLEDHTTPD=${DIRCONFENABLEDHTTPD:="/etc/lighttpd/conf-enabled"}
CTPARENTALCONFHTTPD=${CTPARENTALCONFHTTPD:="$DIRCONFENABLEDHTTPD/10-CTparental.conf"}
DIRHTML=${DIRHTML:="/var/www/CTparental"}
DIRadminHTML=${DIRadminHTML:="/var/www/CTadmin"}
PASSWORDFILEHTTPD=${PASSWORDFILEHTTPD:="/etc/lighttpd/lighttpd-htdigest.user"}
REALMADMINHTTPD=${REALMADMINHTTPD:="interface admin"}
CADIR=${CADIR:="/usr/share/ca-certificates/ctparental"}
PEMSRVDIR=${PEMSRVDIR:="/etc/ssl/private"}
CMDINSTALL=""
IPTABLES=${IPTABLES:="/sbin/iptables"}
ADDUSERTOGROUP=${ADDUSERTOGROUP:="gpasswd -a "}
DELUSERTOGROUP=${DELUSERTOGROUP:="gpasswd -d "}
PRIVOXYCONF=${PRIVOXYCONF:="/etc/privoxy/config"}
PRIVOXYUSERA=${PRIVOXYUSERA:="/etc/privoxy/user.action"}
PRIVOXYCTA=${PRIVOXYCTA:="/etc/privoxy/ctparental.action"}
CTFILEPROXY=${CTFILEPROXY:="$DIR_CONF/CT-proxy.sh"}
XSESSIONFILE=${XSESSIONFILE:="/etc/X11/Xsession"}
REPCAMOZ=${REPCAMOZ:="/usr/share/ca-certificates/mozilla/"}
DOMAINEDEPOTS=${DOMAINEDEPOTS:=$(cat /etc/apt/sources.list /etc/apt/sources.list.d/* | grep "^deb" | cut -d"/" -f3 | sort -u | sed -e "s/^www././g")}
TIMERALERT=${TIMERALERT:=10}

if [ "$(yum help 2> /dev/null | wc -l )" -ge 50 ] ; then
   ## "Distribution basée sur yum exemple redhat, fedora..."
   CMDINSTALL=${CMDINSTALL:="yum install "}
   CMDREMOVE=${CMDREMOVE:="rpm -e "}
fi
urpmi --help 2&> /dev/null
if [ $? -eq 1 ] ; then
   ## "Distribution basée sur urpmi exemple mandriva..."
   CMDINSTALL=${CMDINSTALL:="urpmi -a --auto "}
   CMDREMOVE=${CMDREMOVE:="rpm -e "}
fi
apt-get -h 2&> /dev/null
if [ $? -eq 0 ] ; then
   ## "Distribution basée sur apt-get exemple debian, ubuntu ..."
   CMDINSTALL=${CMDINSTALL:="apt-get -y --force-yes install "}
   CMDREMOVE=${CMDREMOVE:="dpkg --purge  "}
fi

if [ -z "$CMDINSTALL" ] ; then
   gettext 'No known package manager, was detected.'
   set -e
   exit 1
fi

ip_route="$(ip route)"
interface_WAN="$(awk '{print $5}' <<< ${ip_route})" # GW!
ipbox="$(awk '{print $3}' <<< ${ip_route})"   
if [ "$(ifconfig | grep -c "adr" )" -ge 1 ];then 
	## jessie et infèrieur
	ipinterface_WAN="$(ifconfig "$interface_WAN" | awk '/adr:/{print substr($2,5)}')"
	ip_broadcast="$(ifconfig "$interface_WAN" | awk '/Bcast:/{ print substr($3,7)}')"	
else
	## testing/sid
	ipinterface_WAN="$(ifconfig "$interface_WAN" | awk '/inet /{print substr($2,1)}')"
	ip_broadcast="$(ifconfig "$interface_WAN" | awk '/broadcast /{print substr($6,1)}')"
fi
reseau_box="$(awk '/'"${ipinterface_WAN}"'/{print $10}' <<< ${ip_route})"
export interface_WAN
export ipbox
export ipinterface_WAN
export reseau_box
export ip_broadcast
unset ip_route
nameserver="$(cat < /etc/resolv.conf | awk '/nameserver/ { print $2 }' | tr '\n' ' ')"
DNS1="$(echo "${nameserver}" | awk '{ print $1}')"
DNS2="$(echo "${nameserver}" | awk '{ print $2}')"
#echo $interface_WAN $ipbox $ipinterface_WAN $reseau_box $ip_broadcast $DNS1 $DNS2

ipMaskValide() {
ip=$(echo "$1" | cut -d"/" -f1)
mask=$(echo "$1" | grep "/" | cut -d"/" -f2)
if [ "$(echo "$1" | grep -c "^\(\(2[0-5][0-5]\|2[0-4][0-9]\|1[0-9][0-9]\|[0-9]\{1,2\}\)\.\)\{3\}\(2[0-5][0-5]\|2[0-4][0-9]\|1[0-9][0-9]\|[0-9]\{1,2\}\)$")" -eq 1 ];then
	echo 1
	return 1
fi
if [ ! "$(echo "$ip" | grep -c "^\(\(2[0-5][0-5]\|2[0-4][0-9]\|1[0-9][0-9]\|[0-9]\{1,2\}\)\.\)\{3\}\(2[0-5][0-5]\|2[0-4][0-9]\|1[0-9][0-9]\|[0-9]\{1,2\}\)$")" -eq 1 ];then
	echo 0
	return 0
fi
if [ "$(echo "$mask" | grep -c "^\([1-9]\|[1-2][0-9]\|3[0-2]\)$")" -eq 1 ];then
	echo 1
	return 1
fi
i=1 
octn=255
result=1
while [ $i -le 4 ]
do
oct=$( echo "$mask" | grep '\.'| cut -d "." -f$i )
if [ -z "$oct" ] ; then
	result=0
	break
fi
if [ ! "$octn" -eq 255 ];then
	if [ ! "$oct" -eq 0 ];then
		result=0
		break
	fi
fi 
octn=$oct
if [ ! "$oct" -eq 255 ] &&  [ ! "$oct" -eq 254 ]  &&  [ ! "$oct" -eq 252 ] &&  [ ! "$oct" -eq 248 ] &&  [ ! "$oct" -eq 240 ] &&  [ ! "$oct" -eq 224 ] &&  [ ! "$oct" -eq 192 ] &&  [ ! "$oct" -eq 128 ] &&  [ ! "$oct" -eq 0 ]; then
	result=0
	break	
  fi
i=$(( i + 1 ))
done
   echo $result
   return $result
}

if [ "$(echo "$interface_WAN" | grep -c -E "^[a-zA-Z0-9]*$")" -eq 0 -o  "$( ipMaskValide "$ipbox" )" -eq 0 -o "$( ipMaskValide "$ipinterface_WAN" )" -eq 0 \
 -o "$( ipMaskValide "$DNS1" )" -eq 0  -o "$( ipMaskValide "$DNS2" )" -eq 0 -o "$( ipMaskValide "$ip_broadcast" )" -eq 0 \
 -o "$( ipMaskValide "$reseau_box" )" -eq 0 ];then
gettext 'error recovery network settings'
echo
exit 1
fi 

resolvconffixon () {
echo "<resolvconffixon>"
# redemare dnsmasq 
$DNSMASQstop

resolvconf -u 2&> /dev/null 
if [ $? -eq 1 ];then # si resolvconf et bien installé
resolvconf -u
# on s'assure que les dns du FAI soit bien ajoutés au fichier /etc/resolv.conf malgré l'utilisation de dnsmasq.
cat < /etc/resolv.conf | grep ^nameserver | sort -u > /etc/resolvconf/resolv.conf.d/tail
fi
$DNSMASQstart
echo "</resolvconffixon>"
}
resolvconffixoff () {
echo "<resolvconffixoff>"
$DNSMASQstop	
resolvconf -u 2&> /dev/null 
if [ $? -eq 1 ];then # si resolvconf et bien installé
echo > /etc/resolvconf/resolv.conf.d/tail
resolvconf -u
fi
echo "</resolvconffixoff>"
}


PRIVATE_IP="127.0.0.10"

FILE_tmp=${FILE_tmp:="$tempDIRRamfs/filetmp.txt"}
FILE_tmpSizeMax=${FILE_tmpSizeMax:="128M"}  # 70 Min, Recomend 128M 
LOWRAM=${LOWRAM:=0}
if [ "$LOWRAM" -eq 0 ] ; then
MFILEtmp="mount -t tmpfs -o size=$FILE_tmpSizeMax tmpfs $tempDIRRamfs"
UMFILEtmp="umount $tempDIRRamfs"
else
MFILEtmp=""
UMFILEtmp=""
fi
BL_SERVER="dsi.ut-capitole.fr"
FILEIPBLACKLIST="$DIR_CONF/ip-blackliste"
FILEIPTABLES="$DIR_CONF/iptables"
FILEIPTIMEWEB="$DIR_CONF/iptables-timerweb"
CATEGORIES_ENABLED="$DIR_CONF/categories-enabled"
BL_CATEGORIES_AVAILABLE="$DIR_CONF/bl-categories-available"
WL_CATEGORIES_AVAILABLE="$DIR_CONF/wl-categories-available"
DIR_DNS_FILTER_AVAILABLE="$DIR_CONF/dnsfilter-available"
DIR_DNS_BLACKLIST_ENABLED="$DIR_CONF/blacklist-enabled"
DIR_DNS_WHITELIST_ENABLED="$DIR_CONF/whitelist-enabled"
DNS_FILTER_OSSI="$DIR_CONF/blacklist-local"
DREAB="$DIR_CONF/domaine-rehabiliter" 
E2GUXSITELIST="/etc/dansguardian/lists/exceptionsitelist"
THISDAYS=$(( $(date +%Y) * 365 + $(date +%j | sed -e "s/^0*//g") ))
MAXDAYSFORUPDATE="7" # update tous les 7 jours
CHEMINCTPARENTLE="$(readlink -f "$0")"

initblenabled () {
   cat << EOF > $CATEGORIES_ENABLED
adult
agressif
dangerous_material
dating
drogue
gambling
hacking
malware
marketingware
mixed_adult
phishing
redirector
sect
strict_redirector
strong_redirector
tricheur
warez
ossi   
EOF
         

}
confe2guardian () {
  # replace the default deny HTML page
 
  echo "<confe2guardian>"
  $SED "s?^loglevel =.*?loglevel = 0?g" "$FILEConfe2gu"
  $SED "s?^languagedir =.*?languagedir = $DIRE2GLANG?g" "$FILEConfe2gu"
  $SED "s?^language =.*?language = 'french'?g" "$FILEConfe2gu"
  $SED "s?^logexceptionhits =.*?logexceptionhits = 0?g" "$FILEConfe2gu"
  $SED "s?^filterip =.*?filterip = 127.0.0.1?g" "$FILEConfe2gu"
  $SED "s?^proxyip =.*?proxyip = 127.0.0.1?g" "$FILEConfe2gu"
  $SED "s?^filterports =.*?filterports = $E2GUport?g" "$FILEConfe2gu"
  $SED "s?^proxyport =.*?proxyport = $PROXYport?g" "$FILEConfe2gu"
  $SED "s?.*UNCONFIGURED.*?#UNCONFIGURED?g" "$FILEConfe2gu"
cat << EOF > "$DIRE2G"lists/bannedsitelist
#Blanket Block.  To block all sites except those in the
#exceptionsitelist and greysitelist files, remove
#the # from the next line to leave only a '**':
#**

#Blanket SSL/CONNECT Block.  To block all SSL
#and CONNECT tunnels except to addresses in the
#exceptionsitelist and greysitelist files, remove
#the # from the next line to leave only a '**s':
#**s

#Blanket IP Block.  To block all sites specified only as an IP,
#remove the # from the next line to leave only a '*ip':
#*ip

#Blanket SSL/CONNECT IP Block.  To block all SSL and CONNECT
#tunnels to sites specified only as an IP,
#remove the # from the next line to leave only a '**ips':
#**ips

$(gettext "#the domain filtering is handled by dnsmasq, do not touch this file !!")

EOF

$E2GUARDIANrestart
cp -f "$NEWTEMPLETE2G"/template.html "$DIRE2GLANG"ukenglish/
cp -f "$NEWTEMPLETE2G"/template-fr.html "$DIRE2GLANG"french/template.html
sed -i "s/é/\&eacute;/g" "$DIRE2GLANG"french/messages
sed -i "s/è/\&egrave;/g" "$DIRE2GLANG"french/messages
$E2GUARDIANrestart
echo "</confe2guardian>"
}

confprivoxy () {
	
echo "<confprivoxy>"
$SED "s?^debug.*?debug = 0?g"  "$PRIVOXYCONF"
$SED "s?^listen-address.*?listen-address  127.0.0.1:$PROXYport?g"  "$PRIVOXYCONF"

	test=$(grep -c "actionsfile ctparental.action" "$PRIVOXYCONF" )
	if [ "$test" -ge "1" ] ; then
		$SED "s?actionsfile.*ctparental.*?actionsfile ctparental\.action      # ctparental customizations?g" "$PRIVOXYCONF"
	else
	    nline=$(grep "actionsfile.*user.action" "$PRIVOXYCONF" -n | cut -d":" -f1)
		$SED "$nline""i\actionsfile ctparental.action      # ctparental customizations" "$PRIVOXYCONF"
	fi
	unset test
cat << 'EOF' >  $PRIVOXYCTA
{{alias}}
+crunch-all-cookies = +crunch-incoming-cookies +crunch-outgoing-cookies
-crunch-all-cookies = -crunch-incoming-cookies -crunch-outgoing-cookies
 allow-all-cookies  = -crunch-all-cookies -session-cookies-only -filter{content-cookies}
 allow-popups       = -filter{all-popups} -filter{unsolicited-popups}
+block-as-image     = +block{Blocked image request.} +handle-as-image
-block-as-image     = -block
fragile     = -block -crunch-all-cookies -filter -fast-redirects -hide-referer -prevent-compression
shop        = -crunch-all-cookies allow-popups
myfilters   = +filter{html-annoyances} +filter{js-annoyances} +filter{all-popups}\
              +filter{webbugs} +filter{banners-by-size}
allow-ads   = -block -filter{banners-by-size} -filter{banners-by-link}
{ fragile }
http://127.0.0.10.*
http://localhost.*
# BING Add &adlt=strict
{+redirect{s@$@&adlt=strict@}}
.bing./.*[&?]q=
{-redirect}
.bing./.*&adlt=strict

# dailymotion.com 
# remplace http://www.dailymotion.com/family_filter?enable=false....
# par http://www.dailymotion.com/family_filter?enable=true...
{+redirect{s@enable=[^&]+@enable=true@}}
 .dailymotion.*/.*enable=(?!true)
              
EOF

$PRIVOXYrestart
setproxy
echo "</confprivoxy>"
}

unsetproxy () {
for user in $(listeusers) ; do	
	HOMEPCUSER=$(getent passwd "$user" | cut -d ':' -f6)
	if [  -f "$HOMEPCUSER"/.profile ] ; then
	test=$(grep -c "^### CTparental ###" "$HOMEPCUSER"/.profile )
		if [ "$test" -eq "1" ] ; then	 
		 $SED  2d "$HOMEPCUSER"/.profile
		 $SED  2d "$HOMEPCUSER"/.profile
		 $SED  2d "$HOMEPCUSER"/.profile
		 $SED  2d "$HOMEPCUSER"/.profile
		 $SED  2d "$HOMEPCUSER"/.profile
		 $SED  2d "$HOMEPCUSER"/.profile
		 $SED  2d "$HOMEPCUSER"/.profile
		fi
	unset test
	fi	
done
test=$(grep -c "^### CTparental ###" "$XSESSIONFILE" )
		if [ "$test" -eq "1" ] ; then	 
		 $SED  2d "$XSESSIONFILE"
		 $SED  2d "$XSESSIONFILE"
		 $SED  2d "$XSESSIONFILE"
		 $SED  2d "$XSESSIONFILE"
		 $SED  2d "$XSESSIONFILE"
		 $SED  2d "$XSESSIONFILE"
		 $SED  2d "$XSESSIONFILE"
		fi
unset test
}
setproxy () {
if [  -f "$XSESSIONFILE" ] ; then
test=$(grep -c "^### CTparental ###" "$XSESSIONFILE" )
		if [ "$test" -eq "0" ] ; then	 
		 $SED  2"i\### CTparental ###" "$XSESSIONFILE"
		 $SED  3"i\if  [ \$(groups \$(whoami) | grep -c -E \"( ctoff\$)|( ctoff )\") -eq 0 ];then" "$XSESSIONFILE"
		 $SED  4"i\  export https_proxy=http://127.0.0.1:$E2GUport" "$XSESSIONFILE"
		 $SED  5"i\  export HTTPS_PROXY=http://127.0.0.1:$E2GUport" "$XSESSIONFILE"
		 $SED  6"i\  export http_proxy=http://127.0.0.1:$E2GUport" "$XSESSIONFILE"
		 $SED  7"i\  export HTTP_PROXY=http://127.0.0.1:$E2GUport" "$XSESSIONFILE"
		 $SED  8"i\fi" "$XSESSIONFILE"
		fi
unset test
fi
for user in $(listeusers) ; do	
	HOMEPCUSER=$(getent passwd "$user" | cut -d ':' -f6)
	if [  -f "$HOMEPCUSER"/.profile ] ; then
	test=$(grep -c "^### CTparental ###" "$HOMEPCUSER"/.profile )
		if [ "$test" -eq "0" ] ; then	 
		 $SED  2"i\### CTparental ###" "$HOMEPCUSER"/.profile
		 $SED  3"i\if  [ \$(groups \$(whoami) | grep -c -E \"( ctoff\$)|( ctoff )\") -eq 0 ];then" "$HOMEPCUSER"/.profile
		 $SED  4"i\  export https_proxy=http://127.0.0.1:$E2GUport" "$HOMEPCUSER"/.profile
		 $SED  5"i\  export HTTPS_PROXY=http://127.0.0.1:$E2GUport" "$HOMEPCUSER"/.profile
		 $SED  6"i\  export http_proxy=http://127.0.0.1:$E2GUport" "$HOMEPCUSER"/.profile
		 $SED  7"i\  export HTTP_PROXY=http://127.0.0.1:$E2GUport" "$HOMEPCUSER"/.profile
		 $SED  8"i\fi" "$HOMEPCUSER"/.profile
		fi
	unset test
	fi
	
done
}

addadminhttpd() {
if [ ! -f "$PASSWORDFILEHTTPD" ]; then touch "$PASSWORDFILEHTTPD"; fi
USERADMINHTTPD=${1}
pass=${2}
hash="$(echo -n "$USERADMINHTTPD"":""$REALMADMINHTTPD"":""$pass" | md5sum | cut -b -32)"
ligne="$USERADMINHTTPD"":""$REALMADMINHTTPD"":""$hash"
#echo $ligne
$SED "/.*:$REALMADMINHTTPD.*/d" "$PASSWORDFILEHTTPD"
echo "$ligne" >> "$PASSWORDFILEHTTPD"
chown root:"$USERHTTPD" "$PASSWORDFILEHTTPD"
chmod 640 "$PASSWORDFILEHTTPD"
}

download() {
   rm -rf $tempDIR
   mkdir $tempDIR
   # on attend que la connection remonte suite au redemarage de networkmanager
   gettext 'Waiting to Connect to Server from Toulouse:'
   i=1
   while [ "$(ping -c 1 $BL_SERVER 2> /dev/null | grep -c "1 received"  )" -eq 0 ]
   do
   echo -n .
   sleep 1
   i=$(( i + 1 ))
   if [ $i -ge 40 ];then # si au bout de 40 secondes on a toujours pas de connection on considaire qu'il y a une erreur
		gettext 'The connection to the server of Toulouse is impossible.'
		set -e
		exit 1
   fi
   done
   echo
   gettext 'connection established:'
   
   wget -P $tempDIR http://$BL_SERVER/blacklists/download/blacklists.tar.gz 2>&1 | cat
   if [ ! $? -eq 0 ]; then
      gettext 'error when downloading, interrupted process'
      rm -rf $tempDIR
      set -e
      exit 1
   fi
   tar -xzf $tempDIR/blacklists.tar.gz -C $tempDIR
   if [ ! $? -eq 0 ]; then
      gettext 'archive extraction error , interrupted process'
      set -e
      exit 1
   fi
   rm -rf ${DIR_DNS_FILTER_AVAILABLE:?}/
   mkdir $DIR_DNS_FILTER_AVAILABLE
}
autoupdate() {
        LASTUPDATEDAY=$(grep LASTUPDATE= "$FILE_CONF" | cut -d"=" -f2)
        LASTUPDATEDAY=${LASTUPDATEDAY:=0}
        DIFFDAY=$(( THISDAYS - LASTUPDATEDAY ))
	if [ $DIFFDAY -ge $MAXDAYSFORUPDATE ] ; then
		download
		adapt
		catChoice
		dnsmasqon
                $SED "s?^LASTUPDATE.*?LASTUPDATE=$THISDAYS=$(date +%d-%m-%Y\ %T)?g" $FILE_CONF
		exit 0
	fi
}
autoupdateon() {
$SED "s?^AUTOUPDATE.*?AUTOUPDATE=ON?g" $FILE_CONF
echo "PATH=$PATH"  > /etc/cron.d/CTparental-autoupdate
echo "*/10 * * * * root $CHEMINCTPARENTLE -aup" >> /etc/cron.d/CTparental-autoupdate
$CRONrestart
}

autoupdateoff() {
$SED "s?^AUTOUPDATE.*?AUTOUPDATE=OFF?g" $FILE_CONF
rm -f /etc/cron.d/CTparental-autoupdate
$CRONrestart
}
adapt() {
echo adapt
date +%H:%M:%S
dnsmasqoff
$MFILEtmp
if [ ! -f $DNS_FILTER_OSSI ] ; then
	echo > $DNS_FILTER_OSSI
fi
if [ -d $tempDIR  ] ; then
	CATEGORIES_AVAILABLE="$tempDIR"/categories_available
	echo -n > $CATEGORIES_AVAILABLE
	echo -n > $WL_CATEGORIES_AVAILABLE
	echo -n > $BL_CATEGORIES_AVAILABLE
	if [ ! -f $DIR_DNS_FILTER_AVAILABLE/ossi.conf ] ; then
		echo > $DIR_DNS_FILTER_AVAILABLE/ossi.conf
	fi
	gettext 'blacklist and WhiteList , migration process. Please wait :'" "
	cd "$tempDIR"/blacklists
	for categorie in *
	do
		if [ -d "$categorie" ] ; then
			if [ ! -L "$categorie" ] ; then 
				echo "$categorie" >> $CATEGORIES_AVAILABLE
				echo -n "."
				cp -f "$tempDIR"/blacklists/"$categorie"/domains "$FILE_tmp"
				$SED -r '/([0-9]{1,3}\.){3}[0-9]{1,3}/d' "$FILE_tmp"
				$SED "/[äâëêïîöôüû]/d" "$FILE_tmp"
				$SED "/^#.*/d" "$FILE_tmp"
				$SED "/^$/d" "$FILE_tmp"
				$SED "s/\.\{2,10\}/\./g" "$FILE_tmp"
				if [ -e "$tempDIR"/blacklists/"$categorie"/usage ] ; then
					if [ "$(grep -c "white" "$tempDIR"/blacklists/"$categorie"/usage)" -ge 1 ] ;then
						echo "$categorie" >> $WL_CATEGORIES_AVAILABLE
						$SED "s?.*?server=/&/#?g" "$FILE_tmp"  # Mise en forme dnsmasq des listes blanches
						mv "$FILE_tmp" "$DIR_DNS_FILTER_AVAILABLE"/"$categorie".conf
					else
						echo "$categorie" >> $BL_CATEGORIES_AVAILABLE
						$SED "s?.*?address=/&/$PRIVATE_IP?g" "$FILE_tmp"  # Mise en forme dnsmasq des listes noires
						mv "$FILE_tmp" "$DIR_DNS_FILTER_AVAILABLE"/"$categorie".conf  	
					fi				
				else
					echo "$categorie" >> $BL_CATEGORIES_AVAILABLE
					$SED "s?.*?address=/&/$PRIVATE_IP?g" "$FILE_tmp"  # Mise en forme dnsmasq des listes noires
					mv "$FILE_tmp" "$DIR_DNS_FILTER_AVAILABLE"/"$categorie".conf  	
				fi
			fi
		fi
	done

else
	mkdir   $tempDIR
	echo -n "."
	# suppression des @IP, de caractères acccentués et des lignes commentées ou vides
	cp -f $DNS_FILTER_OSSI "$FILE_tmp"
	$SED -r '/([0-9]{1,3}\.){3}[0-9]{1,3}/d' "$FILE_tmp"
	$SED "/[äâëêïîöôüû]/d" "$FILE_tmp" 
	$SED "/^#.*/d" "$FILE_tmp" 
	$SED "/^$/d" "$FILE_tmp" 
	$SED "s/\.\{2,10\}/\./g" "$FILE_tmp" # supprime les suite de "." exemple: address=/fucking-big-tits..com/127.0.0.10 devient address=/fucking-big-tits.com/127.0.0.10
	$SED "s?.*?address=/&/$PRIVATE_IP?g" "$FILE_tmp"  # Mise en forme dnsmasq
	mv "$FILE_tmp" "$DIR_DNS_FILTER_AVAILABLE"/ossi.conf
fi     
echo
$UMFILEtmp
cd "$(dirname "$(readlink -f "$0")")"
rm -rf $tempDIR
date +%H:%M:%S
}
catChoice() {
echo "<catChoice>"
rm -rf ${DIR_DNS_BLACKLIST_ENABLED:?}/
mkdir $DIR_DNS_BLACKLIST_ENABLED
rm -rf  ${DIR_DNS_WHITELIST_ENABLED:?}/
mkdir  $DIR_DNS_WHITELIST_ENABLED  
while read CATEGORIE
do
	if [ "$(grep -c "$CATEGORIE" "$BL_CATEGORIES_AVAILABLE")" -ge "1" ] ; then
		cp $DIR_DNS_FILTER_AVAILABLE/"$CATEGORIE".conf $DIR_DNS_BLACKLIST_ENABLED/
	else
		cp $DIR_DNS_FILTER_AVAILABLE/"$CATEGORIE".conf $DIR_DNS_WHITELIST_ENABLED/
	fi     
done < $CATEGORIES_ENABLED
cp $DIR_DNS_FILTER_AVAILABLE/ossi.conf $DIR_DNS_BLACKLIST_ENABLED/
echo "</catChoice>"
reabdomaine
}

reabdomaine () {
echo "<reabdomaine>"
date +%H:%M:%S
$MFILEtmp
if [ ! -f $DREAB ] ; then
cat << EOF > $DREAB
EOF
fi
if [ ! -f $DIR_DNS_BLACKLIST_ENABLED/ossi.conf ] ; then
	echo > $DIR_DNS_BLACKLIST_ENABLED/ossi.conf
fi
echo
gettext 'Application whitelisting (restored area):'
while read CATEGORIE
do 
	if [ "$(grep -c "$CATEGORIE" "$BL_CATEGORIES_AVAILABLE" )" -ge "1" ] ; then
		echo -n "."
		while read DOMAINE
		do
		    cp -f $DIR_DNS_BLACKLIST_ENABLED/"$CATEGORIE".conf "$FILE_tmp"
		    $SED "/$DOMAINE/d" "$FILE_tmp"
            cp -f "$FILE_tmp" $DIR_DNS_BLACKLIST_ENABLED/"$CATEGORIE".conf
		done < $DREAB
		
		for DOMAINE in $DOMAINEDEPOTS
		do
		    cp -f $DIR_DNS_BLACKLIST_ENABLED/"$CATEGORIE".conf "$FILE_tmp"
		    $SED "/$DOMAINE/d" "$FILE_tmp"
            cp -f "$FILE_tmp" $DIR_DNS_BLACKLIST_ENABLED/"$CATEGORIE".conf
		done
    fi
done < $CATEGORIES_ENABLED

{ 
echo 'localhost' 
echo '127.0.0.1' 
echo "$BL_SERVER" 
for domain in $DOMAINEDEPOTS 
do 
	echo "$domain" 
done 
cat < "$DREAB" | sed -e"s/^\.//g" | sed -e"s/^www.//g" 
}  > "$E2GUXSITELIST"

echo -n "."
cat < "$DREAB" | sed -e "s? ??g" | sed -e "s?.*?server=/&/#?g" >  "$DIR_DNS_WHITELIST_ENABLED"/whiteliste.ossi.conf
echo
$UMFILEtmp
rm -f "$FILE_tmp"
date +%H:%M:%S


{


## on force a passer par forcesafesearch.google.com de maninière transparente
forcesafesearchgoogle=$(host -ta forcesafesearch.google.com|cut -d" " -f4)	# retrieve forcesafesearch.google.com ip
if [ "$(cat < $FILE_CONF | grep -c "^SAFEGOOGLE=ON" )" -eq 1 ];then
	echo "# forcesafesearch redirect server for google" 
	for subdomaingoogle in $(wget http://www.google.com/supported_domains -O - 2> /dev/null )  # pour chaque sous domain de google
	do 
	echo "address=/www$subdomaingoogle/$forcesafesearchgoogle" 	
	done
fi
if [ "$(cat < $FILE_CONF | grep -c "^SAFEYOUTUBE=ON" )" -eq 1 ];then
	echo "address=/www.youtube.com/$forcesafesearchgoogle" 
fi
if [ "$(cat < $FILE_CONF | grep -c "^SAFEDUCK=ON" )" -eq 1 ];then
	echo "# on force a passer par safe.duckduckgo.com" 
	for ipsafeduckduckgo in $(host -ta safe.duckduckgo.com|cut -d" " -f4 | grep -v alias)
	do
		echo "address=/safe.duckduckgo.com/$ipsafeduckduckgo" 
	done
	## les requette sur http(s)://duckduckgo.com sont rediriger vers lighttpd qui les renvois vers safe.duckduckgo.com
	echo "address=/duckduckgo.com/127.0.0.1" 
fi

if [ "$(cat < $FILE_CONF | grep -c "^SAFEBING=ON" )" -eq 1 ];then
	## on attribut une seul ip pour les recherches sur bing de manière a pouvoir bloquer sont acces en https dans iptables.
	## et ainci forcer le safesearch via privoxy.
	## tous les sous domaines type fr.bing.com ... retourneront l'ip de www.bing.com
	echo "address=/.bing.com/$(host -ta bing.com|cut -d" " -f4)"
fi
## on force a passer par search.yahoo.com pour redirection url par lighttpd
#ipsearchyahoo=`host -ta search.yahoo.com|cut -d" " -f4 | grep [0-9]`
#echo "address=/safe.search.yahoo.com/$ipsearchyahoo" >> $DIR_DNS_BLACKLIST_ENABLED/forcesafesearch.conf
#echo "address=/search.yahoo.com/127.0.0.1" >> $DIR_DNS_BLACKLIST_ENABLED/forcesafesearch.conf

# on bloque les moteurs de recherche pas asser sur
echo "address=/search.yahoo.com/127.0.0.10"
} > $DIR_DNS_BLACKLIST_ENABLED/forcesafesearch.conf


echo "</reabdomaine>"

}

dnsmasqon () {
echo "<dnsmasqon>"
	
if [ "$(grep -c "$(sed -n "1 p" $CATEGORIES_ENABLED)" "$BL_CATEGORIES_AVAILABLE" )" -ge "1" ] ; then
$SED "s?^DNSMASQ.*?DNSMASQ=BLACK?g" $FILE_CONF

cat << EOF > $DNSMASQCONF 
# Configuration file for "dnsmasq with blackhole"
# Inclusion de la blacklist <domains> de Toulouse dans la configuration
conf-dir=$DIR_DNS_BLACKLIST_ENABLED
# conf-file=$DIR_DEST_ETC/alcasar-dns-name   # zone de definition de noms DNS locaux
interface=lo
listen-address=127.0.0.1
no-dhcp-interface=$interface_WAN
bind-interfaces
cache-size=1024
domain-needed
expand-hosts
bogus-priv
port=54
server=$DNS1
server=$DNS2  
EOF

resolvconffixon # redemare dnsmasq en prenent en compte la présence ou non de resolvconf.
$E2GUARDIANrestart
$PRIVOXYrestart
else
  dnsmasqwhitelistonly
fi
echo "</dnsmasqon>"
}
dnsmasqoff () {
echo "<dnsmasqoff>"
$SED "s?^DNSMASQ.*?DNSMASQ=OFF?g" $FILE_CONF
resolvconffixoff
$E2GUARDIANrestart
$PRIVOXYrestart
echo "</dnsmasqoff>"
}

ipglobal () {
    ### BLOQUE TOUT PAR DEFAUT (si aucune règle n'est définie par la suite) ###
    $IPTABLES -P INPUT DROP
    $IPTABLES -P OUTPUT DROP
    $IPTABLES -P FORWARD DROP
    # TCP Syn Flood
    $IPTABLES -A INPUT -i "$interface_WAN" -p tcp --syn -m limit --limit 3/s -j ACCEPT
    # UDP Syn Flood
    $IPTABLES -A INPUT -i "$interface_WAN" -p udp -m limit --limit 10/s -j ACCEPT

	### IP indésirables
 
    if [ -e "$FILEIPBLACKLIST" ] ;  then
	   while read ligne
	   do
		ipdrop=$(echo "$ligne" | cut -d " " -f1)  
	    if [ "$( ipMaskValide "$ipdrop" )" -eq 1 ] ;then
			$IPTABLES -I INPUT  -s "$ipdrop" -j DROP
			$IPTABLES -I OUTPUT  -d "$ipdrop" -j DROP
		fi
       done < $FILEIPBLACKLIST
    else
	    echo >  $FILEIPBLACKLIST
	    chown root:root  $FILEIPBLACKLIST
	    chmod 750  $FILEIPBLACKLIST
    fi
   
    ### ACCEPT ALL interface loopback ###
    $IPTABLES -A INPUT  -i lo -j ACCEPT
    $IPTABLES -A OUTPUT -o lo -j ACCEPT
    ### accepte en entrée les connexions déjà établies (en gros cela permet d'accepter 
    ### les connexions initiées par sont propre PC)
    $IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
     
    ### DHCP
    $IPTABLES -A OUTPUT -o "$interface_WAN" -p udp --sport 68 --dport 67 -j ACCEPT
    $IPTABLES -A INPUT -i "$interface_WAN" -p udp --sport 67 --dport 68 -j ACCEPT
 
    ### DNS indispensable pour naviguer facilement sur le web ###
    $IPTABLES -A OUTPUT -p tcp -m tcp --dport 53 -j ACCEPT
    $IPTABLES -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
    $IPTABLES -A OUTPUT -d 127.0.0.1 -p tcp -m tcp --dport 54 -j ACCEPT
    $IPTABLES -A OUTPUT -d 127.0.0.1 -p udp -m udp --dport 54 -j ACCEPT
 
    ### HTTP navigation internet non sécurisée ###
    $IPTABLES -A OUTPUT -p tcp -m tcp --dport 80 -j ACCEPT
    
    ### HTTPS pour le site des banques .... ###
    $IPTABLES -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
    
    ### ping ... autorise à "pinger" un ordinateur distant ###
    $IPTABLES -A OUTPUT -p icmp -j ACCEPT
    
    ### clientNTP ... syncro à un serveur de temps ###
    $IPTABLES -A OUTPUT -p udp -m udp --dport 123 -j ACCEPT
    
    # On autorise les requêtes FTP 
	modprobe ip_conntrack_ftp
	$IPTABLES -A OUTPUT -p tcp --dport 21 -j ACCEPT
	$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	
	if [ -e "$FILEIPTABLES" ] ;  then
		source "$FILEIPTABLES"
    else
	    initfileiptables
	    source "$FILEIPTABLES"
    fi
### LOG ### Log tout ce qui qui n'est pas accepté par une règles précédente
$IPTABLES -A OUTPUT -j LOG  --log-prefix "iptables: "
$IPTABLES -A INPUT -j LOG   --log-prefix "iptables: "
$IPTABLES -A FORWARD -j LOG  --log-prefix "iptables: "


}
initfileiptables () {

cat << EOF >  $FILEIPTABLES
## on autorise tous le trafic sortant à destination de notre lan (PC imprimante de la maison)
\$IPTABLES -A OUTPUT -d \$reseau_box -j ACCEPT
## on acepte tous le trafic entrant en provenence de notre lan (PC imprimante de la maison)
\$IPTABLES -A INPUT -s \$reseau_box -j ACCEPT 

### smtp + pop ssl thunderbird ...  ####
\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 993 -j ACCEPT		# imap/ssl
\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 995 -j ACCEPT		# pop/ssl
\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 465 -j ACCEPT     # smtp/ssl

## Client Steam voir infos https://support.steampowered.com/kb_article.php?ref=8571-GLVN-8711&l=french
#\$IPTABLES -A OUTPUT -p udp -m udp --dport 27000:27015 -j ACCEPT  		# (trafic pour le client jeu)
#\$IPTABLES -A OUTPUT -p udp -m udp --dport 27015:27030 -j ACCEPT  		# (en général pour les matchs et HLTV)
#\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 27014:27050 -j ACCEPT  		# (pour les téléchargements sur Steam)
#\$IPTABLES -A INPUT  -s \$reseau_box -p udp -m multiport --sports 27031,27036 -j ACCEPT 				# (entrant, pour le Streaming local)
#\$IPTABLES -A INPUT  -s \$reseau_box -p tcp -m multiport --sports 27036,27037 -j ACCEPT 				# (entrant, pour le Streaming local)
#\$IPTABLES -A OUTPUT -p udp -m udp --dport 4380 -j ACCEPT 			# chat audio Steam


## Serveurs dédiés ou Serveurs d'écoute
#\$IPTABLES -A INPUT  -p tcp --dport 27015 -j ACCEPT 					# (port Rcon SRCDS)

##Steamworks P2P et chat audio Steam
#\$IPTABLES -A OUTPUT -p udp -m udp --dport udp 3478 -j ACCEPT 	
#\$IPTABLES -A OUTPUT -p udp -m udp --dport udp 4379 -j ACCEPT 	
#\$IPTABLES -A OUTPUT -p udp -m udp --dport udp 4380 -j ACCEPT 	
 
## Steam Ports supplémentaires pour for Call of Duty: Modern Warfare 2 Multijoueur
#\$IPTABLES -A OUTPUT -p udp -m udp --dport udp 1500 -j ACCEPT 	
#\$IPTABLES -A OUTPUT -p udp -m udp --dport udp 3005 -j ACCEPT 	
#\$IPTABLES -A OUTPUT -p udp -m udp --dport udp 3101 -j ACCEPT 	
#\$IPTABLES -A OUTPUT -p udp -m udp --dport udp 28960 -j ACCEPT

# Ping Externe
# \$IPTABLES -A INPUT -i \$interface_WAN -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
# \$IPTABLES -A INPUT -i \$interface_WAN -p icmp --icmp-type echo-reply -m limit --limit 1/s -j ACCEPT

### cups serveur , impriment partager sous cups
#\$IPTABLES -A OUTPUT -d \$ip_broadcast -p udp -m udp --sport 631 --dport 631 -j ACCEPT # diffusion des imprimantes partager sur le réseaux
#\$IPTABLES -A INPUT -s \$reseau_box -m state --state NEW -p TCP --dport 631 -j ACCEPT
#\$IPTABLES -I INPUT -s \$ipbox -m state --state NEW -p TCP --dport 631 -j DROP # drop les requette provenent de la passerelle

### emesene,pidgin,amsn...  ####
#\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 1863 -j ACCEPT     
#\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 6891:6900 -j ACCEPT # pour transfert de fichiers , webcam
#\$IPTABLES -A OUTPUT -p udp -m udp --dport 6891:6900 -j ACCEPT # pour transfert de fichiers , webcam

###  smtp + pop thunderbird ...  ###
#\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 25 -j ACCEPT
#\$IPTABLES -A OUTPUT -p tcp -m tcp --dport 110 -j ACCEPT
### client-transmission
# ouvre beaucoup de ports
#\$IPTABLES -A OUTPUT -p udp -m udp --sport 51413 --dport 1023:65535  -j ACCEPT
#\$IPTABLES -A OUTPUT -p tcp -m tcp --sport 30000:65535 --dport 1023:65535  -j ACCEPT
###Ryzom
#srvupdateRtzom=178.33.44.72
#srvRyzom1=176.31.229.93
#\$IPTABLES -A OUTPUT  -d \$srvupdateRtzom -p tcp --dport 873 -j ACCEPT
#\$IPTABLES -A OUTPUT  -d \$srvRyzom1 -p tcp --dport 43434 -j ACCEPT
#\$IPTABLES -A OUTPUT  -d \$srvRyzom1 -p tcp --dport 50000 -j ACCEPT
#\$IPTABLES -A OUTPUT  -d \$srvRyzom1 -p tcp --dport 40916 -j ACCEPT
#\$IPTABLES -A OUTPUT  -d \$srvRyzom1 -p udp --dport 47851:47860 -j ACCEPT
#\$IPTABLES -A OUTPUT  -d \$srvRyzom1 -p tcp --dport 47851:47860 -j ACCEPT
### Regnum Online
#\$IPTABLES -A OUTPUT  -d 91.123.197.131 -p tcp --dport 47300 -j ACCEPT # autentification
#\$IPTABLES -A OUTPUT  -d 91.123.197.142 -p tcp --dport 48000:48002  -j ACCEPT # nemon
### NeverWinter Nights 1
#\$IPTABLES -A OUTPUT  -p udp --dport 5120:5121 -j ACCEPT
#\$IPTABLES -I OUTPUT  -d 204.50.199.9 -j DROP # nwmaster.bioware.com permet d'éviter le temps d'attente avant l'ouverture du multijoueur " >>  $FILEIPTABLES
### LandesEternelles
#\$IPTABLES -A OUTPUT  -d 62.93.225.45 -p tcp --dport 3000 -j ACCEPT
### Batel for Wesnoth
#14998 pour version stable.
#14999 pour version stable précédente.
#15000 pour version de développement.
#15001 télécharger addons
#\$IPTABLES -A OUTPUT  -d 65.18.193.12 -p tcp --sport 1023:65535 --dport 14998:15001 -j ACCEPT
#\$IPTABLES -A INPUT   -p tcp --sport 1023:65535 --dport 15000 -j ACCEPT
EOF
	
chown root:root  $FILEIPTABLES
chmod 750  $FILEIPTABLES
}

iptablesreload () {
   echo "<iptablesreload>"
   ### SUPPRESSION de TOUTES LES ANCIENNES TABLES (OUVRE TOUT!!) ###
   $IPTABLES -F
   $IPTABLES -X
   $IPTABLES -t nat -D OUTPUT -j ctparental 2> /bin/null
   $IPTABLES -t nat -F ctparental  2> /bin/null
   $IPTABLES -t nat -X ctparental  2> /bin/null
   $IPTABLES -P INPUT ACCEPT
   $IPTABLES -P OUTPUT ACCEPT
   $IPTABLES -P FORWARD ACCEPT
   if [ ! "$FILTRAGEISOFF" -eq 1 ];then
	 $IPTABLES -t nat -N ctparental
     $IPTABLES -t nat -A OUTPUT -j ctparental
      
      # Force privoxy a utiliser dnsmasq sur le port 54
	  $IPTABLES -t nat -A ctparental -m owner --uid-owner "$PROXYuser" -p udp --dport 53 -j DNAT --to 127.0.0.1:54
	  if [ "$(cat < $FILE_CONF | grep -c "^SAFEBING=ON" )" -eq 1 ];then
		  # on interdit l'accès a bing en https .
		  ipbing=$(cat < $DIR_DNS_BLACKLIST_ENABLED/forcesafesearch.conf | grep "address=/.bing.com/" | cut -d "/" -f3)
		  $IPTABLES -A OUTPUT -d "$ipbing" -m owner --uid-owner "$PROXYuser" -p tcp --dport 443 -j REJECT # on rejet l'acces https a bing
	  fi
	  for ipdailymotion in $(host -ta dailymotion.com|cut -d" " -f4)  
	  do 
		$IPTABLES -A OUTPUT -d "$ipdailymotion" -m owner --uid-owner "$PROXYuser" -p tcp --dport 443 -j REJECT # on rejet l'acces https a dailymotion.com
	  done

      for user in $(listeusers) ; do
      if  [ "$(groups "$user" | grep -c -E "( ctoff$)|( ctoff )" )" -eq 0 ];then
         #on rediriges les requet DNS des usagers filtrés sur dnsmasq
         $IPTABLES -t nat -A ctparental -m owner --uid-owner "$user" -p tcp --dport 53 -j DNAT --to 127.0.0.1:54 
         $IPTABLES -t nat -A ctparental -m owner --uid-owner "$user" -p udp --dport 53 -j DNAT --to 127.0.0.1:54
         #force passage par dansguardian pour les utilisateurs filtrés 
		 $IPTABLES -t nat -A ctparental ! -d 127.0.0.1/8 -m owner --uid-owner "$user" -p tcp --dport 80 -j DNAT --to 127.0.0.1:"$E2GUport"
		 $IPTABLES -t nat -A ctparental ! -d 127.0.0.1/8 -m owner --uid-owner "$user" -p tcp --dport "$PROXYport" -j DNAT --to 127.0.0.1:"$E2GUport"
		 #$IPTABLES -t nat -A ctparental -m owner --uid-owner "$user" -p tcp --dport 443 -j DNAT --to 127.0.0.1:$E2GUport  # proxy https transparent n'est pas possible avec privoxy
		 $IPTABLES -A OUTPUT ! -d 127.0.0.1/8 -m owner --uid-owner "$user" -p tcp --dport 443 -j REJECT # on interdit l'aces https sans passer par le proxy pour les utilisateur filtré.	
      fi
      done
   fi
   if [ -e "$FILEIPTIMEWEB" ] ;  then
		source "$FILEIPTIMEWEB"
   fi
	
   if [ "$(cat < $FILE_CONF | grep -c IPRULES=ON )" -eq 1 ];then
    ipglobal
   fi

# Save configuration so that it survives a reboot
   $IPTABLESsave
   
updatecauser
setproxy
echo "</iptablesreload>"
}
updatecauser () {
echo "<updatecauser>"
for user in $(listeusers) ; do	
	HOMEPCUSER=$(getent passwd "$user" | cut -d ':' -f6)
	if [ -d "$HOMEPCUSER" ] ;then
			#on install le certificat dans tous les prifile firefoxe utilisateur existant 
		profileliste=$(cat < "$HOMEPCUSER"/.mozilla/firefox/profiles.ini | grep Path= | cut -d"=" -f2)
		for profilefirefox in $profileliste ; do
			# on supprime tous les anciens certificats
			while true
			do
				certutil -D -d "$HOMEPCUSER"/.mozilla/firefox/"$profilefirefox"/ -n"CActparental - ctparental" 2&> /dev/null
				if [ ! $? -eq 0 ];then 
					break
				fi
			done
			# on ajoute le nouveau certificat
			certutil -A -d "$HOMEPCUSER"/.mozilla/firefox/"$profilefirefox"/ -i "$DIRHTML"/cactparental.crt -n"CActparental - ctparental" -t "CT,c,c"		
		done
	fi
done
echo "</updatecauser>"
}
iptablesoff () {

   $IPTABLES -F
   $IPTABLES -X
   $IPTABLES -P INPUT ACCEPT
   $IPTABLES -P OUTPUT ACCEPT
   $IPTABLES -P FORWARD ACCEPT
   $IPTABLES -t nat -D OUTPUT -j ctparental  2> /bin/null
   $IPTABLES -t nat -F ctparental  2> /bin/null
   $IPTABLES -t nat -X ctparental  2> /bin/null
   $IPTABLESsave
   unsetproxy
}
dnsmasqwhitelistonly  () {
$SED "s?^DNSMASQ.*?DNSMASQ=WHITE?g" $FILE_CONF
cat << EOF > $DNSMASQCONF
# Configuration file for "dnsmasq with blackhole"
# Inclusion de la blacklist <domains> de Toulouse dans la configuration
conf-dir=$DIR_DNS_WHITELIST_ENABLED
# conf-file=$DIR_DEST_ETC/alcasar-dns-name   # zone de definition de noms DNS locaux
interface=lo
listen-address=127.0.0.1
no-dhcp-interface=$interface_WAN
bind-interfaces
cache-size=1024
domain-needed
expand-hosts
bogus-priv
port=54
server=$DNS1
server=$DNS2 
address=/localhost/127.0.0.1
address=/#/$PRIVATE_IP #redirige vers $PRIVATE_IP pour tout ce qui n'a pas été resolu dans les listes blanches
EOF

$DNSMASQrestart
$E2GUARDIANrestart
$PRIVOXYrestart
}


FoncHTTPDCONF () {
echo "<FoncHTTPDCONF>"
$LIGHTTPDstop
rm -rf "${DIRHTML:?}"/*
mkdir "$DIRHTML" 2> /dev/null
mkdir -p "$DIRadminHTML"
mkdir -p "$DIRHTML"
if [ ! -z "$DIRhtmlPersonaliser" ];then
   cp -rf "$DIRhtmlPersonaliser"/* "$DIRHTML"
else
cp -rf /usr/local/share/CTparental/www/locale "$DIRHTML"
cp -rf /usr/local/share/CTparental/www/CTparental/* "$DIRHTML"
fi
cp -rf /usr/local/share/CTparental/www/locale "$DIRadminHTML"
cp -rf /usr/local/share/CTparental/www/CTadmin/* "$DIRadminHTML"

USERHTTPD=$(cat < /etc/passwd | grep /var/www | cut -d":" -f1)
GROUPHTTPD=$(cat < /etc/group | grep "$USERHTTPD" | cut -d":" -f1)
chmod 644 "$FILE_CONF"
chown root:"$GROUPHTTPD" "$FILE_CONF"
cat << EOF > "$MAINCONFHTTPD"
server.modules = (
"mod_access",
"mod_alias",
"mod_redirect",
"mod_auth",	#pour interface admin
"mod_fastcgi",  #pour interface admin (activation du php)
)
auth.debug                 = 0
auth.backend               = "htdigest" 
auth.backend.htdigest.userfile = "$PASSWORDFILEHTTPD" 

server.document-root = "/var/www"
server.upload-dirs = ( "/var/cache/lighttpd/uploads" )
#server.errorlog = "/var/log/lighttpd/error.log" # ne pas decommenter sur les eeepc qui on /var/log  en tmpfs
server.pid-file = "$LIGHTTPpidfile"
server.username = "$USERHTTPD"
server.groupname = "$GROUPHTTPD"
server.port = 80
server.bind = "127.0.0.1"


index-file.names = ( "index.php", "index.html" )
url.access-deny = ( "~", ".inc" )
static-file.exclude-extensions = (".php", ".pl", ".fcgi" )

server.tag = ""

include_shell "/usr/share/lighttpd/create-mime.assign.pl"
include_shell "/usr/share/lighttpd/include-conf-enabled.pl"
EOF

mkdir -p /usr/share/lighttpd/

if [ ! -f /usr/share/lighttpd/create-mime.assign.pl ];then
cat << EOF > /usr/share/lighttpd/create-mime.assign.pl
#!/usr/bin/perl -w
use strict;
open MIMETYPES, "/etc/mime.types" or exit;
print "mimetype.assign = (\n";
my %extensions;
while(<MIMETYPES>) {
  chomp;
  s/\#.*//;
  next if /^\w*$/;
  if(/^([a-z0-9\/+-.]+)\s+((?:[a-z0-9.+-]+[ ]?)+)$/) {
    foreach(split / /, \$2) {
      # mime.types can have same extension for different
      # mime types
      next if \$extensions{\$_};
      \$extensions{\$_} = 1;
      print "\".\$_\" => \"\$1\",\n";
    }
  }
}
print ")\n";
EOF
chmod +x /usr/share/lighttpd/create-mime.assign.pl
fi


if [ ! -f /usr/share/lighttpd/include-conf-enabled.pl ];then
cat << EOF > /usr/share/lighttpd/include-conf-enabled.pl
#!/usr/bin/perl -wl

use strict;
use File::Glob ':glob';

my \$confdir = shift || "/etc/lighttpd/";
my \$enabled = "conf-enabled/*.conf";

chdir(\$confdir);
my @files = bsd_glob(\$enabled);

for my \$file (@files)
{
        print "include \"\$file\"";
}
EOF
chmod +x /usr/share/lighttpd/include-conf-enabled.pl 

fi

mkdir -p "$DIRCONFENABLEDHTTPD"


if [ $nomanuel -eq 0 ]; then  
	configloginpassword
else

	## variable récupérer par éritage du script DEBIAN/postinst
	debconfloginhttp=${debconfloginhttp:="admin"}
	debconfpassword=${debconfpassword:="admin"}
	addadminhttpd "$debconfloginhttp" "$debconfpassword"
	unset debconfpassword
	unset debconfloginhttp
	
fi

mkdir /run/lighttpd/ 2> /dev/null
chmod 770 /run/lighttpd/
chown root:"$GROUPHTTPD" /run/lighttpd/
cat << EOF > "$CTPARENTALCONFHTTPD"

fastcgi.server = (
    ".php" => (
      "localhost" => ( 
        "bin-path" => "/usr/bin/php-cgi",
        "socket" => "/run/lighttpd/php-fastcgi.sock",
        "max-procs" => 4, # default value
        "bin-environment" => (
          "PHP_FCGI_CHILDREN" => "1", # default value
        ),
        "broken-scriptfilename" => "enable"
      ))
)
  fastcgi.map-extensions     = ( ".php3" => ".php",
                               ".php4" => ".php",
                               ".php5" => ".php",
                               ".phps" => ".php",
                               ".phtml" => ".php" )

\$HTTP["url"] =~ ".*CTadmin.*" {
  auth.require = ( "" =>
                   (
                     "method"  => "digest",
                     "realm"   => "$REALMADMINHTTPD",
                     "require" => "user=$USERADMINHTTPD" 
                   )
                 )

}


\$HTTP["host"] =~ "search.yahoo.com" {
	\$SERVER["socket"] == ":443" {
	ssl.engine = "enable"
	ssl.pemfile = "$PEMSRVDIR/search.yahoo.com.pem" 
	server.document-root = "$DIRHTML"
	server.errorfile-prefix = "$DIRHTML/err" 
	}
}

\$HTTP["host"] =~ "localhost" {
	\$SERVER["socket"] == ":443" {
	ssl.engine = "enable"
	ssl.pemfile = "$PEMSRVDIR/localhost.pem" 	
	}
}
\$HTTP["host"] =~ "duckduckgo.com" {
	\$SERVER["socket"] == ":443" {
	ssl.engine = "enable"
	ssl.pemfile = "$PEMSRVDIR/duckduckgo.pem" 
	url.redirect  = (".*" => "https://safe.duckduckgo.com\$0" )
	}
	\$SERVER["socket"] == "127.0.0.1:80" {
	url.redirect  = (".*" => "https://safe.duckduckgo.com\$0" )
	}
}

\$SERVER["socket"] == "$PRIVATE_IP:80" {
server.document-root = "$DIRHTML"
server.error-handler-404 ="err404.php"
}

EOF
if [ -e "$DIRHTML/index.php" ] ;  then
	ln -s "$DIRHTML"/index.php "$DIRHTML"/err404.php
else
	if [ -e "$DIRHTML/index.html" ] ;  then
		ln -s  "$DIRHTML"/index.html "$DIRHTML"/err404.html
	fi
	$SED "s?^server.error-handler-404 =.*?server.error-handler-404 =\"err404.html\"?g" "$CTPARENTALCONFHTTPD"
fi


chown root:"$GROUPHTTPD" "$DREAB"
chmod 660 "$DREAB"
chown root:"$GROUPHTTPD" "$DNS_FILTER_OSSI"
chmod 660 "$DNS_FILTER_OSSI"
chown root:"$GROUPHTTPD" "$CATEGORIES_ENABLED"
chmod 660 "$CATEGORIES_ENABLED"
chmod 660 /etc/sudoers
chown root:"$GROUPHTTPD" "${DIRE2G}lists/bannedextensionlist"
chmod 664 "${DIRE2G}lists/bannedextensionlist"
chown root:"$GROUPHTTPD" "${DIRE2G}lists/bannedmimetypelist"
chmod 664 "${DIRE2G}lists/bannedmimetypelist"
chown root:"$GROUPHTTPD" "${DIRE2G}lists/bannedsitelist"
chmod 664 "${DIRE2G}lists/bannedsitelist"

if [ "$(grep -c Defaults:"$USERHTTPD" /etc/sudoers )" -ge "1" ] ; then
    $SED "s?^Defaults:$USERHTTPD.*requiretty.*?Defaults:$USERHTTPD     \!requiretty?g" /etc/sudoers
else
    echo "Defaults:$USERHTTPD     !requiretty" >> /etc/sudoers
fi

if [ "$(grep -c "$USERHTTPD"" ALL=" /etc/sudoers )" -ge "1" ] ; then
    $SED "s?^$USERHTTPD.*?$USERHTTPD ALL=(ALL) NOPASSWD:/usr/local/bin/CTparental.sh -dgreload,/usr/local/bin/CTparental.sh -gctalist,/usr/local/bin/CTparental.sh -gctulist,/usr/local/bin/CTparental.sh -gcton,/usr/local/bin/CTparental.sh -gctoff,/usr/local/bin/CTparental.sh -tlu,/usr/local/bin/CTparental.sh -trf,/usr/local/bin/CTparental.sh -dble,/usr/local/bin/CTparental.sh -ubl,/usr/local/bin/CTparental.sh -dl,/usr/local/bin/CTparental.sh -on,/usr/local/bin/CTparental.sh -off,/usr/local/bin/CTparental.sh -aupon,/usr/local/bin/CTparental.sh -aupoff?g" /etc/sudoers
else
    echo "$USERHTTPD ALL=(ALL) NOPASSWD:/usr/local/bin/CTparental.sh -dgreload,/usr/local/bin/CTparental.sh -gctalist,/usr/local/bin/CTparental.sh -gctulist,/usr/local/bin/CTparental.sh -gcton,/usr/local/bin/CTparental.sh -gctoff,/usr/local/bin/CTparental.sh -tlu,/usr/local/bin/CTparental.sh -trf,/usr/local/bin/CTparental.sh -dble,/usr/local/bin/CTparental.sh -ubl,/usr/local/bin/CTparental.sh -dl,/usr/local/bin/CTparental.sh -on,/usr/local/bin/CTparental.sh -off,/usr/local/bin/CTparental.sh -aupon,/usr/local/bin/CTparental.sh -aupoff" >> /etc/sudoers
fi
	
unset sudotest
    
chmod 440 /etc/sudoers
if [ ! -f $FILE_HCONF ] ; then 
	echo > $FILE_HCONF 
fi
chown root:"$GROUPHTTPD" "$FILE_HCONF"
chmod 660 "$FILE_HCONF"
if [ -f "$FILE_GCTOFFCONF" ] ; then 
	chown root:"$GROUPHTTPD" "$FILE_GCTOFFCONF"
	chmod 660 "$FILE_GCTOFFCONF"
fi

if [ ! -f "$FILE_HCOMPT" ] ; then
	echo "date=$(date +%D)" > "$FILE_HCOMPT"
fi
chown root:"$GROUPHTTPD" "$FILE_HCOMPT"
chmod 660 "$FILE_HCOMPT"

chown -R root:"$GROUPHTTPD" "$DIRHTML"
chown -R root:"$GROUPHTTPD" "$DIRadminHTML"
CActparental
$LIGHTTPDstart
test=$?
if [ ! $test -eq 0 ];then
	gettext 'Error launching of lighttpd Service'
	set -e
	exit 1
fi
echo "</FoncHTTPDCONF>"
}
configloginpassword () {
PTNlogin='^[a-zA-Z0-9]*$'
while (true)
do
loginhttp=$(whiptail --title "$(gettext 'Login')" --nocancel --inputbox "$(gettext 'Enter login to the administration interface') 
$(gettext '	- Only letters or numbers.')
$(gettext '	- 6 characters minimum:')" 10 60 3>&1 1>&2 2>&3)			
	if [ "$(expr "$loginhttp" : "$PTNlogin")" -gt 6  ];then 
		break
	fi	
done
while (true)
do
password=$(whiptail --title "$(gettext 'Password')" --nocancel --passwordbox "$(gettext 'Enter your password and press OK to continue.')" 10 60 3>&1 1>&2 2>&3)
		password2=$(whiptail --title "$(gettext 'Password')" --nocancel --passwordbox "$(gettext 'Confirm your password and press OK to continue.')" 10 60 3>&1 1>&2 2>&3)
		if [ "$password" = "$password2" ] ; then
			test="$(echo "$password" | grep -E "[a-z]" | grep -E "[0-9]" | grep -E "[A-Z]" | grep '[&éè~#{}()ç_@à?.;:/!,$<>=£%]')"
			if [ "${#test}" -ge 8 ] ; then
				break
			else
				whiptail --title "$(gettext "Password")" --msgbox "$(gettext "Password is not complex enough, it must contain at least:")
$(gettext "- 8 characters total, 1 Uppercase, lowercase 1, number 1")
$(gettext "and one special character among the following") &éè~#{}()ç_@à?.;:/!,$<>=£% " 14 60 
			fi
		else
		    whiptail --title "$(gettext "Password")" --msgbox "$(gettext "The password entered is not identical to the first.")" 14 60 
				
		fi

done
addadminhttpd "$loginhttp" "$password"
}
CActparental () {
echo "<CActparental>"
DIR_TMP=${TMPDIR-/tmp}/ctparental-mkcert.$$
mkdir "$DIR_TMP"
mkdir "$CADIR" 2> /dev/null

## création de la clef priver ca et du certificat ca
openssl genrsa  1024 > "$DIR_TMP"/cactparental.key 2> /dev/null
openssl req -new -x509 -subj "/C=FR/ST=FRANCE/L=ici/O=ctparental/CN=CActparental" -days 10000 -key "$DIR_TMP"/cactparental.key > "$DIR_TMP"/cactparental.crt 

## création de la clef privée serveur localhost
openssl genrsa 1024 > "$DIR_TMP"/localhost.key 2> /dev/null
## création certificat localhost et signature par la ca
openssl req -new -subj "/C=FR/ST=FRANCE/L=ici/O=ctparental/CN=localhost" -key "$DIR_TMP"/localhost.key > "$DIR_TMP"/localhost.csr 
openssl x509 -req -in "$DIR_TMP"/localhost.csr -out "$DIR_TMP"/localhost.crt -CA "$DIR_TMP"/cactparental.crt -CAkey "$DIR_TMP"/cactparental.key -CAcreateserial -CAserial "$DIR_TMP"/ca.srl  

## création du certificat duckduckgo pour redirection vers safe.duckduckgo.com
openssl genrsa 1024 > "$DIR_TMP"/duckduckgo.key 2> /dev/null
openssl req -new -subj "/C=FR/ST=FRANCE/L=ici/O=ctparental/CN=duckduckgo.com" -key "$DIR_TMP"/duckduckgo.key > "$DIR_TMP"/duckduckgo.csr 
openssl x509 -req -in "$DIR_TMP"/duckduckgo.csr -out "$DIR_TMP"/duckduckgo.crt -CA "$DIR_TMP"/cactparental.crt -CAkey "$DIR_TMP"/cactparental.key -CAserial "$DIR_TMP"/ca.srl 

## création du certificat search.yahoo.com pour redirection vers pages d'interdiction
openssl genrsa 1024 > "$DIR_TMP"/search.yahoo.com.key 2> /dev/null
openssl req -new -subj "/C=FR/ST=FRANCE/L=ici/O=ctparental/CN=search.yahoo.com" -key "$DIR_TMP"/search.yahoo.com.key > "$DIR_TMP"/search.yahoo.com.csr 
openssl x509 -req -in "$DIR_TMP"/search.yahoo.com.csr -out "$DIR_TMP"/search.yahoo.com.crt -CA "$DIR_TMP"/cactparental.crt -CAkey "$DIR_TMP"/cactparental.key -CAserial "$DIR_TMP"/ca.srl 

## instalation de la CA dans les ca de confiance.
cp -f "$DIR_TMP"/cactparental.crt "$CADIR"/
cp -f "$DIR_TMP"/cactparental.crt "$DIRHTML"
cp -f "$DIR_TMP"/cactparental.crt "$REPCAMOZ"
## instalation des certificats serveur
cat "$DIR_TMP"/localhost.key "$DIR_TMP"/localhost.crt > "$PEMSRVDIR"/localhost.pem
cat "$DIR_TMP"/duckduckgo.key "$DIR_TMP"/duckduckgo.crt > "$PEMSRVDIR"/duckduckgo.pem
cat "$DIR_TMP"/search.yahoo.com.key "$DIR_TMP"/search.yahoo.com.crt > "$PEMSRVDIR"/search.yahoo.com.pem
rm -rf "$DIR_TMP"

updatecauser
echo "</CActparental>"
}


install () {
	if [ $nomanuel -eq 0 ]; then  
		cp -rf www /usr/local/share/CTparental
		cp -rf confe2guardian /usr/local/share/CTparental
		cp -rf locale /usr/local/etc/CTparental
	fi
	iptablesoff
	groupadd ctoff
	unset https_proxy
	unset HTTPS_PROXY
	unset http_proxy
	unset HTTP_PROXY
	if [ $nomanuel -eq 0 ]; then 
		vim -h 2&> /dev/null
		if [ $? -eq 0 ] ; then
		EDIT="vim "
		fi
		nano -h 2&> /dev/null
		if [ $? -eq 0 ] ; then
		EDIT=${EDIT:="nano "}
		fi
		vi -h 2&> /dev/null
		if [ $? -eq 0 ] ; then
			EDIT=${EDIT:="vi "}
		fi
	
		if [ -f gpl-3.0.fr.txt ] ; then
			cp -f gpl-3.0.fr.txt /usr/local/share/CTparental/
		fi
		if [ -f gpl-3.0.txt ] ; then
			cp -f gpl-3.0.txt /usr/local/share/CTparental/
		fi
		if [ -f CHANGELOG ] ; then
			cp -f CHANGELOG /usr/local/share/CTparental/
		fi
		if [ -f dist.conf ];then
			cp -f dist.conf /usr/local/share/CTparental/dist.conf.orig
			cp -f dist.conf $DIR_CONF/
		fi
		while (true); do
		$EDIT $DIR_CONF/dist.conf
		clear
		cat < "$DIR_CONF"/dist.conf | grep -v -E ^# | grep -v ^$
		gettext 'Enter: S to continue with these parameters.'
		gettext 'Enter Q to Quit Setup.'
		gettext 'Enter any other choice to change settings.'
		 read choi
		case $choi in
			 S | s )
				break
			;;
			 Q | q )
				exit
			;;
			esac
		done
			
	fi
	if [ -f $DIR_CONF/dist.conf ];then
		source  $DIR_CONF/dist.conf 
	fi

	if [ -f /etc/NetworkManager/NetworkManager.conf ];then
    		 $SED "s/^dns=dnsmasq/#dns=dnsmasq/g" /etc/NetworkManager/NetworkManager.conf
    		 $NWMANAGERrestart
     		sleep 5
   	fi

      mkdir $tempDIR
      mkdir -p $DIR_CONF
      initblenabled
      cat /etc/resolv.conf > $DIR_CONF/resolv.conf.sav
      if [ $noinstalldep = "0" ]; then
	  for PACKAGECT in $CONFLICTS
         do
			$CMDREMOVE "$PACKAGECT" 2> /dev/null
         done
	  fi
      if [ "$noinstalldep" = "0" ]; then
	      $CMDINSTALL "$DEPENDANCES"
      fi
      # on desactive l'ipv6
		if [ "$( grep -c "net.ipv6.conf.all.disable_ipv6=" "$FILESYSCTL" )" -ge "1" ] ; then
			$SED "s?^net.ipv6.conf.all.disable_ipv6=.*?net.ipv6.conf.all.disable_ipv6=1?g" "$FILESYSCTL"
		else
			echo "net.ipv6.conf.all.disable_ipv6=1" >> "$FILESYSCTL"
		fi
		unset test
		if [ "$( grep -c "net.ipv6.conf.default.disable_ipv6=" "$FILESYSCTL" )" -ge "1" ] ; then
			$SED "s?^net.ipv6.conf.default.disable_ipv6=.*?net.ipv6.conf.default.disable_ipv6=1?g" "$FILESYSCTL"
		else
			echo "net.ipv6.conf.default.disable_ipv6=1" >> "$FILESYSCTL"
		fi
		unset test
		if [ "$( grep -c "net.ipv6.conf.lo.disable_ipv6=" "$FILESYSCTL" )" -ge "1" ] ; then
			$SED "s?^net.ipv6.conf.lo.disable_ipv6=.*?net.ipv6.conf.lo.disable_ipv6=1?g" "$FILESYSCTL"
		else
			echo "net.ipv6.conf.lo.disable_ipv6=1" >> "$FILESYSCTL"
		fi
		unset test
		sysctl -p "$FILESYSCTL"
      ######################
      # on charge le(s) module(s) indispensable(s) pour iptables.
		if [ "$( grep -c ip_conntrack_ftp "$FILEMODULESLOAD" )" -ge "1" ] ; then
			$SED "s?.*ip_conntrack_ftp.*?#ip_conntrack_ftp?g" "$FILEMODULESLOAD"
		else
			echo "#ip_conntrack_ftp" >> "$FILEMODULESLOAD"
		fi
		modprobe ip_conntrack_ftp	
		$SED "s?.*ip_conntrack_ftp.*?ip_conntrack_ftp?g" "$FILEMODULESLOAD"
		echo ':msg,contains,"iptables" /var/log/iptables.log' > "$RSYSLOGCTPARENTAL" 
		echo '& ~' >> "$RSYSLOGCTPARENTAL" 
	  #######################
      
      if [ ! -f blacklists.tar.gz ]
      then
         download
      else
         tar -xzf blacklists.tar.gz -C $tempDIR
         if [ ! $? -eq 0 ]; then
            gettext 'archive extraction error , interrupted process'
            uninstall
            set -e
            exit 1
         fi
         rm -rf ${DIR_DNS_FILTER_AVAILABLE:?}/
         mkdir $DIR_DNS_FILTER_AVAILABLE
      fi
      adapt
      catChoice
      dnsmasqon
      $SED "s?^LASTUPDATE.*?LASTUPDATE=$THISDAYS=$(date +%d-%m-%Y\ %T)?g" $FILE_CONF
	  confe2guardian
	  confprivoxy
      FoncHTTPDCONF
      activegourpectoff
      iptablesreload
      $ENCRON
      $ENLIGHTTPD
      $ENDNSMASQ
      $ENNWMANAGER
      $ENIPTABLESSAVE
      { echo "PATH=$PATH" ; echo "LANG=$LANG" ; }  > /etc/cron.d/CTparentalnomade
	  echo "*/1 * * * * root /usr/local/bin/CTparental.sh -nomade" >> /etc/cron.d/CTparentalnomade
	  { echo I_WAN="$interface_WAN"
		  echo IP_BOX="$ipbox"
		  echo IP_IWAN="$ipinterface_WAN"
		  echo DNS1="$DNS1"
		  echo DNS2="$DNS2"
	  } >> $FILE_CONF
    
}
nomade () {
	
#### si il y a un changement dan la conf réseaux ####
if [ "$DNS1" != "$(cat < $FILE_CONF | grep DNS1 | cut -d"=" -f2)"  -o \
 "$DNS2" != "$(cat < $FILE_CONF | grep DNS2 | cut -d"=" -f2)"  -o \
 "$interface_WAN" != "$(cat < $FILE_CONF | grep I_WAN | cut -d"=" -f2)"  -o \
 "$ipbox" != "$(cat < $FILE_CONF | grep IP_BOX | cut -d"=" -f2)"  -o \
 "$ipinterface_WAN" != "$(cat < $FILE_CONF | grep IP_IWAN | cut -d"=" -f2)" \
 -a "$interface_WAN" != "" -a "$ipbox" != "" -a "$ipinterface_WAN" != "" \
 -a "$DNS1" != "" ];then
# on sauvegarde ces chnagement dans le fichier de conf CTparental.
$SED "/^I_WAN=/d" "$FILE_CONF"
$SED "/^IP_BOX=/d" "$FILE_CONF"
$SED "/^IP_IWAN=/d" "$FILE_CONF"
$SED "/^DNS1=/d" "$FILE_CONF"
$SED "/^DNS2=/d" "$FILE_CONF"
{ echo I_WAN="$interface_WAN"
  echo IP_BOX="$ipbox"
  echo IP_IWAN="$ipinterface_WAN"
  echo DNS1="$DNS1"
  echo DNS2="$DNS2"
} >> $FILE_CONF
# on modifi la conf dnsmasq
dnsmasqon
# on reconfigure les règle du parfeux.
iptablesreload
fi

}

updatelistgctoff () {
	result="0"
	if [ ! -f $FILE_GCTOFFCONF ] ; then 
		echo -n > $FILE_GCTOFFCONF
	fi
	## on ajoute tous les utilisateurs manquants dans la liste
	for PCUSER in $(listeusers)
	do
		if [ "$(cat < $FILE_GCTOFFCONF | sed -e "s/#//g" | grep -c -E "^$PCUSER$")" -eq 0 ];then
			result="1"	
			if [ "$(groups "$PCUSER" | grep -c -E "( sudo )|( sudo$)")" -eq 1 ];then
				#si l'utilisateur fait parti du group sudo on l'ajoute sans filtrage par default.
				echo "$PCUSER" >> $FILE_GCTOFFCONF
			else
				#si l'utilisateur ne fait pas parti du group sudo on l'ajoute avec filtrage  par default.
				echo "#$PCUSER" >> $FILE_GCTOFFCONF
			fi
		fi
	done
	## on supprime tout ceux qui n'existent plus sur le pc.
	while read PCUSER
	do
		PCUSER=${PCUSER//#/} 
		if [ "$( listeusers | grep -c -E "^$PCUSER$")" -eq 0 ];then
			result="1"
			$SED "/^$PCUSER$/d" "$FILE_GCTOFFCONF"
			$SED "/^#$PCUSER$/d" "$FILE_GCTOFFCONF"
		fi
	done < $FILE_GCTOFFCONF
	echo $result
	
}
applistegctoff () {
		$ADDUSERTOGROUP root ctoff 2> /dev/null
		while read PCUSER
		do
			if [ "$(echo "$PCUSER" | grep -c -v "#")" -eq 1 ];then
				$ADDUSERTOGROUP "$PCUSER" ctoff 2> /dev/null
			else
				$DELUSERTOGROUP "${PCUSER//#/}" ctoff 2> /dev/null
			fi
		done < "$FILE_GCTOFFCONF"
	

}

activegourpectoff () {
echo "<activegourpectoff>"
   groupadd ctoff
   $SED "s?^GCTOFF.*?GCTOFF=ON?g" $FILE_CONF
   updatelistgctoff
   applistegctoff
   USERHTTPD=$(cat < /etc/passwd | grep /var/www | cut -d":" -f1)
   GROUPHTTPD=$(cat < /etc/group | grep "$USERHTTPD" | cut -d":" -f1)
   chown root:"$GROUPHTTPD" "$FILE_GCTOFFCONF"
   chmod 660 "$FILE_GCTOFFCONF"
   echo "PATH=$PATH"  > /etc/cron.d/CTparentalupdateuser
   echo "*/1 * * * * root /usr/local/bin/CTparental.sh -ucto" >> /etc/cron.d/CTparentalupdateuser
   $CRONrestart
echo "</activegourpectoff>"
}

desactivegourpectoff () {
   groupdel ctoff 2> /dev/null
   $SED "s?^GCTOFF.*?GCTOFF=OFF?g" $FILE_CONF
}

uninstall () {
   # On force la désinstall par dpkg ou rpm si l'install a était effectuer par un paquage.
   if [ $nomanuel -eq 0 ]; then 
	   muninstall=$(gettext "Install a packet was detected please use this command to uninstall ctparental.")
	   if [ "$(dpkg -l ctparental | grep -c ^i)" -eq 1 ] ;then
			echo "$muninstall"
			echo "$CMDREMOVE ctparental"
			exit 0
	   fi
	   if [ "$(rpm -q -a | grep ctparental )" -eq 1 ] ;then
			echo "$muninstall"
			echo "$CMDREMOVE ctparental"
			exit 0
	   fi
   fi
   autoupdateoff 
   dnsmasqoff
   desactivetimelogin
   iptablesoff
   desactivegourpectoff
   $LIGHTTPDstop
   $DNSMASQstop
   if [ $nomanuel -eq 1 ]; then 
	   # en install par le deb on n'efface pas les fichiers installer par celuis si
       rm -f /etc/cron.d/CTparental*
       rm -rf "$DIRHTML"
       rm -rf /usr/local/share/CTparental
       cd "$DIR_CONF"
       for file in *
       do
		  if [ ! "$file" = "" ] ;then
		  rm -rf ${DIR_CONF:?}/"$file"
		  fi
       done
       
   else 
       rm -f /etc/cron.d/CTparental*
       rm -rf "$DIRadminHTML"
       rm -rf "$DIRHTML"
       rm -rf /usr/local/share/CTparental
       rm -rf "$DIR_CONF"
   fi
   
   rm -rf "$tempDIR"
   rm -rf /usr/share/lighttpd/*
   rm -f "$CTPARENTALCONFHTTPD"
   if [ -f /etc/NetworkManager/NetworkManager.conf ];then
	$SED "s/^#dns=dnsmasq/dns=dnsmasq/g" /etc/NetworkManager/NetworkManager.conf
	$NWMANAGERrestart
  	sleep 5
   fi

   if [ $noinstalldep = "0" ]; then
	 for PACKAGECT in $DEPENDANCES
         do
			
			$CMDREMOVE "$PACKAGECT" 2> /dev/null
         done
   fi
   # desactivation du modules ip_conntrack_ftp

	if [ "$(grep -c ip_conntrack_ftp "$FILEMODULESLOAD" )" -ge "1" ] ; then
		$SED "s?.*ip_conntrack_ftp.*?#ip_conntrack_ftp?g" "$FILEMODULESLOAD"
	else
		echo "#ip_conntrack_ftp" >> "$FILEMODULESLOAD"
	fi
	modprobe -r ip_conntrack_ftp	
	$SED "s?.*ip_conntrack_ftp.*?#ip_conntrack_ftp?g" "$FILEMODULESLOAD"
	###

   rm -f "$PEMSRVDIR"/localhost.pem
   rm -f "$PEMSRVDIR"/duckduckgo.pem
   rm -f "$CADIR"/cactparental.crt
   rm -f "$REPCAMOZ"/cactparental.crt
   for user in $(listeusers) ; do	
		HOMEPCUSER=$(getent passwd "$user" | cut -d ':' -f6)
		if [ -d "$HOMEPCUSER" ];then
			#on desinstall le certificat dans tous les prifiles firefoxe utilisateur existant 
			listprofile=$(cat < "$HOMEPCUSER"/.mozilla/firefox/profiles.ini | grep Path= | cut -d"=" -f2)
			for profilefirefox in $listprofile ; do
				#firefox iceweachel
				# on supprime tous les anciens certificats
				while true
				do
					certutil -D -d "$HOMEPCUSER"/.mozilla/firefox/"$profilefirefox"/ -n"CActparental - ctparental" 2&> /dev/null
					if [ ! $? -eq 0 ];then 
						break
					fi
				done
			done
		fi
   done
   unsetproxy
}

choiblenabled () {
echo -n > $CATEGORIES_ENABLED
clear
gettext 'Want to filter by, Blacklist or Whitelist:'
echo -n " B/W :"
while (true); do
         read choi
         case $choi in
         B | b )
         gettext 'Choice of filtered categories.'
        while read CATEGORIE # pour chaque catégorie 
		do   
		      clear
		      gettext 'You want to enable this category:'
		      echo -n " $CATEGORIE  O/N :"
		      while (true); do
			 read choi
			 case $choi in
			 O | o )
			 echo "$CATEGORIE" >> "$CATEGORIES_ENABLED"
			 break
			 ;;
			 N | n )
			 break
			 ;;
		      esac
		      done
		done < $BL_CATEGORIES_AVAILABLE
         break
         ;;
         W | w )
               gettext 'Choice of unfiltered categories.'
        while read CATEGORIE # pour chaque catégorie
		do   
		      clear
		      gettext 'You want to enable this category:'
		      echo -n " $CATEGORIE  O/N :"
		      while (true); do
			 read choi
			 case $choi in
			 O | o )
			 echo "$CATEGORIE" >> "$CATEGORIES_ENABLED"
			 break
			 ;;
			 N | n )
			 break
			 ;;
		      esac
		      done
		done < $WL_CATEGORIES_AVAILABLE
         break
         ;;
      esac
done
}


errortime1 () {
clear
at=$(gettext "at")
and=$(gettext "and")
h=$(gettext ":")
or=$(gettext "or")
echo -e "$(gettext "The start time must be strictly less than the end time:")$RougeD$input$Fcolor "
echo "exemple: 00${h}00 $at 23${h}59 $or 08${h}00 $at 12${h}00 $and 14${h}00 $at 16${h}50"
echo -e -n "$RougeD$PCUSER$Fcolor $(gettext "is allowed to connect the") $BleuD${DAYS[$NumDAY]}$Fcolor $(gettext "at :")"
}
errortime2 () {
clear
at=$(gettext "at")
and=$(gettext "and")
h=$(gettext ":")
or=$(gettext "or")
echo -e "$(gettext "Bad syntax:")$RougeD$input$Fcolor "
echo "exemple: 00${h}00 $at 23${h}59 $or 08${h}00 $at 12${h}00 $and 14${h}00 $at 16${h}50"
echo -e -n "$RougeD$PCUSER$Fcolor $(gettext "is allowed to connect the") $BleuD${DAYS[$NumDAY]}$Fcolor $(gettext "at :")"
}


timecronalert () {
MinAlert=${1} # temps en minute entre l'alerte et l'action
H=$((10#${2}))
M=$((10#${3}))
D=$((10#${4}))
Numday=${Numday:=1}
MinTotalAlert="$((H*60+M-MinAlert))"
if [ $(( MinTotalAlert < 0 )) -eq 1 ] 
then
	if [ "$Numday" -eq 0 ] ; then
		D=6
	else
		D=$(( D -1 ))
	fi
	MinTotalAlert="$(( $((H + 24)) * 60 + M - MinAlert))"
fi
Halert=$((MinTotalAlert/60))
MAlert=$((MinTotalAlert - $(( Halert *60 )) ))
echo "$MAlert $Halert * * ${DAYSCRON[$D]}"
}
updatetimelogin () {
	USERSCONECT=$(who | awk '//{print $1}' | sort -u)
   	if [ "$(cat < $FILE_HCOMPT | grep -c "$(date +%D)")" -eq 1 ] ; then
			# on incrémente le compteur de temps de connection. pour chaque utilisateur connecté
		for PCUSER in $USERSCONECT
		do
		
			if [ "$(cat < $FILE_HCONF | grep -c "^$PCUSER=user=" )" -eq 1 ] ;then
			   if [ "$(cat < $FILE_HCOMPT | grep -c "^$PCUSER=" )" -eq 0 ] ;then
					echo "$PCUSER=1=1" >> $FILE_HCOMPT
			   else
					count=$(($(cat < $FILE_HCOMPT | grep "^$PCUSER=" | cut -d"=" -f2) + 1 ))
					if [ "$(netstat -e | grep "$PCUSER" | grep -c ESTABLISHED)" -ge 1 ];then
						countweb=$(($(cat < $FILE_HCOMPT | grep "^$PCUSER=" | cut -d"=" -f3) + 1 ))
					else
						countweb=$(cat < $FILE_HCOMPT | grep "^$PCUSER=" | cut -d"=" -f3) 
					fi
					$SED "s?^$PCUSER=.*?$PCUSER=$count=$countweb?g" $FILE_HCOMPT
					temprest=$(($(cat < $FILE_HCONF | grep "^$PCUSER=user=" | cut -d "=" -f3 ) - count ))
					temprestweb=$(($(cat < $FILE_HCONF | grep "^$PCUSER=user=" | cut -d "=" -f4 ) - countweb ))
					echo $temprest
					# si le compteur de l'usager dépasse la valeur max autorisée on verrouille le compte et on déconnecte l'utilisateur.
					if [ $temprest -le 0 ];then
						/usr/bin/skill -KILL -u"$PCUSER"
						passwd -l "$PCUSER"
					else
						# On alerte l'usager que son quota temps session arrive à expiration 5-4-3-2-1 minutes avant.
						if [ $temprest -le "$TIMERALERT" ];then
						HOMEPCUSER=$(getent passwd "$PCUSER" | cut -d ':' -f6)
						export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u "$PCUSER"  /usr/bin/notify-send -u critical "CTparental" "$(gettext 'Logout in') $temprest $(gettext 'minutes') $LANG "
						fi
					fi
					if [ "$temprestweb" -le 0 ];then
						if [ "$(cat < "$FILEIPTIMEWEB" | grep -c "$PCUSER")" -eq 0 ];then
							echo "$IPTABLES -A OUTPUT ! -d 127.0.0.1/8 -m owner --uid-owner $PCUSER -j REJECT" >> "$FILEIPTIMEWEB"
							iptablesreload
							HOMEPCUSER=$(getent passwd "$PCUSER" | cut -d ':' -f6)
							export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u "$PCUSER"  /usr/bin/notify-send -u critical "CTparental" "$(gettext 'Your surf time as expird!')"
						fi
					else
						if [ "$(cat < "$FILEIPTIMEWEB" | grep -c "$PCUSER")" -ge 1 ];then
							$SED "/$PCUSER/d" $FILEIPTIMEWEB
							iptablesreload
						fi
						# On alerte l'usager que son quota temps web arrive à expiration 5-4-3-2-1 minutes avant.
						if [ $temprestweb -le "$TIMERALERT" ];then
						HOMEPCUSER=$(getent passwd "$PCUSER" | cut -d ':' -f6)
						export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u "$PCUSER"  /usr/bin/notify-send -u critical "CTparental" "$(gettext 'Internet surfing cut in') $temprestweb $(gettext 'minutes') "
						fi
					fi
			   fi   
			else
			# on efface les lignes relatives à cet utilisateur
			if [ "$(cat < "$FILEIPTIMEWEB" | grep -c "$PCUSER")" -ge 1 ];then
					$SED "/$PCUSER/d" $FILEIPTIMEWEB
					iptablesreload
			fi
			$SED "/^$PCUSER=/d" $FILE_HCOMPT
		
			fi

		done	
	else
		# on réactive tous les comptes
		for PCUSER in $(listeusers)
		do
			passwd -u "$PCUSER"
		done
		# on remet tous les compteurs à zéro.
		echo "date=$(date +%D)" > $FILE_HCOMPT
		echo > $FILEIPTIMEWEB 
		iptablesreload
		
	fi
	
}
requiredpamtime (){
	TESTGESTIONNAIRE=""
   if [ ! -f $DIRPAM$COMMONFILEGS ] ; then 
	   for FILE in $GESTIONNAIREDESESSIONS
	   do
		  if [ -f "$DIRPAM""$FILE" ];then
			 if [ "$(cat < "$DIRPAM""$FILE" | grep -c "^account required pam_time.so")" -eq 0  ] ; then
				$SED "1i account required pam_time.so"  "$DIRPAM$FILE"
			 fi
			 TESTGESTIONNAIRE=1
		  fi
	   done
	   if [ $TESTGESTIONNAIRE -eq 1 ] ; then
		  gettext 'No known session manager has been detected.'
		  gettext 'so it is impossible to activate the time control connections'
		  desactivetimelogin
		  exit 1
	   fi
	else
		if [ "$(cat < "$DIRPAM""$COMMONFILEGS" | grep -c "^account required pam_time.so")" -eq 0  ] ; then
				$SED "1i account required pam_time.so"  $DIRPAM$COMMONFILEGS 
		fi
	fi
   
   if [ ! -f $FILEPAMTIMECONF.old ] ; then
   cp $FILEPAMTIMECONF $FILEPAMTIMECONF.old
   fi
   echo "*;*;root;Al0000-2400" > $FILEPAMTIMECONF
}
activetimelogin () {
requiredpamtime
   for NumDAY in 0 1 2 3 4 5 6
   do
   { echo "PATH=$PATH" ; echo "LANG=$LANG" ; } > /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
   done
   for PCUSER in $(listeusers)
   do
   HOMEPCUSER=$(getent passwd "$PCUSER" | cut -d ':' -f6)
   $SED "/^$PCUSER=/d" $FILE_HCONF
   echo -e -n "$PCUSER $(gettext "is allowed to connect 7/7 24/24") O/N?" 
   choi=""
   while (true); do
   read choi
        case $choi in
         O | o )
	 alltime="O"
         echo "$PCUSER=admin=" >> $FILE_HCONF
   	break
         ;;
	 N| n )
         alltime="N"
         clear
         echo -e "$PCUSER $(gettext 'is allowed to connect X minutes per day')" 
         echo -e -n "X (1 a 1440) = " 
         while (true); do
         read choi
         if [ "$choi" -ge 1 ];then
			if [ "$choi" -le 1440 ];then
				timesession=$choi
				break
			fi
		 fi	
         echo " $(gettext 'X must take a value between 1 and') 1440 "
         done
         clear
         echo -e "$PCUSER $(gettext 'is allowed to surf the Internet X minutes per day')" 
         echo -e -n "X (1 a ""$timesession"") = " 
         while (true); do
         read choi
         if [ "$choi" -ge 1 ];then
			if [ "$choi" -le "$timesession" ];then
				timeweb=$choi
				break
			fi
		 fi	
         echo " $(gettext 'X must take a value between 1 and') $timesession "
         done
         echo "$PCUSER=user=$timesession=$timeweb" >> $FILE_HCONF
		 break
         ;;	
   esac
   done
      
      for NumDAY in 0 1 2 3 4 5 6
         do
	 if [ $alltime = "O" ];then	
		break	
	 fi
	 
         clear
         at=$(gettext "at")
         and=$(gettext "and")
         h=$(gettext ":")
         or=$(gettext "or")
         echo "exemple: 00${h}00 $at 23${h}59 $or 08${h}00 $at 12${h}00 $and 14${h}00 $at 16${h}50"
         echo -e -n "$RougeD$PCUSER$Fcolor $(gettext "is allowed to connect the") $BleuD${DAYS[$NumDAY]}$Fcolor $(gettext "at :")"
         while (true); do
            read choi
            input=$choi
            choi=$(echo "$choi" | sed -e "s/$h//g" | sed -e "s/ //g" | sed -e "s/$at/-/g" | sed -e "s/$and/:/g" ) # mise en forme de la variable choi pour pam   
               if [ "$( echo "$choi" | grep -E -c "^([0-1][0-9]|2[0-3])[0-5][0-9]-([0-1][0-9]|2[0-3])[0-5][0-9]$|^([0-1][0-9]|2[0-3])[0-5][0-9]-([0-1][0-9]|2[0-3])[0-5][0-9]:([0-1][0-9]|2[0-3])[0-5][0-9]-([0-1][0-9]|2[0-3])[0-5][0-9]$" )" -eq 1 ];then
                  int1=$(echo "$choi" | cut -d ":" -f1 | cut -d "-" -f1)
                  int2=$(echo "$choi" | cut -d ":" -f1 | cut -d "-" -f2)
                  int3=$(echo "$choi" | cut -d ":" -f2 | cut -d "-" -f1)
                  int4=$(echo "$choi" | cut -d ":" -f2 | cut -d "-" -f2)
                  if [ "$int1" -lt "$int2" ];then
                     if [ ! "$(echo "$choi" | grep -E -c ":")" -eq 1 ] ; then
                        if [ "$NumDAY" -eq 6 ] ; then
                           HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$int1-$int2"
                        else
                           HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$int1-$int2|"
                        fi
                        m1=${int1:2:4} 
                        h1=${int1:0:2}
                        m2=${int2:2:4} 
                        h2=${int2:0:2}
						echo "$PCUSER=$NumDAY=$h1${h}h$m1:$h2${h}h$m2" >> "$FILE_HCONF"   
                        echo "$m2 $h2 * * ${DAYSCRON[$NumDAY]} root /usr/bin/skill -KILL -u$PCUSER" >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
			for ((count=1 ; TIMERALERT + 1 - count ; count++))
			do
                        echo "$(timecronalert "$count" "$h2" "$m2" "$NumDAY" ) root export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u $PCUSER  /usr/bin/notify-send -u critical \"CTparental\" \"$(gettext 'Logout in') $count $(gettext 'minutes')\" " >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
			done
                        break
   
                     else   
                        if [ "$int2" -lt "$int3" ];then
                           if [ "$int3" -lt "$int4" ];then
                              if [ "$NumDAY" -eq 6 ] ; then
                                 HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$int1-$int2|${DAYSPAM[$NumDAY]}$int3-$int4"
                              else
                                 HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$int1-$int2|${DAYSPAM[$NumDAY]}$int3-$int4|"
                              fi
								m1=${int1:2:4} 
								h1=${int1:0:2}
								m2=${int2:2:4} 
								h2=${int2:0:2} 
								m3=${int3:2:4} 
								h3=${int3:0:2}
								m4=${int4:2:4} 
								h4=${int4:0:2} 
                              ## minutes heures jourdumoi moi jourdelasemaine utilisateur  commande
							  echo "$PCUSER=$NumDAY=$h1${h}h$m1:$h2${h}h$m2:$h3${h}h$m3:$h4${h}h$m4" >> "$FILE_HCONF"
                              echo "$m2 $h2 * * ${DAYSCRON[$NumDAY]} root /usr/bin/skill -KILL -u$PCUSER" >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
			      echo "$m4 $h4 * * ${DAYSCRON[$NumDAY]} root /usr/bin/skill -KILL -u$PCUSER" >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
			      for ((count=1 ; TIMERALERT + 1 - count ; count++))
			      do
                              echo "$(timecronalert "$count" "$h2" "$m2" "$NumDAY" ) root export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u $PCUSER  /usr/bin/notify-send -u critical \"CTparental\" \"$(gettext 'Logout in') $count $(gettext 'minutes')\" " >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
                              echo "$(timecronalert "$count" "$h4" "$m4" "$NumDAY" ) root export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u $PCUSER  /usr/bin/notify-send -u critical \"CTparental\" \"$(gettext 'Logout in') $count $(gettext 'minutes')\" " >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
			      done
                             
                              break   
                           else
                              errortime1
                           fi
                        else
                           errortime1
                        fi
                     fi
                  else
                     errortime1
   
                  fi
                       
               else
                  errortime2   
               fi
           
         done
     
        done
     	if [ $alltime = "N" ] ; then
		echo "*;*;$PCUSER;$HORAIRESPAM" >> $FILEPAMTIMECONF
	else
		echo "*;*;$PCUSER;Al0000-2400" >> $FILEPAMTIMECONF
	fi
   done
   
   for NumDAY in 0 1 2 3 4 5 6
   do
      echo >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
   done
   echo >> $FILE_HCONF
{ echo "PATH=$PATH" ; echo "LANG=$LANG" ; }   > /etc/cron.d/CTparentalmaxtimelogin
echo "*/1 * * * * root /usr/local/bin/CTparental.sh -uctl" >> /etc/cron.d/CTparentalmaxtimelogin
$SED "s?^HOURSCONNECT.*?HOURSCONNECT=ON?g" $FILE_CONF
$CRONrestart
}

desactivetimelogin () {
echo "<desactivetimelogin>"
for FILE in $GESTIONNAIREDESESSIONS
do
   $SED "/account required pam_time.so/d" "$DIRPAM""$FILE" 2> /dev/null
done
$SED "/account required pam_time.so/d" "$DIRPAM""$COMMONFILEGS" 2> /dev/null

cat $FILEPAMTIMECONF.old > $FILEPAMTIMECONF
for NumDAY in 0 1 2 3 4 5 6
do
   rm -f /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
done
rm -f /etc/cron.d/CTparentalmaxtimelogin
$SED "s?^HOURSCONNECT.*?HOURSCONNECT=OFF?g" $FILE_CONF 
for PCUSER in $(listeusers)
do
	passwd -u "$PCUSER" > /dev/null
done
# on remet tous les compteurs à zéro.
echo "date=$(date +%D)" > $FILE_HCOMPT
echo > $FILE_HCONF
$CRONrestart
echo > $FILEIPTIMEWEB 
iptablesreload
echo "</desactivetimelogin>"
}


listeusers () {

for LIGNES in $(getent passwd | cut -d":" -f1,3)
do
#echo $(echo $LIGNES | cut -d":" -f2)
if [ "$(echo "$LIGNES" | cut -d":" -f2)" -ge "$UIDMINUSER" ] ;then
	echo "$LIGNES" | cut -d":" -f1
fi
done


}


readTimeFILECONF () {
   requiredpamtime
   for NumDAY in 0 1 2 3 4 5 6
   do
   { echo "PATH=$PATH" ; echo "LANG=$LANG" ; }  > /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
   done
   
   for PCUSER in $(listeusers)
   do
   HOMEPCUSER=$(getent passwd "$PCUSER" | cut -d ':' -f6)
   HORAIRESPAM=""
  	userisconfigured="0"

	while read line
	do
	
			if [ "$( echo "$line" | grep -E -c "^$PCUSER=[0-6]=" )" -eq 1 ] ; then
				echo "$line" 
				NumDAY=$(echo "$line" | cut -d"=" -f2)
				h1=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f1 | cut -d"h" -f1)
				m1=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f1 | cut -d"h" -f2)
				h2=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f2 | cut -d"h" -f1)
				m2=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f2 | cut -d"h" -f2)
				h3=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f3 | cut -d"h" -f1)
				m3=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f3 | cut -d"h" -f2)
				h4=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f4 | cut -d"h" -f1)
				m4=$(echo "$line" | cut -d"=" -f3 | cut -d":" -f4 | cut -d"h" -f2)
				if [ "$(echo -n "$h3""$m3" | wc -c)" -gt 2 ]; then
 					if [ "$NumDAY" -eq 6 ] ; then
		                        	HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$h1$m1-$h2$m2|${DAYSPAM[$NumDAY]}$h3$m3-$h4$m4"
						
		                      	else
		                        	HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$h1$m1-$h2$m2|${DAYSPAM[$NumDAY]}$h3$m3-$h4$m4|"
		                      	fi
					echo "$m2 $h2 * * ${DAYSCRON[$NumDAY]} root /usr/bin/skill -KILL -u$PCUSER" >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
					echo "$m4 $h4 * * ${DAYSCRON[$NumDAY]} root /usr/bin/skill -KILL -u$PCUSER" >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
					for ((count=1 ; TIMERALERT + 1 - count ; count++))
					do
					echo "$(timecronalert "$count" "$h2" "$m2" "$NumDAY" ) root export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u $PCUSER  /usr/bin/notify-send -u critical \"CTparental\" \"$(gettext 'Logout in') $count $(gettext 'minutes')\" " >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
					echo "$(timecronalert "$count" "$h4" "$m4" "$NumDAY" ) root export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u $PCUSER  /usr/bin/notify-send -u critical \"CTparental\" \"$(gettext 'Logout in') $count $(gettext 'minutes')\" " >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
					userisconfigured="1"
					done

				else
				        if [ "$NumDAY" -eq 6 ] ; then
				           HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$h1$m1-$h2$m2"
				        else
				           HORAIRESPAM="$HORAIRESPAM${DAYSPAM[$NumDAY]}$h1$m1-$h2$m2|"
				        fi
					for ((count=1 ; TIMERALERT + 1 - count ; count++))
					do
					echo "$(timecronalert "$count" "$h2" "$m2" "$NumDAY" ) root export HOME=$HOMEPCUSER && export DISPLAY=:0.0 && export XAUTHORITY=$HOMEPCUSER/.Xauthority && sudo -u $PCUSER  /usr/bin/notify-send -u critical \"CTparental\" \"$(gettext 'Logout in') $count $(gettext 'minutes')\" " >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
					done
					echo "$m2 $h2 * * ${DAYSCRON[$NumDAY]} root /usr/bin/skill -KILL -u$PCUSER" >> /etc/cron.d/CTparental"${DAYS[$NumDAY]}"
					
					userisconfigured="1"
				fi
			fi
	
	
	done < $FILE_HCONF
	if [ $userisconfigured -eq 1 ] ; then
		echo "*;*;$PCUSER;$HORAIRESPAM" >> $FILEPAMTIMECONF
	else
		echo "*;*;$PCUSER;Al0000-2400" >> $FILEPAMTIMECONF 
		$SED "/^$PCUSER=/d" $FILE_HCOMPT 
		passwd -u "$PCUSER"
	fi
   done
{ echo "PATH=$PATH" ; echo "LANG=$LANG" ; }  > /etc/cron.d/CTparentalmaxtimelogin  
echo "*/1 * * * * root /usr/local/bin/CTparental.sh -uctl" >> /etc/cron.d/CTparentalmaxtimelogin
$SED "s?^HOURSCONNECT.*?HOURSCONNECT=ON?g" $FILE_CONF
$CRONrestart
}

confgrub2() {
	
#!/bin/sh
PTNlogin='^[a-zA-Z]*$'
##Passage en keymap us pour le password comme sa quelque soit votre clavier le mot de passe correspond bien ##au touche frappée.ce qui, ce qui évite de ce prendre la tête pour le clavier avec le mot de passe grub.
#apt-get install console-data
layout1="$(cat < /etc/default/keyboard | grep "XKBLAYOUT" | awk -F "\"" '{print $2}' | awk -F "," '{print $1}')"
setxkbmap us
loadkeys us
clear
gettext 'keymap is in qwerty us in grub menu.
    - Only letters or numbers.
    - 4 characters minimum.
Enter login to the superuser of grub2 :'
while (true); do
    read logingrub
    if [ "$(expr "$logingrub" : "$PTNlogin")" -gt 4  ];then 
        break
    else
        clear
gettext 'keymap is in qwerty us in grub menu.
    - Only letters or numbers.
    - 4 characters minimum.
Enter login to the superuser of grub2 :'
    fi    
done
echo > /tmp/passgrub
while [ "$(awk '{print $NF}' /tmp/passgrub | grep -c grub.)" -eq 0 ];do
grub-mkpasswd-pbkdf2 | tee /tmp/passgrub
done    
passwordgrub=$(awk '{print $NF}' /tmp/passgrub | grep grub.)
##on rebascule sur la keymap system
setxkbmap "$layout1"
loadkeys "$layout1"
vide=""
cat << EOF > /etc/grub.d/99_password
#!/bin/sh
## ce script doit être lancé en dernier !!!
## on restreint uniquement les menus de "setup uefi" , " recovery mode "
## ainsi que tous les submenu.
## seul les menuentry et submenu de premier niveaux prennent en compte les paramètres d’accès utilisateurs.
## ce qui implique que l'ajout de --unrestricted a un submenu et récursif  !!
cat << ${vide}EOF
set superusers="$logingrub"
password_pbkdf2 $logingrub $passwordgrub
${vide}EOF
confunrestricted() {
        ## fonction lancer en tache de fond par la commande
        ## confunrestricted &
        ## elle attend la fin de l’exécution de tous les scripts  update grub 
        ## puis modifie le fichier /boot/grub/grub.cfg pour y ajouter le droits a touts le monde
        cd /etc/grub.d/
        for file in *
        do
        if [ "\$(echo "\$file" | grep -E -c "[0-9][0-9]_")" -eq 1 ];then
            if [ -z "\$processupdategrub" ] ; then
                processupdategrub=\$file
            else
                processupdategrub=\$processupdategrub","\$file
            fi
        fi
        done
        while [ "\$(ps -C "\$processupdategrub" -o pid= | wc -l)" -gt 2 ]
        do
            sleep 0.2
        done
        cp /boot/grub/grub.cfg /tmp/grub.cfg.new
        while read linecfg 
        do
            if [ "\$(echo "\$linecfg" | grep -E "menuentry " | grep -v "uefi-firmware" | grep -c -v "recovery mode" )" -eq 1 ];then
                line2=\$(echo "\$linecfg" | sed -e 's/ {/ --unrestricted { /g')
                sed -i "s|\$linecfg|\$line2|" /boot/grub/grub.cfg
            fi
        done < /tmp/grub.cfg.new
        rm /tmp/grub.cfg.new
    }
confunrestricted &
EOF
chmod 755 /etc/grub.d/99_password
update-grub2

}

# and func # ne pas effacer cette ligne !!

usage="$(gettext "Use"): CTparental.sh    {-i }|{ -u }|{ -dl }|{ -ubl }|{ -rl }|{ -on }|{ -off }|{ -cble }|{ -dble }
                               |{ -tlo }|{ -tlu }|{ -uhtml }|{ -aupon }|{ -aupoff }|{ -aup } 
-i$(gettext "	=> Install parental controls on the computer (desktop PC). Can be used with
	   an additional parameter to specify a source path for the redirection page.
	   example: CTparental.sh -dirhtml -i /home/toto/html/
	   if no option a page by default is used.")
	   
-u$(gettext "	=> uninstall the Parental Control Computer (desktop PC)")

-dl$(gettext "	=> updates parental control from the blacklist of the University of Toulouse")

-ubl$(gettext "	=> What to do after each change of the file") $DNS_FILTER_OSSI

-rl$(gettext "	=> What to do after each change of the file") $DREAB

-on$(gettext "	=> Enable parental control")

-off$(gettext "	=> Disable parental controls")

-cble$(gettext "	=> Set the filter mode by whitelist or blacklist (default)
	   and the categories that you want to activate.")
	   
-dble$(gettext "	=> Resets the default active categories and blacklist filtering.")

-tlo$(gettext "	=> Enable and configure the login time restrictions for users.")

-tlu$(gettext "	=> Disable the login time restrictions for users.")

-uhtml$(gettext "	=> updates the redirect page from a source directory or default.
	   examples:
	           - With a source directory: CTparental.sh -uhtml -dirhtml /home/toto/html/
	           - Default: CTparental.sh -uhtml
	   also lets you change the login couple password of the web interface.")
	   
-aupon$(gettext "	=> Enable the automatic update of the blacklist of Toulouse (every 7 days).")

-aupoff$(gettext "	=> Disable the automatic update of the blacklist of Toulouse.")

-aup$(gettext "	=> as -dl but only if there is no update for more than 7 days.")

-nodep$(gettext "	=> if placed after -i or -u allows not install / uninstall the dependencies useful if
	   we prefer to install them by hand, or for the postinst and prerm script of deb.
	   examples:
	   CTparental.sh -i -nodep
	   CTparental.sh -dirhtml -i /home/toto/html/ -nodep
	   CTparental.sh -u -nodep")
	   
-nomanuel$(gettext "	=> used only for the postinst and prerm script.")

-gcton$(gettext "	=> Enable privileged group.
	   exemples:
	           CTparental.sh -gctulist
	           Comment all users that you want to filter in ")$FILE_GCTOFFCONF 
	           CTparental.sh -gctalist
	           
-gctoff$(gettext "	=> Disable privileged group.")
	   $(gettext "all users of the system undergo the filtering !!")
	   			 
	   			 
-gctalist$(gettext "	=> Add / delete users in the ctoff group based on the config file ,") $FILE_GCTOFFCONF

-ipton$(gettext "	=> Enable rules of custom firewall.")

-iptoff$(gettext "	=> Disable rules of custom firewall.")

-grubPon$(gettext "	=> Enable the superuser of grub2.")

-grubPoff$(gettext "	=> Disable the superuser of grub2.")
"
arg1=${1}
case $arg1 in
   -\? | -h* | --h*)
      echo "$usage"
      exit 0
      ;;
   -i )
      install
      exit 0
      ;;
   -u )
	  uninstall
      exit 0
      ;;
   -dl )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  download
		  adapt
		  catChoice
		  dnsmasqon
		  $SED "s?^LASTUPDATE.*?LASTUPDATE=$THISDAYS=$(date +%d-%m-%Y\ %T)?g" $FILE_CONF
      fi
      exit 0
      ;;
   -ubl )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  adapt
		  catChoice
		  dnsmasqon
      fi
       
      exit 0
      ;;
   -uhtml )
      FoncHTTPDCONF
      exit 0
      ;;
   -rl )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
         catChoice
         dnsmasqon
      fi 
      exit 0
      ;;
   -on )
      dnsmasqon
      iptablesreload
      exit 0
      ;;
   -off )
	  desactivegourpectoff
      autoupdateoff 
      dnsmasqoff
      iptablesoff
      exit 0
      ;;
   -wlo )
	  if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  dnsmasqwhitelistonly
      fi
      exit 0
      ;;
   -cble )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  choiblenabled
		  catChoice
		  dnsmasqon
      fi
      exit 0
      ;;
    -dble )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  initblenabled
		  catChoice
		  dnsmasqon
      fi
      exit 0
      ;;
    -tlo )
      activetimelogin
      exit 0
      ;;
    -tlu )
      desactivetimelogin
      exit 0
      ;;
    -trf )
      readTimeFILECONF
      exit 0
      ;;
    -aupon )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		 autoupdateon
      fi
      exit 0
      ;;
    -aupoff )
      autoupdateoff
      exit 0
      ;;
    -aup )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		 autoupdate
      fi
      exit 0
      ;;
    -listusers )
      listeusers
      exit 0
      ;;
    -gcton )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  activegourpectoff
		  iptablesreload
	  fi
	  exit 0
      ;;
    -gctoff )
	  desactivegourpectoff
	  iptablesreload
	  exit 0
      ;;
    -gctulist )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  updatelistgctoff
		  iptablesreload
	  fi
	  exit 0
      ;;
    -gctalist )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		  if [ "$(updatelistgctoff)" -eq 1 ];then
			updatecauser
			setproxy
		  fi
		  unset test
		  applistegctoff
		  iptablesreload
	  fi
	  exit 0
      ;;
    -ipton )
      $SED "s?.*IPRULES.*?IPRULES=ON?g" $FILE_CONF
      iptablesreload
      echo -e "$RougeD $(gettext "to add custom rules edit the file") "
      echo " $FILEIPTABLES "
      echo -e " $(gettext "then run the command") CTparental.sh -ipton $Fcolor"
      exit 0
      ;;
    -iptoff )
      $SED "s?.*IPRULES=.*?IPRULES=OFF?g" $FILE_CONF
      iptablesreload
      exit 0
      ;;
    -nomade )
	 # appelé toutes les minutes par cron pour modifier la configuration en cas de changement de réseaux.
	  nomade
	  exit 0
      ;;  
    -uctl )
	 # appelé toutes les minutes par cron pour activer désactiver les usagers ayant des restrictions de temps journalier de connexion.
	  updatetimelogin
	  exit 0
      ;;  
    -ucto )
      if [ ! "$FILTRAGEISOFF" -eq 1 ];then
		 # appelé toutes les minutes par cron pour activer le filtrage sur les usagers nouvelement créé .
		 
		  if [ "$(updatelistgctoff)" -eq 1 ];then
			applistegctoff
			updatecauser
			setproxy
			iptablesreload
		  fi
		  unset test
	  fi
	  exit 0
      ;;  
    -dgreload )
      $E2GUARDIANrestart     
      exit 0
      ;;  
    -grubPon )
      confgrub2
      exit 0
      ;;  
    -grubPoff )
      rm -rf /etc/grub.d/99_password
      update-grub2
      exit 0
      ;;
      
   *)
      echo "$(gettext "unknown argument"):$1";
      echo "$usage";
      exit 1
      ;;
esac


